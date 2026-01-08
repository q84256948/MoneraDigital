# P1 修复总结 - 定期理财系统

**修复日期**：2026-01-08
**修复优先级**：🟡 **开发前必须完成**
**风险等级**：MEDIUM - 影响业务体验和合规

---

## 一、修复概览

本文档总结了定期理财系统的 **3 大 P1 修复**，涉及自动续期、利息派发、权限审核等业务关键流程。

| 序号 | 修复项 | 风险 | 解决方案 | 影响范围 |
|-----|------|------|--------|---------|
| 1 | 自动续期边界处理 | 🟡 MEDIUM | 状态机 + 产品检查 + 降级处理 | 赎回流程 |
| 2 | 利息派发时间线 | 🟡 MEDIUM | 每日计息脚本 + 利息锁定 | 计息系统 |
| 3 | 权限与审核流程 | 🟠 LOW-MEDIUM | RBAC + 工作流 + 审计日志 | 管理后台 |

---

## 二、详细修复说明

### P1.1 - 自动续期状态机与降级处理 🟡

**风险场景**：
```
用户 A 开启自动续期，到期后：
- 情况1：产品已下架 → 系统应自动赎回，不是报错
- 情况2：产品额度已满 → 系统应自动赎回，不是报错
- 情况3：产品正常 → 正常续期

当前设计缺少情况1和2的处理
```

**修复方案**：

#### 订单状态机（P1 新增）
```
HOLDING (持有中，计息中)
  ↓
MATURITY_REACHED (到期日期)
  ↓
AUTO_RENEW_CHECK (检查是否续期)
  ├─→ auto_renew = 0 或产品不符合 → REDEEM_FALLBACK
  └─→ auto_renew = 1 且产品符合 → RENEW_PROCESSING
  ↓
  ├─→ RENEW_SUCCESS (续期成功，新订单已创建)
  └─→ RENEW_FAILED (续期失败，本息已转入账户)
  ↓
CLOSED
```

#### 自动续期检查逻辑（P1 详细）

1. **获取到期订单**：
```sql
SELECT * FROM wealth_order
WHERE status = 1 AND end_date = CURDATE() AND auto_renew = 1
```

2. **检查产品是否可续期（关键）**：
```sql
SELECT status, sold_quota, total_quota FROM wealth_product

-- 条件1：产品必须在募集中（status = 2）
IF product.status != 2:
  → 降级为赎回
  → 发送通知："产品已下架，将转入账户"
  RETURN

-- 条件2：产品必须有足够额度（本金 + 利息）
new_amount = principal + interest_expected
IF (product.sold_quota + new_amount) > product.total_quota:
  → 降级为赎回
  → 发送通知："产品额度已满，将转入账户"
  RETURN

-- 条件3：用户 KYC 仍有效
IF user.kyc_status != 'VERIFIED':
  → 降级为赎回
  → 发送通知："KYC 过期，无法续期，将转入账户"
  RETURN
```

3. **创建续期订单**：
```sql
INSERT INTO wealth_order (
  user_id, product_id,
  amount = :principal + :interest_expected,
  start_date = CURDATE(),
  end_date = DATE_ADD(CURDATE(), INTERVAL product.duration DAY),
  auto_renew = :user_auto_renew_setting,
  renewed_from_order_id = :old_order_id,  -- 链接原订单
  status = 0  -- 处理中
)

UPDATE wealth_order
SET status = 4,  -- RENEWED
    renewed_to_order_id = :new_order_id  -- 反向链接
WHERE id = :old_order_id
```

4. **降级为赎回的处理**：
```sql
-- 如果续期失败，自动转为赎回
UPDATE wealth_order
SET status = 3  -- FAILED
WHERE id = :old_order_id

-- 本息直接转入用户账户
UPDATE account
SET balance = balance + :principal + :interest
WHERE user_id = :uid AND type = 'WEALTH'

-- 记录流水
INSERT INTO account_journal VALUES (
  ..., biz_type = 'REDEEM_FALLBACK', ref_id = :order_id
)

-- 发送用户通知
INSERT INTO user_notification VALUES (
  user_id = :uid,
  type = 'AUTO_RENEWAL_FAILED',
  content = '因产品[原因]，本息已转入账户，请重新选择产品'
)
```

