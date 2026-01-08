# P0 关键修复总结 - 定期理财系统

**审计日期**：2026-01-08
**修复优先级**：🔴 **必须在开发前完成**
**风险等级**：CRITICAL - 影响资金安全与合规

---

## 一、修复概览

本文档总结了定期理财系统的 **5 个关键 P0 修复**，涉及并发控制、幂等性保证、账务闭环等金融系统必要条件。

| 序号 | 修复项 | 风险 | 解决方案 | 影响范围 |
|-----|------|------|--------|---------|
| 1 | 并发超卖 | 🔴 HIGH | SELECT FOR UPDATE + 乐观锁 | 申购流程 |
| 2 | 重复提交 | 🔴 HIGH | idempotency_record 表 + request_id | 申购、划转、赎回 |
| 3 | Safeheron 重复创建 | 🔴 HIGH | wallet_creation_request 表 | 钱包开户流程 |
| 4 | 账务不平衡 | 🔴 CRITICAL | 系统账户 + 每小时对账 | 整个理财系统 |
| 5 | 划转失败 | 🟠 MEDIUM | transfer_record 表 + transfer_id | 划转流程 |

---

## 二、详细修复说明

### P0.1 - 并发超卖防护 🔴

**风险场景**：
```
T1 线程：检查产品额度 ✓ → 申购 100 元
T2 线程：检查产品额度 ✓ → 申购 100 元
实际结果：产品被超卖了 100 元（应该总额 200 上限，现在 300）
```

**修复方案**：

1. **使用 SELECT FOR UPDATE 锁定行**（在事务读阶段）
```sql
BEGIN;
SELECT id, sold_quota, total_quota
FROM wealth_product
WHERE id = :pid
FOR UPDATE;  -- 此时其他线程无法修改

IF (sold_quota + amount) > total_quota:
  ROLLBACK;  抛出异常
ELSE:
  UPDATE wealth_product SET sold_quota = sold_quota + :amount
  COMMIT;
END;
```

2. **保留乐观锁版本号机制**（在 UPDATE 阶段验证）
```sql
UPDATE wealth_product
SET sold_quota = sold_quota + :amount, version = version + 1
WHERE id = :pid AND version = :current_version

IF rows_affected = 0:
  -- 版本号不匹配，重试
```

3. **混合方案的优势**：
   - SELECT FOR UPDATE：保证读阶段的一致性
   - 乐观锁：保证 UPDATE 时的版本正确性
   - 结合：既安全又高效（不会长期持有锁）

**开发清单**：
- [ ] 修改申购接口，添加 SELECT FOR UPDATE 逻辑
- [ ] 确保事务隔离级别为 REPEATABLE_READ 或 SERIALIZABLE
- [ ] 添加单元测试：并发申购场景（100 线程同时申购）
- [ ] 性能测试：锁定时间控制在 50ms 以内

---

### P0.2 - 重复提交防护 🔴

**风险场景**：
```
用户弱网环境：
1. 点击"确认申购" → 请求发送
2. 网络延迟 5 秒无响应
3. 用户以为失败，再次点击
4. 后台两笔扣款都成功 ❌ 资金损失
```

**修复方案**：

#### 前端防护（30 秒去重）
```javascript
// 生成唯一请求 ID
const requestId = generateUUID();
sessionStorage.setItem('subscriptionRequestId', requestId);

// 标记已发送，防止重复
const sendTime = Date.now();
if (sessionStorage.getItem('subscriptionInProgress')) {
  const elapsed = Date.now() - sendTime;
  if (elapsed < 30000) {
    showToast('订单处理中，请勿重复提交');
    return;
  }
}

// 发送请求
fetch('/api/wealth/subscribe', {
  body: JSON.stringify({
    request_id: requestId,  // ← 关键
    product_id, amount, ...
  })
});
```

#### 后端幂等检查（idempotency_record 表）
```sql
-- 表结构
CREATE TABLE idempotency_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  request_id VARCHAR(128) NOT NULL UNIQUE,  -- UUID
  biz_type VARCHAR(32) NOT NULL,  -- SUBSCRIBE, TRANSFER, REDEEM
  status ENUM('PROCESSING', 'SUCCESS', 'FAILED'),
  result_data JSON,  -- 成功时返回 {order_id: ...}
  error_message VARCHAR(255),
  created_at DATETIME,
  completed_at DATETIME,
  ttl_expire_at DATETIME,  -- 24小时后过期
  UNIQUE KEY uk_user_req (user_id, request_id, biz_type)
);

-- 使用流程
1. 首先检查幂等性记录
   SELECT * FROM idempotency_record
   WHERE user_id = :uid AND request_id = :req_id AND biz_type = 'SUBSCRIBE'

2. 如果已存在：
   - status = SUCCESS → 直接返回 result_data（不扣款）
   - status = PROCESSING → 返回 "订单处理中，请稍候"
   - status = FAILED → 允许用户重新提交（新 request_id）

3. 如果不存在：
   - 创建记录（status = PROCESSING）
   - 执行扣款流程
   - 更新记录（status = SUCCESS/FAILED）
```

