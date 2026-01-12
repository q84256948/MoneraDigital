# 产品需求文档：MoneraDigital托管账户开通功能

## 前言
> **核心目标**：为用户提供安全、便捷的数字资产钱包账户开通服务。通过MoneraDigital的机构级托管技术，用户可以快速激活专属钱包账户，开始进行资产充值和金融服务使用。

---

## 一、版本信息

| 版本号 | 创建日期 | 审核人 |
| :--- | :--- | :--- |
| V1.0.0 | 2026-01-12 | 待定 |

---

## 二、变更日志

| 时间 | 版本号 | 变更人 | 主要变更内容 |
| :--- | :--- | :--- | :--- |
| 2026-01-12 | V1.0.0 | Claude | 文档初始化：Safeheron品牌替换为MoneraDigital自有品牌，添加完整OpenAPI规范 |

---

## 三、文档说明

### 名词解释

| 术语 / 缩略词 | 说明 |
| :--- | :--- |
| **托管账户** | MoneraDigital提供的安全数字资产钱包账户，采用机构级多重签名技术 |
| **钱包地址** | 用户用于接收加密资产充值的区块链地址 |
| **钱包ID** | 系统生成的唯一钱包标识，格式为 `wallet_*` |
| **激活** | 完成钱包账户开通流程，获取专属钱包地址和ID |

---

## 四、需求背景

### 产品现状
用户注册MoneraDigital后，需要开通专属的数字资产钱包账户方可进行资产充值和金融服务使用。目前的账户开通页面需要品牌更新，从第三方托管服务商（Safeheron）升级为MoneraDigital自有的机构级托管服务。

### 业务价值
- **品牌独立性**：强化MoneraDigital自有品牌身份
- **用户信任**：突出MoneraDigital的机构级安全承诺
- **用户体验**：简化一键激活流程，快速获得钱包地址

---

## 五、需求范围

1. **账户开通页面**：展示MoneraDigital品牌的托管账户说明、安全特性、快速激活功能
2. **钱包地址生成与展示**：用户点击激活后，系统返回钱包地址和ID
3. **多语言支持**：英文和中文页面文案
4. **错误处理与重试机制**：网络异常或激活失败时的用户提示

---

## 六、功能详细说明

### 1. 页面流程图

```
用户访问账户开通页面
  ↓
显示"MoneraDigital托管账户"介绍卡片
（包含安全说明、功能特性）
  ↓
点击"立即开通"按钮
  ↓
调用 POST /api/wallet/create 接口
  ↓
状态流转：激活中 → 激活成功 / 激活失败
  ↓
成功：展示钱包地址、ID、复制按钮
失败：显示错误提示和重试按钮
```

### 2. 功能模块详述

#### 模块一：账户开通页面 (Account Opening Page)

**页面目标**：让用户快速理解MoneraDigital的托管服务，一键完成钱包激活。

| 序号 | 区域 | 功能说明 | 交互逻辑 |
| :--- | :--- | :--- | :--- |
| 1 | **页面标题** | "开通资金账户" / "Activate Your Wallet" | 静态展示，体现账户激活主题 |
| 2 | **页面描述** | "使用 MoneraDigital 机构级托管服务创建您的安全数字资产钱包账户。" | 简明扼要说明服务内容 |
| 3 | **主卡片区域** | **卡片标题**："MoneraDigital 托管账户"<br>**卡片描述**："要充值并使用我们的金融服务，您需要先激活您的专属 MoneraDigital 托管账户。" | 重点强调品牌名称和必要性 |
| 4 | **安全提示** | "您的资产受到机构级多重签名托管技术的保护。MoneraDigital 为机构投资者提供安全的数字资产管理服务。" | 红色AlertCircle图标，增强可信度 |
| 5 | **激活按钮** | 按钮文本："立即开通" / "Activate Now"<br>按钮状态：<br>- 初始：可点击<br>- 激活中：Loading动画，文本变为"创建中..."<br>- 激活成功：按钮隐藏，显示成功信息<br>- 激活失败：显示重试按钮 | 点击触发钱包创建流程 |
| 6 | **成功状态** | 显示以下信息：<br>- ✓ "账户开通成功" 绿色标签<br>- "您的首选充值地址" 说明文本<br>- 钱包地址代码块（可复制）<br>- 钱包ID标识<br>- 充值提示文本 | 用户可复制地址用于充值 |
| 7 | **失败状态** | 显示：<br>- ⚠️ "开通失败" 错误标签<br>- 错误原因说明<br>- 重试按钮 | 允许用户重新尝试激活 |
| 8 | **特性卡片区域** | 3张特性卡片：<br>1. "银行级安全" - 多重签名托管<br>2. "即时开通" - 一键获取地址<br>3. "完全透明" - 链上可验证 | 图标+标题+描述，辅助说明服务特性 |

