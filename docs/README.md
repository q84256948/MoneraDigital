# 静态理财产品文档 - 完整索引

## 📚 文档总览

> 本索引包含"静态理财"产品的所有专业文档，包括用户故事、API 规范、集成指南和产品规格。

---

## 📄 文档清单

### 核心文档

#### 1. **产品综合规格 (PRD)**
📄 文件名：`static-finance-prd.md`
🎯 用途：产品的总体规格和所有优化功能点的完整总结
📝 内容：
- 产品定义和目标
- 6 大核心优化功能详解
- 完整功能矩阵
- 4 阶段发布计划
- 技术和业务指标
- 风险管理和合规

⏱️ 阅读时间：15-20 分钟
👥 适用读者：产品经理、项目经理、技术负责人

---

#### 2. **用户故事和需求文档**
📄 文件名：`static-finance-user-stories.md`
🎯 用途：完整的用户故事、验收条件、业务流程
📝 内容：
- 用户角色定义（4 个角色）
- 12 条完整的用户故事 (US)
- 每个故事的验收条件
- 详细的业务流程图
- 数据模型设计
- 非功能需求

⏱️ 阅读时间：25-30 分钟
👥 适用读者：开发团队、QA、产品经理

---

#### 3. **API 规范文档**
📄 文件名：`static-finance-api.md`
🎯 用途：所有 API 端点、请求/响应示例、错误处理
📝 内容：
- 11 个 API 端点分类（理财产品、申购、充提币、交易历史）
- 每个端点的完整请求/响应示例
- 参数说明和验收规则
- 错误代码和解决方案
- Webhook 事件定义

⏱️ 阅读时间：20-25 分钟
👥 适用读者：后端开发、前端开发、集成测试

---

#### 4. **Safeheron 集成指南**
📄 文件名：`safeheron-integration-guide.md`
🎯 用途：充提币与 Safeheron 多签钱包的集成细节
📝 内容：
- 集成架构说明
- 环境配置和认证机制
- 充币流程（地址生成、监听、确认）
- 提币流程（请求、审批、确认）
- Webhook 实时推送处理
- 错误处理和重试策略
- 安全最佳实践
- 监控和告警配置

⏱️ 阅读时间：20-25 分钟
👥 适用读者：后端开发（钱包模块）、DevOps、安全团队

---

## 🔑 6 大核心优化功能点

### 1️⃣ 自动申购 (Auto-Subscribe)
- **文档位置**：`static-finance-user-stories.md` 第 3.1 节 + `static-finance-prd.md` 第 2.1 节
- **API 端点**：PUT `/subscriptions/:subscriptionId/auto-subscribe`
- **用户故事**：US-001、US-002
- **关键特性**：支持 4 种周期、失败重试、邮件通知

### 2️⃣ 利率固定不变 (Fixed Rate)
- **文档位置**：`static-finance-user-stories.md` 第 3.2 节 + `static-finance-prd.md` 第 2.2 节
- **API 端点**：GET `/products/:productId`（包含 `rateFixedUntil` 字段）
- **用户故事**：US-003、US-004
- **关键特性**：利率锁定、公式说明、计算器工具

### 3️⃣ 到期前 3 天邮件提醒 (Maturity Reminder)
- **文档位置**：`static-finance-user-stories.md` 第 3.3 节 + `static-finance-prd.md` 第 2.3 节
- **API 端点**：POST `/webhooks/email/send`（内部）
- **用户故事**：US-005、US-006
- **关键特性**：精确提醒、完整收益明细、确认按钮

### 4️⃣ IP 限制与新加坡小额限制 (Regional Restriction)
- **文档位置**：`static-finance-user-stories.md` 第 3.4 节 + `static-finance-prd.md` 第 2.4 节
- **API 端点**：POST `/subscriptions`（在验证逻辑中）
- **用户故事**：US-007、US-008
- **关键特性**：IP 检测、1 万 U 限额、KYC 升级解除

### 5️⃣ 到期还本付息与利息公式 (Maturity Settlement)
- **文档位置**：`static-finance-user-stories.md` 第 3.5 节 + `static-finance-prd.md` 第 2.5 节
- **API 端点**：GET `/subscriptions/:subscriptionId`（显示利息详情）
- **用户故事**：US-006
- **关键特性**：公式 `利息 = 本金 × 利率 × 天数 / 365`、自动还款、PDF 导出

### 6️⃣ Safeheron 充提币集成 (Safeheron Integration)
- **文档位置**：`safeheron-integration-guide.md` 全文 + `static-finance-api.md` 第 5 节
- **API 端点**：
  - 充币：GET `/wallet/deposit-address`
  - 提币：POST `/wallet/withdraw`、POST `/wallet/withdraw/:withdrawalId/confirm`
- **用户故事**：US-009、US-010、US-011、US-012
- **关键特性**：多签安全、白名单管理、审计日志、多链支持

---

## 🗺️ 文档导航地图

```
/docs
├── static-finance-prd.md              ← ⭐ 从这里开始！
├── static-finance-user-stories.md     ← 详细需求说明
├── static-finance-api.md              ← API 实现参考
├── safeheron-integration-guide.md     ← 钱包集成细节
└── README.md                          ← 本文件
```

### 快速导航