#### P1 新增字段（wealth_order 表）
```sql
ALTER TABLE wealth_order ADD COLUMN (
  renewed_from_order_id BIGINT,     -- 续期来源的订单ID
  renewed_to_order_id BIGINT,       -- 续期到的新订单ID
  INDEX idx_renewed_from (renewed_from_order_id),
  INDEX idx_renewed_to (renewed_to_order_id)
);

-- status 值扩展：
-- 0 = PROCESSING (处理中)
-- 1 = HOLDING (持有中)
-- 2 = REDEEMED (已赎回)
-- 3 = FAILED (失败 - 包括续期失败)
-- 4 = RENEWED (已续期 - 标记为旧订单)
```

**开发清单**：
- [ ] 实现订单状态机（6 个状态）
- [ ] 添加产品检查逻辑（3 个检查条件）
- [ ] 实现降级处理（转为赎回）
- [ ] 发送用户通知（区分成功/失败/失败原因）
- [ ] 添加 renewed_from/renewed_to 字段
- [ ] 测试：产品下架时续期自动降级为赎回 ✓
- [ ] 测试：产品额度满时续期自动降级为赎回 ✓

---

### P1.2 - 利息派发的完整时间线 🟡

**问题**：
```
原设计缺少：
- 利息何时开始计提？
- 利息如何每日积累？
- 到期日利息如何锁定？
- 赎回日如何入账？
- 预期利息与实际利息的差异如何处理？
```

**修复方案**：

#### 利息时间线（详细）

```
T 日（申购日）
  用户申购 1000 USDT，年化 7%，期限 7 天
  预期总利息 = 1000 * 0.07 / 365 * 7 = 1.34 USDT

  ↓

T+1 日 00:00（起息日）
  系统标记开始计息
  当日不计提（从第二天开始计提）

  ↓

T+1 ~ T+7 日 23:59（计息阶段）
  每日 23:59 执行计息脚本：

  CREATE PROCEDURE daily_interest_accrual()
  BEGIN
    SELECT order_id, amount, apy, start_date, end_date
    FROM wealth_order wo
    JOIN wealth_product wp ON wo.product_id = wp.id
    WHERE wo.status = 1  -- 持有中

    -- 计算当日应计利息
    FOR EACH order:
      days_held = DATEDIFF(CURDATE(), start_date)
      IF days_held >= 1 AND days_held <= duration:
        daily_interest = amount * apy / 365

        -- 记录计提（不入账）
        INSERT INTO wealth_interest_record (
          order_id, amount, type = 1, date = CURDATE()
        )

      -- 如果到期，锁定总利息
      IF CURDATE() >= end_date:
        total_interest = SUM(daily_interest)
        UPDATE wealth_order
        SET interest_expected = :total_interest,
            status = 2  -- 标记为待赎回
      END IF
    END FOR
  END;
  ```

#### 赎回日的利息入账

```
T+8 日 00:00（赎回日+1，到账日）
  执行赎回流程：

  1. 获取利息总额
     SELECT SUM(amount) INTO :total_interest
     FROM wealth_interest_record
     WHERE order_id = :order_id AND type = 1

  2. 用户账户加本金
     UPDATE account SET balance = balance + :principal
     WHERE user_id = :uid

  3. 用户账户加利息
     UPDATE account SET balance = balance + :total_interest
     WHERE user_id = :uid

  4. 系统账户出账（本息）
     UPDATE account SET balance = balance - :principal - :total_interest
     WHERE user_id = -1  -- 系统账户

  5. 记录流水
     INSERT INTO account_journal VALUES (
       ..., biz_type = 'REDEEM_PRINCIPAL', amount = :principal, ...
     )
     INSERT INTO account_journal VALUES (
       ..., biz_type = 'INTEREST_PAYOUT', amount = :total_interest, ...
     )

  6. 标记利息为已派发
     UPDATE wealth_interest_record SET type = 2
     WHERE order_id = :order_id
```

