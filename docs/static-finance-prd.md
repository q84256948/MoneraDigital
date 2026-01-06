# 静态理财产品 - 综合需求规格 (PRD)

## 📋 文档导航

本产品的完整文档包括以下部分：

| 文档 | 文件名 | 用途 |
|------|--------|------|
| **用户故事文档** | `static-finance-user-stories.md` | 完整的用户故事、验收条件、业务流程 |
| **API 规范文档** | `static-finance-api.md` | 所有 API 端点、请求/响应示例、错误处理 |
| **Safeheron 集成** | `safeheron-integration-guide.md` | 充提币与 Safeheron 的集成细节 |
| **本文档** | `static-finance-prd.md` | 产品总体规格和优化功能点总结 |

---

## 1. 产品总体规格

### 产品名称
**静态理财** (Static Finance)

### 产品定义
静态理财是一款基于区块链的数字资产理财产品，用户通过购买理财产品获得稳定的收益。核心特性包括自动申购、固定利率、智能到期提醒和安全的 Safeheron 托管。

### 产品目标

**商业目标**：
- 吸引超过 10,000 名用户在 6 个月内
- 产品发行总额达到 1,000 万 USDT
- 用户投诉率 ≤ 0.1%
- 平台 NPS 评分 ≥ 50

**技术目标**：
- 99.9% 系统可用性
- API 响应时间 < 500ms
- 支持日均 10万+ 并发用户

---

## 2. 核心优化功能点

### 2.1 自动申购（Auto-Subscribe）

**功能说明**：用户设置后，系统将在指定周期自动申购产品，无需手动操作。

**优化特性**：
- ✅ 支持 4 种申购周期：周、月、季度、年
- ✅ 自动申购失败时发送邮件通知并允许重试
- ✅ 用户可随时修改或取消自动申购设置
- ✅ 显示下次申购日期和预期收益

**业务规则**：
```
自动申购触发条件：
1. 用户启用自动申购
2. 当前时间 = 下次申购日期
3. 账户余额 ≥ 申购金额
4. 产品状态 = "active"

申购失败处理：
- 余额不足：发送"请充值"提示邮件，24小时后重试
- 产品下线：取消申购计划，发送"产品变更"通知
- 系统异常：记录错误，30分钟后重试（最多3次）
```

**数据库字段**（Subscription 表）：
```
autoSubscribe: boolean           # 是否启用自动申购
subscribeCycle: enum             # 周期：weekly/monthly/quarterly/yearly
nextSubscribeDate: datetime      # 下次申购日期
lastSubscribeDate: datetime      # 最后申购日期
```

---

### 2.2 利率固定不变（Fixed Rate）

**功能说明**：产品发行时确定的年化利率在产品周期内不变，给用户充分的收益确定性。

**优化特性**：
- ✅ 产品详情页清晰标注"利率固定，产品期限内不变"
- ✅ 显示"利率锁定至"日期
- ✅ 利率变更需提前 7 天通知已购用户
- ✅ 历史利率数据可查询

**保证机制**：
```
1. 产品上线后，利率不可修改
2. 利率锁定时间 = 产品周期（如 90 天产品锁定 90 天）
3. 新产品发行时可调整利率
4. 所有已申购用户享受申购时的利率
```

**示例**：
```
产品名称：90天稳定理财
申购日期：2026-01-06
到期日期：2026-04-06
年化利率：10%（锁定至 2026-04-06）

用户 A 在 2026-01-06 申购 → 享受 10% 利率
即使 2026-02-01 产品利率调至 8%，用户 A 仍享受 10%
```

---

### 2.3 到期前 3 天邮件提醒（Maturity Reminder）

**功能说明**：系统在产品到期前 3 个工作日自动发送邮件，提醒用户即将到期并确认收益。

**优化特性**：
- ✅ 精确提醒：到期前 3 个工作日（不含周末/节假日）
- ✅ 邮件包含完整的收益明细（本金、利息、总额）
- ✅ 可选"确认"按钮用于用户主动确认
- ✅ 邮件中提醒检查充值地址是否正确