**开发清单**：
- [ ] 创建 idempotency_record 表
- [ ] 申购、划转、赎回接口都添加幂等性检查
- [ ] 前端生成并提交 request_id
- [ ] 添加每日清理脚本（删除 ttl_expire_at < NOW() 的记录）
- [ ] 测试：同一 request_id 提交 5 次，只扣款 1 次 ✓

---

### P0.3 - Safeheron 幂等性防护 🔴

**风险场景**：
```
用户多次点击"开通"按钮：
1. 第一次：创建 wallet_A
2. 第二次：创建 wallet_B（重复）
3. 第三次：创建 wallet_C（重复）
结果：Safeheron 侧创建了 3 个钱包，系统混乱 ❌
```

**修复方案**：

#### 表结构
```sql
CREATE TABLE wallet_creation_request (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL UNIQUE,  -- 同一用户只有一条记录
  request_id VARCHAR(128) NOT NULL,
  status ENUM('PENDING', 'CREATING', 'SUCCESS', 'FAILED'),
  safeheron_wallet_id VARCHAR(128),  -- Safeheron 返回的 ID
  coin_address VARCHAR(256),  -- 充值地址
  error_message VARCHAR(255),
  retry_count INT DEFAULT 0,
  created_at DATETIME,
  updated_at DATETIME
);
```

#### 后端逻辑
```
1. 前端生成 request_id (UUID) 并提交

2. 后端检查流程：
   SELECT * FROM wallet_creation_request WHERE user_id = :uid

   IF 记录存在:
     IF status = 'SUCCESS':
       ✓ 返回已有的 coin_address（不调用 Safeheron）
     ELSE IF status = 'CREATING':
       返回 "账户开通中，请稍候"
     ELSE IF status = 'FAILED':
       允许重试（retry_count + 1）
   ELSE:
     创建新记录 (status = 'CREATING')
     调用 Safeheron API
     更新记录为 SUCCESS

3. 即使用户多次点击，Safeheron 也只会被调用 1 次
```

**前端流程**：
```javascript
// 生成 request_id
const requestId = generateUUID();

// 发送开户请求
POST /api/wallet/create {
  request_id: requestId
}

// 后端返回：
{
  status: 'SUCCESS',
  coin_address: 'TU9...',  // 或
  status: 'CREATING',
  message: '账户开通中...'  // 轮询或等待
}
```

**开发清单**：
- [ ] 创建 wallet_creation_request 表
- [ ] 前端生成并提交 request_id
- [ ] 后端添加幂等性检查逻辑
- [ ] 添加重试机制（最多 3 次）
- [ ] 测试：用户快速点击 10 次，Safeheron 只被调用 1 次 ✓

---

### P0.4 - 系统账户与账务闭环 🔴 **最关键**

**风险场景**：
```
没有系统账户的后果：
- 用户 A 申购 1000 USDT → 用户账户 -1000
- 用户 B 申购 1000 USDT → 用户账户 -1000
- 总共用户侧扣了 2000 USDT
- 但系统侧无人持有这 2000 USDT → 账务不平衡 ❌
```

**修复方案**：

#### 强制实现系统账户
```sql
-- 创建系统账户（user_id = -1）
INSERT INTO account
(user_id, type, currency, balance, frozen, version, created_at)
VALUES (-1, 'SYSTEM_WEALTH', 'USDT', 0, 0, 0, NOW());

-- 账务永远平衡：
Σ(用户理财账户余额) = 系统账户余额
```

#### 申购时的双向记账
```sql
-- 用户申购 100 USDT
BEGIN;

-- 1. 用户账户扣款
UPDATE account SET balance = balance - 100, version = version + 1
WHERE user_id = :uid AND type = 'WEALTH'

-- 2. 系统账户收款
UPDATE account SET balance = balance + 100, version = version + 1
WHERE user_id = -1 AND type = 'SYSTEM_WEALTH'

-- 3. 记录双向流水
INSERT INTO account_journal VALUES (
  ..., user_id = :uid, account_id = :user_wealth_account_id,
  amount = -100, biz_type = 'SUBSCRIBE_DEDUCT', ...
)
INSERT INTO account_journal VALUES (
  ..., user_id = -1, account_id = :system_account_id,
  amount = +100, biz_type = 'SUBSCRIBE_CREDIT', ...
)

COMMIT;
```