#### 预期利息 vs 实际利息

```
申购时展示给用户：
"预计收益"= 1000 * 0.07 / 365 * 7 = 1.34 USDT

实际到期时：
由于每日精确计息，实际利息可能为 1.33 或 1.35 USDT

差异原因：
- 年化利率的精度问题
- 浮点数运算的四舍五入
- 预期和实际的计息方式略有不同

处理方式：
- 实际利息最多与预期利息差 ±0.01
- 用户可在订单详情查看实际派发金额
- 差异部分由系统账户承担（不影响用户）
```

**开发清单**：
- [ ] 创建每日计息脚本（daily_interest_accrual 存储过程）
- [ ] 每日 23:59 执行计息脚本，计提所有进行中订单的利息
- [ ] 到期日时锁定总利息，更新订单状态
- [ ] 赎回日执行利息入账（记录本金和利息两条流水）
- [ ] 在订单详情展示实际派发的利息金额
- [ ] 测试：7 天订单，验证每日利息累积正确 ✓
- [ ] 测试：到期时利息锁定，不再计提 ✓

---

### P1.3 - 权限控制与审核流程 🟠

**背景**：
```
金融系统必须有明确的权限控制：
- 谁可以上架产品？
- 谁可以发放利息？
- 谁可以冻结用户？
- 所有重要操作都需审计日志
```

**修复方案**：

#### 角色定义（P1 新增）

| 角色 | 权限 | 职责 |
|-----|-----|------|
| **superadmin** | 全部操作 | 系统维护、应急决策 |
| **product_manager** | 产品配置 | 产品上下架、费率调整 |
| **finance_admin** | 财务操作 | 利息派发、对账、调账 |
| **risk_officer** | 风险管理 | 用户冻结、额度调整、异常监控 |
| **compliance** | 合规审查 | 数据导出、审计报告 |
| **support** | 用户支持 | 查询、投诉处理 |

#### 权限矩阵

```
                  | SA | PM | FA | RO | CO | SU
产品上架         | ✓  | ✓  | ✗  | ✗  | ✗  | ✗
调整利率        | ✓  | ✓  | ✗  | ✗  | ✗  | ✗
派发利息        | ✓  | ✗  | ✓  | ✗  | ✗  | ✗
手动调账        | ✓  | ✗  | ✓  | ✗  | ✗  | ✗
冻结用户        | ✓  | ✗  | ✗  | ✓  | ✗  | ✗
调整用户额度    | ✓  | ✗  | ✗  | ✓  | ✗  | ✗
业务冻结/解冻  | ✓  | ✗  | ✗  | ✗  | ✗  | ✗
数据导出        | ✓  | ✗  | ✓  | ✗  | ✓  | ✗
查询订单        | ✓  | ✓  | ✓  | ✓  | ✓  | ✓
```

#### 产品上架审核工作流（P1 新增）

```
产品经理创建产品 (status = PENDING_REVIEW)
  ↓
Finance Admin 审核（检查利率是否合理）
  ├─→ 批准 → next step
  └─→ 拒绝 → status = REJECTED
  ↓
Risk Officer 审核（检查风险额度配置）
  ├─→ 批准 → next step
  └─→ 拒绝 → status = REJECTED
  ↓
SuperAdmin 最终审批
  ├─→ 批准 → status = LIVE (上线销售)
  └─→ 拒绝 → status = REJECTED
```

#### 审计日志（P1 强制）

```sql
CREATE TABLE audit_trail (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  operator_id VARCHAR(64),     -- 操作者 ID
  operator_role VARCHAR(32),   -- 操作者角色
  action VARCHAR(64),          -- 操作类型
  target_id BIGINT,            -- 目标 ID
  target_type VARCHAR(32),     -- 目标类型：PRODUCT/ORDER/ACCOUNT

  old_value JSON,              -- 修改前的值
  new_value JSON,              -- 修改后的值

  reason TEXT,                 -- 操作原因
  ip_address VARCHAR(45),      -- 操作IP

  status ENUM('SUCCESS', 'FAILED'),
  error_message VARCHAR(255),

  created_at DATETIME,
  INDEX idx_operator (operator_id, created_at),
  INDEX idx_action (action, created_at),
  INDEX idx_target (target_id, target_type)
);

-- 示例：金融管理员批准产品上架
INSERT INTO audit_trail VALUES (
  NULL, 'admin_001', 'finance_admin', 'PRODUCT_APPROVAL',
  123, 'PRODUCT',
  JSON_OBJECT('status', 'PENDING'),
  JSON_OBJECT('status', 'APPROVED'),
  '审查利率合理性，同意上架',
  '192.168.1.100', 'SUCCESS', NULL, NOW()
);
```