**邮件内容模板**：
```
主题：您的理财产品即将到期 - 请确认收益详情

尊敬的用户，

您的理财产品将于 [到期日期] 到期，现在向您发送本金和利息的详细信息。

【产品信息】
产品名称：[产品名称]
申购金额：[金额] USDT
年化利率：[利率]%
申购日期：[日期]
到期日期：[日期]

【收益明细】
本金：[金额] USDT
利息：[金额] USDT（含天数计算因子）
合计：[总金额] USDT

【重要提示】
✓ 本金 + 利息将在到期日当天自动转入您的账户
✓ 请确认您的充值地址正确，以便成功收款
✓ 如对收益有疑问，请点击下方"了解详情"

[确认收益] [了解详情] [联系客服]

此邮件由系统自动发送，请勿回复。
```

**技术实现**：
```python
from datetime import datetime, timedelta

def send_maturity_reminders():
    """每日定时任务：发送到期前3天的邮件"""

    # 查询到期日期 = 今天 + 3 天 的产品
    three_days_later = datetime.now() + timedelta(days=3)

    subscriptions = Subscription.query.filter(
        Subscription.endDate == three_days_later.date(),
        Subscription.status == "active",
        Subscription.remindingSent == False
    )

    for sub in subscriptions:
        # 计算收益
        interest = calculate_interest(
            principal=sub.principal,
            rate=sub.annualRate,
            days=sub.duration
        )

        # 发送邮件
        send_email(
            to=sub.user.email,
            template="maturity_reminder",
            context={
                "productName": sub.productName,
                "principal": sub.principal,
                "interest": interest,
                "total": sub.principal + interest,
                "endDate": sub.endDate
            }
        )

        # 标记邮件已发送
        sub.remindingSent = True
        sub.remindingAt = datetime.now()
        db.session.commit()
```

---

### 2.4 IP 限制与地区风险管理（Regional Restriction）

**功能说明**：对来自新加坡的用户，限制小额申购（1万 U 以下）以控制风险。

**优化特性**：
- ✅ 实时 IP 地址检测（使用 MaxMind GeoIP2 或类似服务）
- ✅ 检测规则清晰：新加坡 + 申购额 < 1万 U = 拒绝
- ✅ 拒绝时提供清晰的错误提示和解决方案
- ✅ 支持通过 KYC 升级或增加申购额解除限制

**限制规则**：
```
IF 用户IP属于新加坡 THEN
  IF 申购金额 < 10,000 USDT THEN
    拒绝申购
    返回错误信息："该产品对小额申购有地区限制"
    显示解决方案：
      1. 增加申购金额至 ≥ 1万 U
      2. 完成高级 KYC 认证
      3. 联系客服申请白名单
  ELSE
    允许申购
  END
END
```

**Python 实现**：
```python
import geoip2.database

def check_regional_restriction(user_ip, amount):
    """检查地区限制"""

    # 初始化 GeoIP 数据库
    reader = geoip2.database.Reader('/path/to/GeoLite2-Country.mmdb')

    # 查询 IP 信息
    response = reader.country(user_ip)
    country_code = response.country.iso_code

    # 检查是否来自新加坡
    if country_code == 'SG' and amount < 10000:
        raise RegionalRestrictionError(
            message="申购金额必须 ≥ 1万 USDT"，
            suggestions=[
                "增加申购金额至 ≥ 1万 U",
                "完成高级 KYC 认证",
                "联系客服申请白名单"
            ]
        )

    return True
```

**KYC 升级流程**：
```
用户点击"升级 KYC"
    ↓
完成高级身份认证（护照、地址证明等）
    ↓
系统审核（1-2 个工作日）
    ↓
KYC 通过
    ↓
地区限制解除，用户可申购任何金额
```

---

### 2.5 到期还本付息与利息计算（Maturity Settlement）

**功能说明**：产品到期时，系统自动将本金和利息转入用户账户，利息计算公式包含天数因子。

**优化特性**：
- ✅ 到期日当天或次日自动还款
- ✅ 利息公式：`利息 = 本金 × 年化利率 × 实际持有天数 / 365`
- ✅ 支持查看详细的收益明细和计算过程
- ✅ 可导出收益证明为 PDF