---

## 七、接口规范（OpenAPI 3.0）

### 7.1 创建托管账户

**端点**：`POST /api/wallet/create`

**描述**：为认证用户创建MoneraDigital托管账户，分配唯一钱包地址和ID。

**请求头**：
```
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

**请求体**：
```json
{
  "request_id": "uuid_v4_string",
  "user_id": "integer"
}
```

**字段说明**：
- `request_id` (string, required): UUID v4格式的幂等性标识符，防止重复创建钱包
- `user_id` (integer, required): 当前认证用户ID

**响应（200 OK）**：
```json
{
  "success": true,
  "data": {
    "wallet_id": "wallet_abc123def456",
    "address": "0x1234567890abcdef1234567890abcdef12345678",
    "created_at": "2026-01-12T10:30:00Z",
    "status": "active"
  }
}
```

**响应（400 Bad Request）**：
```json
{
  "success": false,
  "error": {
    "code": "INVALID_REQUEST",
    "message": "request_id must be valid UUID v4"
  }
}
```

**响应（401 Unauthorized）**：
```json
{
  "success": false,
  "error": {
    "code": "AUTH_REQUIRED",
    "message": "Valid JWT token required"
  }
}
```

**响应（409 Conflict）**：
```json
{
  "success": false,
  "error": {
    "code": "WALLET_EXISTS",
    "message": "Wallet already exists for this user"
  }
}
```

**响应（500 Internal Server Error）**：
```json
{
  "success": false,
  "error": {
    "code": "WALLET_CREATION_FAILED",
    "message": "Failed to create wallet. Please try again later."
  }
}
```

---

### 7.2 查询钱包账户状态

**端点**：`GET /api/wallet/status`

**描述**：查询当前用户的钱包账户状态和信息。

**请求头**：
```
Authorization: Bearer <JWT_TOKEN>
```

**查询参数**：无

**响应（200 OK）**：
```json
{
  "success": true,
  "data": {
    "wallet_id": "wallet_abc123def456",
    "address": "0x1234567890abcdef1234567890abcdef12345678",
    "status": "active",
    "created_at": "2026-01-12T10:30:00Z",
    "verified": true
  }
}
```

**响应（401 Unauthorized）**：
```json
{
  "success": false,
  "error": {
    "code": "AUTH_REQUIRED",
    "message": "Valid JWT token required"
  }
}
```

**响应（404 Not Found）**：
```json
{
  "success": false,
  "error": {
    "code": "WALLET_NOT_FOUND",
    "message": "User has not activated wallet yet"
  }
}
```

---

## 八、数据格式定义

### 钱包账户 (Wallet Account)

```typescript
interface WalletAccount {
  wallet_id: string;           // 格式: wallet_* (由系统生成)
  user_id: number;             // 用户ID
  address: string;             // 以太坊格式地址 (0x...)
  address_type: 'ETH' | 'BTC' | 'USDC';  // 地址类型
  status: 'creating' | 'active' | 'suspended';  // 账户状态
  created_at: ISO8601DateTime; // 账户创建时间
  verified: boolean;           // 地址是否验证
}
```

### 幂等性记录 (Idempotency Record)

```typescript
interface IdempotencyRecord {
  request_id: string;          // 幂等性UUID
  user_id: number;             // 用户ID
  wallet_id?: string;          // 关联的钱包ID
  status: 'PROCESSING' | 'SUCCESS' | 'FAILED';
  response_data?: object;      // 成功返回的数据
  error?: {                    // 失败时的错误信息
    code: string;
    message: string;
  };
  created_at: ISO8601DateTime;
  updated_at: ISO8601DateTime;
}
```

---

## 九、错误处理

### 常见错误码

| 错误码 | HTTP状态码 | 说明 | 用户提示 |
| :--- | :--- | :--- | :--- |
| `INVALID_REQUEST` | 400 | 请求参数格式不符合规范 | "请求参数无效，请重试" |
| `AUTH_REQUIRED` | 401 | 缺少有效的JWT Token | "请先登录" |
| `WALLET_EXISTS` | 409 | 用户已有钱包账户 | "您的钱包已开通，无需重复激活" |
| `WALLET_CREATION_FAILED` | 500 | 钱包创建服务故障 | "开通失败，请稍后重试" |
| `WALLET_NOT_FOUND` | 404 | 用户未激活钱包 | "请先开通钱包账户" |

### 重试策略

- **客户端重试**：前端在激活失败时显示重试按钮，用户可手动重新尝试
- **幂等性保证**：同一 `request_id` 的请求在30秒内只处理一次，避免重复创建
- **超时处理**：若30秒内未收到响应，前端显示"处理中，请稍后查看账户状态"

---

## 十、用户流程

### 正常流程
1. 用户登录后访问 `/dashboard/account-opening`
2. 阅读"MoneraDigital托管账户"说明和安全信息
3. 点击"立即开通"按钮
4. 前端生成 `request_id` (UUID v4) 并调用 `POST /api/wallet/create`
5. 后端检查幂等性、用户权限、是否已有钱包
6. 创建新钱包账户，分配地址和ID
7. 前端显示成功状态，用户可复制地址进行充值

### 异常流程

#### 已有钱包
- 如果用户已有钱包账户，接口返回 409 Conflict
- 前端显示："您的钱包已开通，无需重复激活"

#### 网络超时
- 若30秒内无响应，前端显示："开通处理中，请勿重复提交，可在账户信息查看结果"
- 用户可稍后访问 `/api/wallet/status` 查询账户状态

#### 系统故障
- 返回 500 内部错误，前端显示重试按钮
- 用户可点击重试，同一 request_id 不会创建重复钱包

---

## 十一、多语言支持

### 英文 (en)
- Page Title: "Activate Your Wallet"
- Card Title: "MoneraDigital Custody Account"
- Button Text: "Activate Now"
- Success Message: "Your MoneraDigital custody account has been created successfully."

### 中文 (zh)
- 页面标题: "开通资金账户"
- 卡片标题: "MoneraDigital 托管账户"
- 按钮文本: "立即开通"
- 成功提示: "您的 MoneraDigital 托管账户已成功创建。"

---

## 十二、安全考虑

### 认证与授权
- 所有钱包相关API必须验证JWT Token
- 用户只能访问/创建自己的钱包账户
- 服务端校验 `user_id` 与Token中的用户ID匹配

### 幂等性保护
- 前端生成UUID `request_id`，每次请求携带
- 后端记录已处理的 `request_id`，重复请求返回原结果
- 防止网络重传导致的重复钱包创建

### 数据加密
- 钱包地址在传输中使用HTTPS加密
- 敏感信息不存储在本地localStorage（仅存储token）

---

## 十三、测试用例

### 单元测试

| 测试项 | 预期结果 |
| :--- | :--- |
| 页面初始化显示MoneraDigital品牌 | ✓ 显示"MoneraDigital 托管账户" |
| 点击激活按钮进入Loading状态 | ✓ 按钮变灰，显示Loading动画 |
| 激活成功显示钱包地址 | ✓ 展示正确格式的以太坊地址 |
| 激活失败显示重试按钮 | ✓ 显示错误信息和重试按钮 |
| 复制地址功能正常工作 | ✓ 地址成功复制到剪贴板 |

### API测试

| 测试场景 | 请求 | 预期响应 |
| :--- | :--- | :--- |
| 首次激活 | POST /api/wallet/create (有效JWT) | 200 + 钱包地址 |
| 重复激活（同request_id） | POST /api/wallet/create (同request_id) | 200 + 原地址（幂等） |
| 已有钱包 | POST /api/wallet/create (已激活用户) | 409 WALLET_EXISTS |
| 无Token请求 | POST /api/wallet/create (无Authorization) | 401 AUTH_REQUIRED |
| 查询钱包状态 | GET /api/wallet/status (有效JWT) | 200 + 钱包信息 |

### 多语言测试

| 语言 | 测试项 | 验证 |
| :--- | :--- | :--- |
| 英文 | 页面显示英文文案 | ✓ "Activate Your Wallet" |
| 中文 | 页面显示中文文案 | ✓ "开通资金账户" |
| 切换语言 | 页面动态更新为对应语言 | ✓ i18n正确加载 |

---

## 十四、部署与维护

### 前端部署
- 使用 Vercel 自动化部署
- 构建命令：`npm run build`
- 部署地址：https://www.moneradigital.com/dashboard/account-opening

### 后端API部署
- Vercel Serverless Functions
- 接口路径：`api/wallet/create` 和 `api/wallet/status`
- 环境变量需配置：`JWT_SECRET`、`DATABASE_URL`

### 监控告警
- 监控钱包创建失败率，目标 < 0.1%
- 监控API响应时间，目标 < 2秒
- 失败率或响应时间异常时触发告警

---

## 十五、版本更新计划

### v1.1 规划（Q1 2026）
- [ ] 支持更多地址类型（Bitcoin、USDC等）
- [ ] 增加钱包地址验证功能
- [ ] 支持多钱包账户管理

### v2.0 规划（Q2 2026）
- [ ] 集成链上KYC验证
- [ ] 支持冷热钱包切换
- [ ] 增加钱包安全设置（2FA、提现限额等）

---

## 附录 A：OpenAPI 3.0 完整规范

```yaml
openapi: 3.0.0
info:
  title: MoneraDigital Wallet Management API
  description: API for MoneraDigital custody wallet account management
  version: 1.0.0
  contact:
    name: MoneraDigital Support
    url: https://www.moneradigital.com