#### 异常账务调账工作流（P1 新增）

```
对账脚本发现不平衡
  ↓
自动告警，标记 status = PENDING_REVIEW
  ↓
Finance Admin 审查原因
  原因1：系统 Bug → 准备调账方案
  原因2：用户误操作 → 评估是否需要调账
  ↓
Risk Officer 审批
  ├─→ 同意 → next step
  └─→ 拒绝 → 返回查证
  ↓
SuperAdmin 执行调账
  1. 更新账户余额
  2. 记录调账流水（特殊标记）
  3. 记录审计日志
  ↓
Compliance 事后审计（抽查）
```

**表结构**：
```sql
CREATE TABLE account_adjustment (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  account_id BIGINT NOT NULL,
  adjustment_amount DECIMAL(32,16),
  reason VARCHAR(255),

  -- 审批流
  requested_by VARCHAR(64),      -- Finance Admin
  reviewed_by VARCHAR(64),       -- Risk Officer
  approved_by VARCHAR(64),       -- SuperAdmin

  status ENUM('PENDING', 'APPROVED', 'EXECUTED', 'REJECTED'),
  executed_at DATETIME,

  created_at DATETIME,
  INDEX idx_status (status),
  INDEX idx_user_id (user_id)
);
```

**开发清单**：
- [ ] 在用户表添加 role 字段（ENUM）
- [ ] 在操作接口添加权限检查（@RequireRole）
- [ ] 创建 audit_trail 表
- [ ] 所有重要操作都记录审计日志
- [ ] 创建权限检查中间件
- [ ] 管理后台添加权限管理界面
- [ ] 测试：非 finance_admin 无法派发利息 ✓
- [ ] 测试：非 risk_officer 无法冻结用户 ✓

---

## 三、数据库 DDL（必须执行）

```sql
-- 1. 订单状态扩展字段
ALTER TABLE wealth_order ADD COLUMN (
  renewed_from_order_id BIGINT,     -- P1：续期来源
  renewed_to_order_id BIGINT,       -- P1：续期到
  INDEX idx_renewed_from (renewed_from_order_id),
  INDEX idx_renewed_to (renewed_to_order_id)
);

-- 2. 审计日志表
CREATE TABLE audit_trail (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  operator_id VARCHAR(64) NOT NULL,
  operator_role VARCHAR(32) NOT NULL,
  action VARCHAR(64) NOT NULL,
  target_id BIGINT,
  target_type VARCHAR(32),

  old_value JSON,
  new_value JSON,
  reason TEXT,
  ip_address VARCHAR(45),

  status ENUM('SUCCESS', 'FAILED'),
  error_message VARCHAR(255),

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_operator (operator_id, created_at),
  INDEX idx_action (action, created_at),
  INDEX idx_target (target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. 产品审核表
CREATE TABLE wealth_product_approval (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT NOT NULL UNIQUE,

  current_step ENUM('CREATED', 'PENDING_FINANCE', 'PENDING_RISK', 'PENDING_ADMIN', 'APPROVED', 'REJECTED'),

  finance_reviewed_by VARCHAR(64),
  finance_review_at DATETIME,
  finance_approved TINYINT,
  finance_comment TEXT,

  risk_reviewed_by VARCHAR(64),
  risk_review_at DATETIME,
  risk_approved TINYINT,
  risk_comment TEXT,

  admin_approved_by VARCHAR(64),
  admin_approve_at DATETIME,
  admin_approved TINYINT,
  admin_comment TEXT,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_product_id (product_id),
  INDEX idx_current_step (current_step)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. 账户调账表
CREATE TABLE account_adjustment (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  account_id BIGINT NOT NULL,
  adjustment_amount DECIMAL(32,16),
  reason VARCHAR(255),

  requested_by VARCHAR(64),
  requested_at DATETIME,
  reviewed_by VARCHAR(64),
  reviewed_at DATETIME,
  approved_by VARCHAR(64),
  approved_at DATETIME,

  status ENUM('PENDING', 'APPROVED', 'EXECUTED', 'REJECTED'),
  execution_by VARCHAR(64),
  executed_at DATETIME,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_status (status),
  INDEX idx_approved_at (approved_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. 用户通知表
CREATE TABLE user_notification (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  type VARCHAR(64),  -- AUTO_RENEWAL_SUCCESS, AUTO_RENEWAL_FAILED, INTEREST_PAYOUT, etc
  title VARCHAR(255),
  content TEXT,

  channels JSON,  -- ["push", "email", "sms"]

  sent_at DATETIME,
  read_at DATETIME,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 四、定时任务配置

```
-- 每日 23:59 执行利息计提脚本
CRON: 0 59 23 * * *
CALL daily_interest_accrual();