#### 赎回时的反向记账
```sql
-- 用户赎回 100 + 5 息 = 105 USDT
BEGIN;

-- 1. 用户账户收钱
UPDATE account SET balance = balance + 105, version = version + 1
WHERE user_id = :uid AND type = 'WEALTH'

-- 2. 系统账户付钱
UPDATE account SET balance = balance - 105, version = version + 1
WHERE user_id = -1 AND type = 'SYSTEM_WEALTH'

-- 3. 记录流水（省略）

COMMIT;
```

#### 每小时对账脚本（CRITICAL）
```sql
CALL reconcile_wealth_accounts();

-- 内部逻辑：
SELECT COALESCE(SUM(balance), 0)
INTO @user_total
FROM account
WHERE type = 'WEALTH' AND user_id > 0;

SELECT balance
INTO @system_balance
FROM account
WHERE user_id = -1 AND type = 'SYSTEM_WEALTH';

IF ABS(@system_balance - @user_total) > 0.0001:
  -- 立即告警
  INSERT INTO reconciliation_alert_log
  VALUES (NOW(), 'BALANCE_MISMATCH', @user_total, @system_balance, ..., 'CRITICAL');

  -- 冻结业务
  UPDATE business_freeze_status SET is_frozen = 1,
    freeze_reason = '账务不平衡，已冻结理财业务';

  -- 发送紧急告警（邮件、钉钉、短信）
  CALL send_alert('账户不平衡！用户总额: ' || @user_total ||
                 ', 系统账户: ' || @system_balance);
```

**核心原则**：
- ✅ 系统账户 **强制实现**，不可省略
- ✅ 所有资金操作都是 **双向记账**
- ✅ 每小时自动对账，失衡立即冻结
- ✅ 这是金融系统的 **基础保证**

**开发清单**：
- [ ] 创建系统账户（user_id = -1）
- [ ] 修改申购、赎回流程，添加系统账户的对应操作
- [ ] 创建 reconciliation_log、reconciliation_alert_log 表
- [ ] 实现每小时对账脚本（cron job）
- [ ] 实现业务冻结机制（business_freeze_status 表）
- [ ] 申购、赎回、划转等接口都检查冻结状态
- [ ] 测试：申购 10 笔，对账检查账务是否平衡 ✓

---

### P0.5 - 划转幂等性防护 🟠

**风险场景**：
```
用户划转 500 USDT 时：
1. 请求发送 → 资金账户 -500，理财账户 +500
2. 网络中断，用户无法知道是否成功
3. 用户再次发起划转请求
4. 结果：资金账户 -500 两次 ❌
```

**修复方案**：

```sql
-- transfer_record 表
CREATE TABLE transfer_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  transfer_id VARCHAR(64) NOT NULL UNIQUE,  -- 前端生成
  from_account_id BIGINT NOT NULL,
  to_account_id BIGINT NOT NULL,
  amount DECIMAL(32,16) NOT NULL,
  status ENUM('PENDING', 'SUCCESS', 'FAILED'),
  created_at DATETIME,
  completed_at DATETIME
);

-- 使用流程
1. 前端生成唯一的 transfer_id（如 "transfer_2026010801_u123_xxx"）

2. 后端检查：
   SELECT * FROM transfer_record WHERE transfer_id = :transfer_id

   IF 记录存在:
     IF status = 'SUCCESS':
       返回第一次的结果（不重复转账）
     ELSE:
       返回"正在处理中"
   ELSE:
     创建记录（status = PENDING）
     执行转账
     更新记录（status = SUCCESS/FAILED）

3. 即使用户多次提交，只有第一次会真正转账
```

**开发清单**：
- [ ] 创建 transfer_record 表
- [ ] 划转接口添加 transfer_id 检查
- [ ] 前端生成唯一的 transfer_id
- [ ] 异常时用户可查询划转记录了解状态
- [ ] 测试：同一 transfer_id 提交 5 次，只转账 1 次 ✓

---

## 三、数据库 DDL（必须执行）