servers:
  - url: https://www.moneradigital.com/api
    description: Production Server
  - url: http://localhost:8080/api
    description: Local Development Server

paths:
  /wallet/create:
    post:
      summary: Create a new wallet account
      description: Creates a new MoneraDigital custody wallet for the authenticated user
      operationId: createWallet
      tags:
        - Wallet Management
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - request_id
                - user_id
              properties:
                request_id:
                  type: string
                  format: uuid
                  description: UUID v4 idempotency identifier
                user_id:
                  type: integer
                  description: Authenticated user ID
      responses:
        '200':
          description: Wallet created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/WalletCreateResponse'
        '400':
          description: Invalid request parameters
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '401':
          description: Unauthorized - missing or invalid JWT token
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '409':
          description: Conflict - wallet already exists for user
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '500':
          description: Internal server error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
      security:
        - BearerAuth: []

  /wallet/status:
    get:
      summary: Get wallet account status
      description: Retrieves the current wallet status for the authenticated user
      operationId: getWalletStatus
      tags:
        - Wallet Management
      responses:
        '200':
          description: Wallet status retrieved successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/WalletStatusResponse'
        '401':
          description: Unauthorized - missing or invalid JWT token
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '404':
          description: Wallet not found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '500':
          description: Internal server error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
      security:
        - BearerAuth: []

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: JWT token for authentication

  schemas:
    WalletCreateResponse:
      type: object
      properties:
        success:
          type: boolean
          example: true
        data:
          type: object
          properties:
            wallet_id:
              type: string
              example: wallet_abc123def456
            address:
              type: string
              example: "0x1234567890abcdef1234567890abcdef12345678"
            created_at:
              type: string
              format: date-time
            status:
              type: string
              enum: [creating, active, suspended]
              example: active

    WalletStatusResponse:
      type: object
      properties:
        success:
          type: boolean
          example: true
        data:
          type: object
          properties:
            wallet_id:
              type: string
            address:
              type: string
            status:
              type: string
              enum: [creating, active, suspended]
            created_at:
              type: string
              format: date-time
            verified:
              type: boolean

    ErrorResponse:
      type: object
      properties:
        success:
          type: boolean
          example: false
        error:
          type: object
          properties:
            code:
              type: string
              example: INVALID_REQUEST
            message:
              type: string
              example: Invalid request parameters
```

---

*最后更新：2026-01-12*
*文档维护人：Claude Code*