-- 每日 00:00 执行到期赎回和续期逻辑
CRON: 0 0 0 * * *
CALL process_order_maturity();

-- 每小时检查并记录日志（用于审计）
CRON: 0 0 * * * *
CALL audit_log_cleanup();  -- 清理过期日志
```

---

## 五、测试计划

### 自动续期测试
```
用例1：产品正常，续期成功
  投资 1000 USDT，开启续期，到期日检查新订单是否创建 ✓

用例2：产品已下架，续期降级为赎回
  投资 1000 USDT，开启续期，到期前下架产品，
  到期日检查本息是否转入账户，是否发送通知 ✓

用例3：产品额度已满，续期降级为赎回
  产品总额 100，已售 100，用户投资 10（自动续期），
  到期日检查本息是否转入账户 ✓
```

### 利息派发测试
```
用例1：每日利息计提
  投资 1000 USDT，7%，7 天，
  验证每日 23:59 计提的利息金额 ✓

用例2：利息锁定
  到期日前检查 interest_expected = 0（未锁定），
  到期日后检查 interest_expected 已锁定 ✓

用例3：利息入账
  到期日赎回，检查本金+利息是否正确入账 ✓
```

### 权限测试
```
用例1：权限检查
  非 Finance Admin 尝试派发利息 → 403 拒绝 ✓

用例2：审计日志
  产品上架时，验证审计日志已记录 ✓

用例3：工作流审批
  产品创建后需经过 Finance + Risk + Admin 三级审批 ✓
```

---

## 六、上线检查清单

**数据库**：
- [ ] 所有新表已创建（audit_trail, product_approval, account_adjustment 等）
- [ ] renewal_from/renewal_to 字段已添加
- [ ] 索引已创建

**后端代码**：
- [ ] 实现自动续期状态机和降级逻辑
- [ ] 实现每日利息计提脚本
- [ ] 实现利息锁定和入账逻辑
- [ ] 添加权限检查中间件
- [ ] 所有重要操作记录审计日志
- [ ] 产品审核工作流已实现

**前端代码**：
- [ ] 订单详情页显示续期结果（成功/失败/原因）
- [ ] 订单详情页显示实际派发利息
- [ ] 支持修改自动续期设置

**测试**：
- [ ] 自动续期测试（正常、下架、额度满）
- [ ] 利息计提测试（每日积累、锁定、入账）
- [ ] 权限测试（各角色权限隔离）
- [ ] 审计日志测试（所有操作记录）

**文档**：
- [ ] 更新 API 文档（新增字段）
- [ ] 补充工作流文档（产品审核、账务调账）
- [ ] 完善权限文档

---

**总结**：P1 修复涵盖了业务流程的完整性（自动续期）、系统的精确性（利息派发）、管理的规范性（权限审核），是上线前的必要保障。建议用 3-4 天完成开发和测试。