**利息计算公式**：
```
利息 = 申购金额 × 年化利率 × 实际持有天数 / 365

示例 1：完整 90 天产品
  申购金额：1,000 USDT
  年化利率：10%
  申购日期：2026-01-06
  到期日期：2026-04-06（90 天）
  利息 = 1,000 × 10% × 90 / 365 = 24.66 USDT

示例 2：中途到期产品
  申购金额：1,000 USDT
  年化利率：10%
  申购日期：2026-01-06
  到期日期：2026-02-10（35 天，假设用户中途赎回）
  利息 = 1,000 × 10% × 35 / 365 = 9.59 USDT
```

**重要说明**：
- 利息以日计算，精确到小数点后 2 位（USDT）
- 不支持提前赎回（产品到期日前无法提取）
- 利息在到期日一次性支付，无复利

**数据库设计**：
```sql
-- 申购记录表
CREATE TABLE subscriptions (
    id VARCHAR(32) PRIMARY KEY,
    user_id VARCHAR(32),
    product_id VARCHAR(32),
    amount DECIMAL(18, 2),
    annual_rate DECIMAL(5, 2),  -- 年化利率 %
    start_date DATETIME,
    end_date DATETIME,
    days INT,                    -- 实际持有天数
    expected_interest DECIMAL(18, 2),
    actual_interest DECIMAL(18, 2),
    principal DECIMAL(18, 2),
    status ENUM('active', 'matured', 'redeemed'),
    settled_at DATETIME,
    created_at DATETIME,
    updated_at DATETIME
);

-- 还本付息流程
BEGIN TRANSACTION;
  -- 1. 创建转账记录
  INSERT INTO transfers (user_id, amount, type, description, status)
  VALUES (?, amount + interest, 'withdrawal', 'Maturity Settlement', 'pending');

  -- 2. 更新用户余额
  UPDATE user_balances SET balance = balance + (amount + interest)
  WHERE user_id = ?;

  -- 3. 更新申购记录
  UPDATE subscriptions
  SET status = 'matured', actual_interest = ?, settled_at = NOW()
  WHERE id = ?;

  -- 4. 记录利息收益
  INSERT INTO user_earnings (user_id, interest, subscription_id, earned_at)
  VALUES (?, interest, ?, NOW());
COMMIT;
```

**还本付息流程图**：
```
定时任务 (每日午夜 00:00)
    ↓
查询所有到期日期 = 今天的申购记录
    ↓
FOR EACH 到期申购 DO
  计算利息：interest = principal × rate × days / 365
    ↓
  创建转账记录（status=pending）
    ↓
  更新用户余额：balance += (principal + interest)
    ↓
  更新申购状态：status='matured', settled_at=now()
    ↓
  记录收益数据
    ↓
  发送"还款完成"邮件
    ↓
  邮件包含：金额、交易哈希、时间戳
END FOR
```

---

### 2.6 充提币与 Safeheron 集成（Safeheron Integration）

**功能说明**：集成 Safeheron 多签钱包，实现安全的充提币功能，用户资金由 Safeheron 多签托管。

**优化特性**：
- ✅ 充币地址由 Safeheron API 生成，自动监听链上确认
- ✅ 提币需二次验证（邮件 + 身份验证）并通过 Safeheron 多签审批
- ✅ 白名单地址管理，新增地址需 24 小时冷却期
- ✅ 完整的充提币审计日志
- ✅ 支持多链和多币种

**充币流程**：
```
1. 用户点击"充币"按钮
2. 系统调用 Safeheron API: POST /wallet/create_deposit_address
   - chainCode: "ETH"
   - tokenAddress: "0xdac17f958d2ee523a2206206994597c13d831ec7"（USDT）
3. Safeheron 返回充币地址：0x1234567890abcdef...
4. 用户从交易所/钱包转账至该地址
5. 系统轮询 Safeheron API 监听链上确认
6. 收到 ≥6 个区块确认后
7. 更新用户余额
8. 发送"充币成功"邮件
```

**提币流程**：
```
1. 用户点击"提币"按钮
2. 输入提币地址和金额
3. 系统检查：
   - 地址是否在白名单
   - 金额是否在限额内
   - 账户余额是否充足
4. 检查通过后，发送"提币确认"邮件（含确认链接）
5. 用户点击邮件链接，进行二次验证
6. 系统调用 Safeheron API: POST /wallet/create_withdraw_request
7. 提交 Safeheron 多签钱包审批
8. Safeheron 多签人审批（通常 15-30 分钟）
9. 审批通过后，Safeheron 签名并广播交易
10. 监听链上确认 (≥6 个区块)
11. 更新用户余额（扣除本金和手续费）
12. 发送"提币完成"邮件
```

