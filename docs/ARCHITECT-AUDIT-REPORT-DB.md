# 数据库设计审计报告

**审计对象**: `docs/静态理财/需求文档MD/数据库表字典.md`
**审计日期**: 2026年1月9日
**审计人**: 架构师 Agent

---

## 1. 总体评价

**评分**: **A- (优秀，但需适配)**

该设计文档提出了一套成熟的、金融级别的账户系统架构。相比现有的代码实现，引入了**复式记账（Double-Entry Bookkeeping）**思想、**统一账户中心**和**完善的风控审计**机制，显著提升了系统的资金安全性和数据完整性。

然而，设计文档采用了 **MySQL** 语法规范，而项目当前通过 Drizzle ORM 使用 **PostgreSQL** 数据库。直接实施需要进行数据库方言的适配和类型调整。

---

## 2. 核心发现与风险 (Critical Findings)

### 🚨 2.1 数据库方言不匹配 (MySQL vs PostgreSQL)
文档及配套 SQL 脚本基于 MySQL 语法，与现有 PostgreSQL 架构存在冲突：
- **自增主键**: 文档暗示 `AUTO_INCREMENT`，PostgreSQL 应使用 `SERIAL` 或 `BIGSERIAL`。
- **时间类型**: 文档使用 `DATETIME`，PostgreSQL 应使用 `TIMESTAMP` 或 `TIMESTAMPTZ`。
- **枚举类型**: 文档使用 `TINYINT` 表示状态，PostgreSQL 推荐使用 `ENUM` 或 `SMALLINT` + Check 约束。
- **JSON处理**: PostgreSQL 的 `JSONB` 类型性能优于 MySQL 的 `JSON`，建议利用 `JSONB` 的索引特性。

### 🚨 2.2 精度与数值类型 (Precision)
- **现状**: 文档定义金额为 `DECIMAL(32,16)`。
- **风险**: 对于 ETH 或 ERC-20 代币（通常 18 位小数），16 位小数精度会导致**精度丢失**（截断最后 2 位）。
- **建议**:
  - **方案 A (推荐)**: 使用 PostgreSQL 的 `NUMERIC` 类型（不指定精度，或指定更高精度如 `NUMERIC(78, 30)`）以支持任意精度。
  - **方案 B**: 存储为原子单位（Wei），使用 `NUMERIC` 或字符串处理（避免 JS Number 溢出）。

### 2.3 命名规范冲突
- **新旧冲突**: 现有代码大量使用 `lending_` 前缀（如 `lending_positions`），新设计全面采用 `wealth_` 前缀（如 `wealth_product`, `wealth_order`）。
- **建议**: 采纳新设计。`Wealth`（理财）比 `Lending`（借贷）更准确地描述了"定期理财/Fixed Deposit"业务。需要制定迁移计划。

---

## 3. 架构亮点 (Architectural Highlights)

该设计在以下方面表现出色，建议完全采纳：

1.  **统一账户模型 (`account` + `account_journal`)**:
    - 引入系统账户（`user_id = -1`），实现资产变动的双向记录（用户资产减少 = 系统资产增加），确保账目永远平衡。
    - `frozen_balance` 字段的设计完美解决了提现时的并发和资金锁定问题。

2.  **并发控制**:
    - `version` 字段的引入（乐观锁）有效防止了高并发下的超扣风险。
    - `idempotency_record` 表的设计为所有资金操作提供了统一的幂等性保障。

3.  **风控与审计**:
    - `audit_trail` 和 `risk_alert` 表的引入填补了当前系统的风控空白。
    - `account_reconciliation` 明确了定期对账的机制。

---

## 4. 与现有代码 (`src/db/schema.ts`) 的差异

| 现有表 (`schema.ts`) | 建议对应表 (`表字典.md`) | 变更说明 |
| :--- | :--- | :--- |
| `users` | (未在文档详述) | 需保留现有 `users` 表，新增 KYC 字段或关联 `user_kyc` 表。 |
| `lending_positions` | `wealth_order` | **重大重构**。需迁移数据。新表增加了 `interest_expected` 快照和更细的状态管理。 |
| `withdrawal_addresses` | `withdrawal_address_whitelist` | 字段扩充（别名、验证方式）。 |
| `withdrawals` | `withdrawal_order` | 状态机更复杂（8种状态 vs 现有3-4种），新增链上确认时间字段。 |
| (无) | `wealth_product` | **新增**。目前产品可能是硬编码的，新设计支持动态配置产品。 |
| (无) | `account` | **新增**。核心资产表，不再直接从 `lending_positions` 聚合计算余额。 |

---

## 5. 实施建议 (Actionable Recommendations)

1.  **Schema 定义优先**:
    - 不要直接执行 SQL 脚本。请使用 **Drizzle ORM** 在 `src/db/schema.ts` 中定义新表结构。
    - 利用 Drizzle 的类型安全特性来处理 PostgreSQL 的枚举和时间类型。

2.  **类型修正**:
    ```typescript
    // 建议的 Drizzle 定义
    balance: decimal("balance", { precision: 78, scale: 30 }).notNull(), // 提升精度
    status: varchar("status", { length: 32 }), // 或使用 pgEnum
    createdAt: timestamp("created_at").defaultNow(),
    ```

3.  **分阶段迁移策略**:
    - **阶段 1**: 创建新表（`wealth_*`, `account_*`），保持现有表不变。
    - **阶段 2**: 双写（Double Write）或编写一次性脚本，根据现有 `lending_positions` 初始化 `account` 表的余额，并迁移订单数据到 `wealth_order`。
    - **阶段 3**: 切换读取逻辑至新表，废弃旧表。

4.  **补充缺失**:
    - 文档中未详细定义 `users` 表，建议沿用现有 `users` 表，并通过外键关联。

## 6. 结论

该数据库设计文档质量高，逻辑严密，是系统向"机构级"迈进的关键一步。**强烈建议在修复上述"精度"和"方言"问题后予以采纳。**