```sql
-- 1. 幂等性记录表
CREATE TABLE idempotency_record (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  request_id VARCHAR(128) NOT NULL,
  biz_type VARCHAR(32) NOT NULL,
  status ENUM('PROCESSING', 'SUCCESS', 'FAILED'),
  result_data JSON,
  error_message VARCHAR(255),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME,
  ttl_expire_at DATETIME,
  UNIQUE KEY uk_user_req (user_id, request_id, biz_type),
  INDEX idx_user_id (user_id),
  INDEX idx_status (status),
  INDEX idx_ttl (ttl_expire_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Safeheron 钱包创建请求表
CREATE TABLE wallet_creation_request (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE,
  request_id VARCHAR(128) NOT NULL,
  status ENUM('PENDING', 'CREATING', 'SUCCESS', 'FAILED'),
  safeheron_wallet_id VARCHAR(128),
  coin_address VARCHAR(256),
  error_message VARCHAR(255),
  retry_count INT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. 划转记录表
CREATE TABLE transfer_record (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  transfer_id VARCHAR(64) NOT NULL UNIQUE,
  from_account_id BIGINT NOT NULL,
  to_account_id BIGINT NOT NULL,
  amount DECIMAL(32,16) NOT NULL,
  status ENUM('PENDING', 'SUCCESS', 'FAILED'),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME,
  INDEX idx_user_id (user_id),
  INDEX idx_transfer_id (transfer_id),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. 系统账户（特殊账户）
INSERT INTO account
(user_id, type, currency, balance, frozen, version, created_at, updated_at)
VALUES (-1, 'SYSTEM_WEALTH', 'USDT', 0, 0, 0, NOW(), NOW());

-- 5. 对账日志表
CREATE TABLE reconciliation_log (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  check_time DATETIME,
  type VARCHAR(32),
  user_total DECIMAL(32,16),
  system_balance DECIMAL(32,16),
  difference DECIMAL(32,16),
  status ENUM('SUCCESS', 'WARNING', 'CRITICAL'),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_check_time (check_time),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. 告警日志表
CREATE TABLE reconciliation_alert_log (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  alert_time DATETIME,
  type VARCHAR(32),
  description TEXT,
  user_total DECIMAL(32,16),
  system_balance DECIMAL(32,16),
  difference DECIMAL(32,16),
  status ENUM('CRITICAL', 'WARNING') DEFAULT 'CRITICAL',
  resolved_at DATETIME,
  resolution_notes TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_alert_time (alert_time),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. 业务冻结状态表
CREATE TABLE business_freeze_status (
  id INT PRIMARY KEY DEFAULT 1,
  is_frozen TINYINT DEFAULT 0,
  freeze_reason TEXT,
  frozen_at DATETIME,
  unfrozen_at DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO business_freeze_status
(id, is_frozen) VALUES (1, 0);
```

---

## 四、接口修改清单

### 申购接口 POST /api/wealth/subscribe
```javascript
请求体：{
  product_id: 123,
  amount: 100,
  auto_renew: true,
  request_id: "uuid-xxx"  // ← 新增：客户端生成的请求ID
}

响应：{
  code: 0,
  data: {
    order_id: 456,
    status: 'pending',
    amount: 100,
    interest_expected: 1.92
  }
}
```

**后端逻辑变更**：
- [ ] 添加 request_id 参数接收
- [ ] 查询 idempotency_record，检查是否已处理
- [ ] 添加 SELECT FOR UPDATE 锁定逻辑
- [ ] 同时更新用户和系统账户
- [ ] 创建幂等性记录并更新状态

### 划转接口 POST /api/transfer
```javascript
请求体：{
  from_type: 'FUND',    // 资金账户
  to_type: 'WEALTH',    // 理财账户
  amount: 500,
  transfer_id: "uuid-xxx"  // ← 新增：客户端生成的划转ID
}
```

**后端逻辑变更**：
- [ ] 添加 transfer_id 参数接收
- [ ] 查询 transfer_record，检查是否已执行
- [ ] 记录划转状态（PENDING → SUCCESS/FAILED）

### 钱包开户接口 POST /api/wallet/create
```javascript
请求体：{
  request_id: "uuid-xxx"  // ← 新增：客户端生成的请求ID
}

响应：{
  status: 'success',
  coin_address: 'TU9...',
  wallet_id: 'w_xxx'
}
// 或
{
  status: 'creating',
  message: '账户开通中，请稍候'
}
```

**后端逻辑变更**：
- [ ] 添加 request_id 参数接收
- [ ] 查询 wallet_creation_request，检查用户是否已开户
- [ ] 防止重复调用 Safeheron API

---

## 五、对账脚本（定时任务）

### 每小时：完整对账（CRITICAL）
```sql
-- 检查所有用户的理财账户总额是否等于系统账户余额
CALL reconcile_wealth_accounts();
```

**执行**：
```
每小时 00:00 执行（如 01:00, 02:00, 03:00...）
如发现不平衡，立即冻结业务并告警
```