**支持的币种和网络**：
| 币种 | 网络 | 手续费 |
|------|------|--------|
| USDT | Ethereum | 2 USDT |
| USDT | Polygon | 0.5 USDT |
| USDT | BNB Chain | 0.5 USDT |
| USDC | Ethereum | 2 USDC |
| ETH | Ethereum | 0.01 ETH |

**白名单地址管理**：
```
用户可添加、编辑、删除收款地址
- 新增地址：需邮件确认 + 24小时冷却期
- 删除地址：需二次确认
- 每个用户最多可添加 10 个地址
```

**提币限额设置**：
| 用户等级 | 单笔限额 | 单日限额 | 冷却期 |
|---------|---------|---------|-------|
| 新用户 | 5,000 USDT | 10,000 USDT | 新地址 24h |
| 普通用户 | 50,000 USDT | 100,000 USDT | 新地址 24h |
| VIP 用户 | 无限 | 无限 | 无 |

详见：`safeheron-integration-guide.md`

---

## 3. 完整的产品功能矩阵

| 功能 | MVP | Phase 2 | Phase 3 | Phase 4 |
|------|-----|--------|--------|--------|
| **理财产品** | ✅ | ✅ | ✅ | ✅ |
| 产品列表展示 | ✅ | ✅ | ✅ | ✅ |
| 产品详情 | ✅ | ✅ | ✅ | ✅ |
| 固定利率说明 | ✅ | ✅ | ✅ | ✅ |
| 利息计算器 | ❌ | ✅ | ✅ | ✅ |
| **申购功能** | ✅ | ✅ | ✅ | ✅ |
| 手动申购 | ✅ | ✅ | ✅ | ✅ |
| **自动申购** | ❌ | ✅ | ✅ | ✅ |
| 申购列表 | ✅ | ✅ | ✅ | ✅ |
| 申购详情 | ✅ | ✅ | ✅ | ✅ |
| **邮件通知** | ✅ | ✅ | ✅ | ✅ |
| 申购确认邮件 | ✅ | ✅ | ✅ | ✅ |
| 自动申购通知 | ❌ | ✅ | ✅ | ✅ |
| **到期提醒** | ❌ | ✅ | ✅ | ✅ |
| 到期前 3 天邮件 | ❌ | ✅ | ✅ | ✅ |
| 还款完成通知 | ❌ | ✅ | ✅ | ✅ |
| **还本付息** | ✅ | ✅ | ✅ | ✅ |
| 自动还款 | ✅ | ✅ | ✅ | ✅ |
| 收益明细 | ✅ | ✅ | ✅ | ✅ |
| 导出收益证明 | ❌ | ❌ | ✅ | ✅ |
| **IP 限制** | ❌ | ✅ | ✅ | ✅ |
| 新加坡 IP 检测 | ❌ | ✅ | ✅ | ✅ |
| 小额限制规则 | ❌ | ✅ | ✅ | ✅ |
| **充提币** | ❌ | ❌ | ✅ | ✅ |
| 充币地址生成 | ❌ | ❌ | ✅ | ✅ |
| 充币监听确认 | ❌ | ❌ | ✅ | ✅ |
| **Safeheron 集成** | ❌ | ❌ | ✅ | ✅ |
| 提币请求 | ❌ | ❌ | ✅ | ✅ |
| 多签审批 | ❌ | ❌ | ✅ | ✅ |
| 地址白名单 | ❌ | ❌ | ✅ | ✅ |
| Webhook 推送 | ❌ | ❌ | ✅ | ✅ |
| **数据和报表** | ❌ | ❌ | ❌ | ✅ |
| 交易历史导出 | ❌ | ❌ | ❌ | ✅ |
| 年度收益报告 | ❌ | ❌ | ❌ | ✅ |
| 税务证明生成 | ❌ | ❌ | ❌ | ✅ |

---

## 4. 发布计划详细版

