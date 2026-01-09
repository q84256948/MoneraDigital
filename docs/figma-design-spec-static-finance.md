# Monera Digital 静态理财：Figma UI/UX 设计规范手册

## 1. 设计目标与原则
- **安全背书 (Security-First)**：通过 UI 强化“Safeheron 硬件冷钱包托管”的安全感。
- **透明度 (Transparency)**：通过利息日历和收益曲线，让金融数据可视化。
- **高效交互 (Efficiency)**：减少用户输入，支持“最大化”填充与自动逻辑。

---

## 2. 信息架构 (Information Architecture)

### 2.1 页面树结构
1. **理财首页 (Earn Hub)**
   - 资产总览 (My Assets Snapshot)
   - 定期产品列表 (Fixed Deposit List) - **按 APR 降序排序**
2. **申购确认弹窗 (Subscription Dialog)**
   - 输入模块：金额、起购限额提示。
   - 配置模块：自动续购开关 (Auto-Reinvest)。
   - 合规提示：新加坡 IP 拦截提示。
3. **资产持仓详情 (Position Details)**
   - 收益日历 (Interest Calendar)
   - 订单状态流转 (Status Timeline)
4. **提币流程 (Withdrawal Flow)**
   - 安全验证 (2FA)
   - 审批进度条 (Safeheron Multi-sig Progress)

---

## 3. 核心 UI 组件规范 (Component Specs)

### 3.1 产品卡片 (Product Card)
- **标题**：产品名称（中/英）。
- **指标**：APR（大字，强调）、期限（Days）、起投金额。
- **状态标签**：售罄（Sold Out）、火热（Hot）、即将到期（Expiring）。
- **背书**：页脚显示 `Secured by Safeheron` 微标。

### 3.2 申购输入框 (Subscription Input)
- **Max 按钮**：右侧内置“最大”按钮，点击自动填充钱包全部余额。
- **动态报错**：
  - **场景**：新加坡 IP 且金额 < 10,000 USDT。
  - **设计**：输入框变红，下方出现 Micro-copy：“根据合规要求，当前地区起购金额为 10,000 USDT”。

### 3.3 自动续购 Toggle (Auto-Reinvest Switch)
- **设计**：使用带有状态解释的 Toggle。
- **交互提示**：开启时，在下方显示预览文案：“到期后本息将自动续投 [X] 天产品，预计产生复利收益 [Y] USDT”。

---

## 4. 关键页面设计指南

### 4.1 自动续购逻辑（UI 触发点）
- **利率策略**：利率变产品不变。
- **UI 设计**：在订单详情中，若系统利率发生变化，开关旁显示小图标：“下次续购将应用新利率 (X%)”。

### 4.2 收益日历 (Yield Calendar)
- **视觉化**：模仿 Apple Health 的趋势图或日历打点图。
- **数据项**：每日派息金额、派息时间、对应的 Safeheron 链上存管凭证。

### 4.3 提币审批进度条 (Multi-sig Progress Bar)
- **阶段 1**：用户发起 (User Initialized)。
- **阶段 2**：多签审批中 (Safeheron Multi-sig Pending) - *显示 2/3 或 3/5 进度*。
- **阶段 3**：区块链确认中 (On-chain Confirming)。
- **阶段 4**：完成 (Completed)。

---

## 5. 极端情况处理 (Edge Cases Design)

| 极端场景 | UI 表现建议 |
| :--- | :--- |
| **自动续购失败** | 弹出红色全局通知，提示“由于额度售罄，自动续购失败，本金已退回钱包”。 |
| **滑点预警** | 非 USDT 申购时，若汇率剧烈波动，显示警告：“当前市场波动较大，可能导致申购撤销”。 |
| **维护中** | 产品操作按钮置灰，显示“系统对账中，请在 12:00 后重试”。 |

---

## 6. 邮件模板设计规范 (Email Templates)

### 6.1 到期确认确认邮件 (Maturity Reminder)
- **时间**：到期前 3 天。
- **视觉要求**：
  - 顶部：Monera Digital 品牌 Logo。
  - 中部：产品到期提醒（产品名、到期时间、预期本息）。
  - 底部：显著的“调整自动申购状态”按钮。
  - 脚注：安全提醒与 Safeheron 托管说明。

---

## 7. 交互说明 (Prototyping Notes)
- **点击理财卡片**：直接滑出 Bottom Sheet（App 端）或 右侧抽屉（Web 端）。
- **利率排序**：理财列表顶部提供“按利率”、“按期限”的 Tab 切换。
- **动画建议**：数字增长动画，利息派发时数字向上滑入。