### 每天 01:00：流水对账
```sql
-- 验证每笔流水的余额快照是否正确
CALL reconcile_journal_accuracy();
```

### 每天 02:00：幂等性检查
```sql
-- 清理过期的幂等记录，检查僵尸请求
DELETE FROM idempotency_record WHERE ttl_expire_at < NOW();

SELECT COUNT(*) FROM idempotency_record
WHERE status = 'PROCESSING'
AND TIMESTAMPDIFF(MINUTE, created_at, NOW()) > 5;
-- 如果有记录，说明存在卡住的请求
```

---

## 六、前端开发指南

### 1. 生成 request_id
```typescript
import { v4 as uuidv4 } from 'uuid';

const generateRequestId = (): string => {
  return uuidv4();
};
```

### 2. 申购流程
```typescript
async function submitSubscription(data) {
  const requestId = generateRequestId();

  // 防止 30 秒内重复提交
  const inProgress = sessionStorage.getItem('subscriptionInProgress');
  if (inProgress && Date.now() - parseInt(inProgress) < 30000) {
    showToast('订单处理中，请勿重复提交');
    return;
  }

  sessionStorage.setItem('subscriptionInProgress', Date.now().toString());

  try {
    const res = await fetch('/api/wealth/subscribe', {
      method: 'POST',
      body: JSON.stringify({
        ...data,
        request_id: requestId
      })
    });

    if (res.ok) {
      showToast('申购成功');
      // 刷新订单列表
      refetchOrders();
    } else {
      showToast(res.error || '申购失败，请重试');
    }
  } finally {
    sessionStorage.removeItem('subscriptionInProgress');
  }
}
```

### 3. 处理超时
```typescript
const timeoutPromise = new Promise((_, reject) =>
  setTimeout(() => reject(new Error('TIMEOUT')), 30000)
);

try {
  await Promise.race([fetchPromise, timeoutPromise]);
} catch (e) {
  if (e.message === 'TIMEOUT') {
    showToast('订单处理中，请勿重复提交，可在订单记录查看结果');
  }
}
```

---

## 七、测试计划

### 并发测试
```
场景：100 个用户同时申购，产品总额 100
预期：恰好 100 个成功，之后的都返回"额度不足"
验证：product.sold_quota = 100，未超卖
```

### 重复提交测试
```
场景：同一个 request_id，提交 5 次
预期：只扣款 1 次，其他 4 次返回已有结果
验证：account.balance 只变化一次
```

### 账务平衡测试
```
场景：申购 10 笔，赎回 5 笔
预期：每次操作后，Σ(user_balance) = system_balance
验证：对账脚本通过
```

### Safeheron 防重复测试
```
场景：用户快速点击开通按钮 10 次
预期：Safeheron API 只被调用 1 次
验证：wallet_creation_request 表中只有 1 条 SUCCESS 记录
```

---

## 八、上线检查清单

**数据库**：
- [ ] 所有新表已创建
- [ ] 系统账户已初始化（user_id = -1）
- [ ] 索引已创建

**后端代码**：
- [ ] 申购接口添加 SELECT FOR UPDATE 逻辑
- [ ] 所有接口添加 request_id/transfer_id 检查
- [ ] 每小时对账脚本已部署
- [ ] 业务冻结检查已添加到所有资金操作接口

**前端代码**：
- [ ] 申购、划转、开户都生成 request_id
- [ ] 超时处理已实现
- [ ] 用户提示文案已更新

**测试**：
- [ ] 并发测试通过
- [ ] 重复提交测试通过
- [ ] 账务对账测试通过
- [ ] 集成测试通过

**监控告警**：
- [ ] 对账告警已配置
- [ ] 业务冻结告警已配置
- [ ] 幂等性重复率监控已配置

---

## 九、常见问题解答

**Q: 为什么需要系统账户？**
A: 复式记账的基础。用户的钱去哪了？必须有"对手方"账户（系统账户）来承载。否则账务无法平衡，监管审计无法通过。

**Q: request_id 保留多久？**
A: 24 小时（ttl_expire_at）。超过 24 小时的请求可以安全删除。

**Q: 账户失衡怎么办？**
A: 立即：
1. 冻结所有理财业务
2. 发送紧急告警
3. 标记为待人工审查
4. 排查原因，手动调账后解冻

**Q: 对账脚本失败会怎样？**
A: 自动重试 3 次，仍失败则告警，运维团队处理。

---

**审计提交人**：Eric
**审计报告**：见 System_Design_Wealth_Account.md
**最后更新**：2026-01-08