| 我想了解... | 查看文档 | 位置 |
|-----------|---------|------|
| 产品整体架构和功能 | `static-finance-prd.md` | 第 1-2 节 |
| 如何实现自动申购 | `static-finance-user-stories.md` | US-001 |
| 利息计算公式 | `static-finance-prd.md` | 第 2.5 节 |
| 到期提醒邮件内容 | `static-finance-prd.md` | 第 2.3 节 |
| 如何处理 IP 限制 | `static-finance-prd.md` | 第 2.4 节 |
| 充币 API 调用 | `static-finance-api.md` | 第 5.1 节 |
| 提币完整流程 | `safeheron-integration-guide.md` | 第 6 节 |
| 实现 Safeheron 签名 | `safeheron-integration-guide.md` | 第 4 节 |
| 所有错误代码 | `static-finance-api.md` | 第 8 节 |
| 发布计划和里程碑 | `static-finance-prd.md` | 第 4 节 |

---

## 📊 功能优化点对标表

| 优化点 | 在 PRD 中 | 在用户故事中 | 在 API 中 | 在 Safeheron 中 |
|-------|----------|-----------|---------|----------------|
| 自动申购 | 第 2.1 | US-001、US-002 | 第 4.4 | - |
| 利率固定不变 | 第 2.2 | US-003、US-004 | 第 3.2 | - |
| 到期前3天邮件 | 第 2.3 | US-005 | 第 7 | - |
| IP限制新加坡 | 第 2.4 | US-007、US-008 | 第 4.1 | - |
| 利息公式乘以天数 | 第 2.5 | US-006 | 第 4.1 | - |
| Safeheron充提币 | 第 2.6 | US-009~012 | 第 5-6 | 第 5-7 |

---

## 🚀 使用说明

### 对于产品经理
1. 📖 阅读 `static-finance-prd.md` 了解完整的产品设计
2. 📋 参考用户故事理解用户需求
3. 📊 使用功能矩阵进行发布计划

### 对于后端开发
1. 📖 阅读 `static-finance-api.md` 了解 API 规范
2. 👤 查看用户故事中的数据模型设计
3. 🔗 如果涉及 Safeheron，阅读 `safeheron-integration-guide.md`

### 对于前端开发
1. 📖 阅读用户故事中的业务流程图
2. 📄 查看 API 文档中的响应示例
3. 📧 参考邮件模板内容进行 UI 设计

### 对于 QA/测试
1. ✅ 使用用户故事中的验收条件编写测试用例
2. 🔍 参考 API 文档中的请求/响应进行功能测试
3. 🐛 使用错误代码表进行异常测试

### 对于项目经理
1. 📅 查看 `static-finance-prd.md` 第 4 节的 4 阶段发布计划
2. 📊 跟踪第 5 节定义的关键指标
3. ⚠️ 参考第 6 节识别和管理风险

---

## 💡 关键概念速览

### 利息计算公式
```
利息 = 申购金额 × 年化利率 × 实际持有天数 / 365

示例：1,000 USDT × 10% × 90 天 / 365 = 24.66 USDT
```

### 自动申购周期
- 周 (Weekly)
- 月 (Monthly)
- 季度 (Quarterly)
- 年 (Yearly)

### 区域限制规则
```
IF 用户IP = 新加坡 AND 申购金额 < 10,000 USDT THEN
  拒绝申购
END
```

### Safeheron 多签流程
```
提币请求 → 多签人审批 → 交易签名 → 广播到链上 → 确认 (≥6 块)
```

### 4 阶段发布计划
1. **MVP (第 1-2 周)**：基础产品 + 自动申购
2. **Phase 2 (第 3-4 周)**：邮件提醒 + IP 限制
3. **Phase 3 (第 5-7 周)**：Safeheron 集成
4. **Phase 4 (持续)**：优化和增强

---

## 📈 关键指标

### 业务指标 KPI
- 用户申购成功率：≥ 99%
- 到期还款准时率：100%
- 自动申购成功率：≥ 98%
- 邮件送达率：≥ 99%
- Safeheron 交易成功率：≥ 99.9%

### 技术指标
- API 响应时间：< 500ms (P95)
- 系统可用性：99.9%
- 页面加载时间：< 2 秒

---

## 🔗 文档间的关联

```
                    ┌─────────────────┐
                    │  static-finance │
                    │      -prd.md    │
                    │   (总体概览)    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
    ┌─────────────────┐ ┌─────────────┐ ┌──────────────────┐
    │  user-stories   │ │   api.md    │ │ safeheron-guide  │
    │  (详细需求)     │ │ (实现参考)  │ │ (集成指南)       │
    └─────────────────┘ └─────────────┘ └──────────────────┘
            │                   │                │
            │                   │                │
     验收条件、流程           端点定义         API 签名、
      数据模型、           请求/响应           错误处理、
      风险说明             错误代码            Webhook
```

---

## 📞 支持和反馈

如有任何问题或建议，请：
1. 查看相关文档的"常见问题"章节
2. 联系产品团队：product@monera.digital
3. 创建 Issue 或 PR 改进文档

---

## 📋 文档版本历史

| 版本 | 日期 | 更新内容 |
|------|------|---------|
| v1.0 | 2026-01-06 | 初始版本，包含 4 个核心文档 |

---

## 📑 附录：完整的用户故事列表

1. **US-001** - 用户设置自动申购计划
2. **US-002** - 自动申购失败处理
3. **US-003** - 查看产品利率信息
4. **US-004** - 理解利息计算公式
5. **US-005** - 接收到期前 3 天的确认邮件
6. **US-006** - 到期后查看还本付息详情
7. **US-007** - 新加坡用户 1 万 U 以下申购限制
8. **US-008** - 风险提示与合规通知
9. **US-009** - 安全充币
10. **US-010** - 安全提币
11. **US-011** - 提币地址管理
12. **US-012** - 充提币审计日志

---

**最后更新**：2026-01-06
**维护人**：产品团队
**状态**：✅ 完成