### Phase 1 (MVP) - 2 周
**交付物**：
- 基础理财产品 CRUD
- 手动申购和赎回
- 利息计算和到期还款
- 基础邮件通知

**KPI**：
- 产品上线 1 个
- 用户注册 100+
- 申购成功率 ≥ 98%

### Phase 2 - 2 周
**交付物**：
- ✅ 自动申购功能
- ✅ IP 限制和地区管理
- ✅ 到期前 3 天邮件提醒
- ✅ 增强的邮件模板

**KPI**：
- 自动申购启用率 ≥ 30%
- 邮件送达率 ≥ 99%
- 邮件打开率 ≥ 60%

### Phase 3 - 3 周
**交付物**：
- ✅ Safeheron 充币集成
- ✅ Safeheron 提币集成
- ✅ 白名单地址管理
- ✅ 完整的审计日志

**KPI**：
- 充提币成功率 ≥ 99.5%
- Safeheron 交易确认时间 < 5 分钟
- 用户投诉率 ≤ 0.1%

### Phase 4 - 持续优化
**交付物**：
- 用户反馈优化
- 性能优化和监控增强
- 安全审计和加固
- 监管合规增强
- 数据报表和导出功能

---

## 5. 关键技术指标

### 5.1 性能指标

| 指标 | 目标 | 测量方法 |
|------|------|---------|
| API 响应时间 | < 500ms (P95) | APM 工具（如 New Relic） |
| 页面加载时间 | < 2 秒 | Lighthouse / WebPageTest |
| 数据库查询时间 | < 100ms | 数据库慢查询日志 |
| 系统可用性 | 99.9% | 监控告警系统 |

### 5.2 安全指标

| 指标 | 目标 |
|------|------|
| API 签名验证通过率 | 100% |
| HTTPS 使用率 | 100% |
| 密钥轮换周期 | 每 90 天 |
| 安全测试覆盖率 | 100% |

### 5.3 业务指标

| 指标 | 目标 |
|------|------|
| 用户申购成功率 | ≥ 99% |
| 到期还款准时率 | 100% |
| 自动申购成功率 | ≥ 98% |
| 用户投诉率 | ≤ 0.1% |
| 邮件送达率 | ≥ 99% |
| Safeheron 交易成功率 | ≥ 99.9% |

---

## 6. 风险和缓解措施

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| Safeheron 服务中断 | 用户无法充提币 | 建立备用充提币方案，监控告警 |
| 利息计算错误 | 用户损失或平台亏损 | 详细的单元测试，人工抽查 |
| 邮件系统故障 | 用户无法收到通知 | 使用多个邮件服务商，重试机制 |
| 地区限制绕过 | 政策合规风险 | IP 黑名单、异常检测 |
| 自动申购失败 | 用户体验下降 | 自动重试、邮件通知、人工介入 |

---

## 7. 合规和监管

### 7.1 必需的合规措施

- [ ] KYC/AML 身份验证
- [ ] 产品销售许可（根据地区要求）
- [ ] 用户协议和风险提示
- [ ] 反洗钱监控
- [ ] 交易异常检测
- [ ] 年度审计报告

### 7.2 需要展示的信息

- [ ] 产品风险提示（强制勾选）
- [ ] 平台资质和监管信息
- [ ] 客户保护措施说明
- [ ] 利息计算公式和示例
- [ ] 到期还款承诺

---

## 8. 后续迭代计划

**Quarter 2 (Q2) 2026**：
- 用户推荐返佣功能
- 产品组合功能（一键申购多个产品）
- 社区和讨论区

**Quarter 3 (Q3) 2026**：
- 借贷功能
- 期权理财产品
- AI 推荐引擎

**Quarter 4 (Q4) 2026**：
- 跨链理财（支持更多公链）
- NFT 理财产品
- 企业级 API 接口

---

## 9. 相关资源

- **用户故事**：`static-finance-user-stories.md`
- **API 文档**：`static-finance-api.md`
- **Safeheron 集成**：`safeheron-integration-guide.md`
- **数据库设计**：`database-schema.md`（待创建）
- **前端设计稿**：`designs/` 目录
- **测试计划**：`test-plan.md`（待创建）

---

**文档版本**：v1.0
**最后更新**：2026-01-06
**维护人**：产品团队
**状态**：生效中
