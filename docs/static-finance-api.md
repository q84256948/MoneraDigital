# 静态理财 - API 规范文档

## 1. 概述

本文档定义了"静态理财"产品的所有 API 端点。所有 API 都使用 REST 风格，基于 HTTPS，返回 JSON 格式的响应。

### 基础信息
- **Base URL**: `https://api.monera.digital/v1`
- **认证方式**: Bearer Token (JWT)
- **Content-Type**: `application/json`
- **超时时间**: 30 秒

---

## 2. 认证

### 请求头示例
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

---

## 3. 理财产品 API

### 3.1 获取产品列表

**请求**
```
GET /products?status=active&page=1&limit=20
```

**参数**
| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| status | string | 否 | 产品状态：active/offline/closed |
| page | integer | 否 | 分页页码（默认1） |
| limit | integer | 否 | 每页数量（默认20） |

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 5,
    "page": 1,
    "limit": 20,
    "items": [
      {
        "id": "prod_001",
        "name": "90天稳定理财",
        "description": "年化10%的稳定理财产品",
        "annualRate": 10.0,
        "duration": 90,
        "minAmount": 100,
        "maxAmount": 1000000,
        "status": "active",
        "rateFixedUntil": "2027-01-06T00:00:00Z",
        "createdAt": "2026-01-06T00:00:00Z"
      }
    ]
  }
}
```

---

### 3.2 获取产品详情

**请求**
```
GET /products/:productId
```

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": "prod_001",
    "name": "90天稳定理财",
    "description": "年化10%的稳定理财产品",
    "annualRate": 10.0,
    "duration": 90,
    "minAmount": 100,
    "maxAmount": 1000000,
    "status": "active",
    "rateFixedUntil": "2027-01-06T00:00:00Z",
    "interestFormula": {
      "description": "利息 = 申购金额 × 年化利率 × 实际持有天数 / 365",
      "example": {
        "principal": 1000,
        "annualRate": 10,
        "days": 30,
        "interest": 8.22
      }
    },
    "createdAt": "2026-01-06T00:00:00Z",
    "updatedAt": "2026-01-06T00:00:00Z"
  }
}
```

---

## 4. 申购 API

### 4.1 创建申购订单

**请求**
```
POST /subscriptions
```

**请求体**
```json
{
  "productId": "prod_001",
  "amount": 1000,
  "enableAutoSubscribe": true,
  "subscribeCycle": "monthly"
}
```

**参数说明**
| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| productId | string | 是 | 产品ID |
| amount | number | 是 | 申购金额（USDT） |
| enableAutoSubscribe | boolean | 否 | 是否启用自动申购（默认false） |
| subscribeCycle | string | 否 | 申购周期：weekly/monthly/quarterly/yearly |

**预检查**
```
- 检查用户IP是否来自新加坡
- 如果来自新加坡 AND 申购金额 < 10,000，返回错误
- 检查产品是否在线
- 检查用户账户余额是否充足
- 检查申购金额是否在产品限额内
```

**响应示例 - 成功**
```json
{
  "code": 200,
  "message": "subscription created successfully",
  "data": {
    "subscriptionId": "sub_2026010601001",
    "productId": "prod_001",
    "productName": "90天稳定理财",
    "amount": 1000,
    "principal": 1000,
    "expectedInterest": 24.66,
    "startDate": "2026-01-06T10:30:00Z",
    "endDate": "2026-04-06T00:00:00Z",
    "status": "active",
    "autoSubscribe": true,
    "subscribeCycle": "monthly",
    "nextSubscribeDate": "2026-02-06T10:30:00Z"
  }
}
```

**响应示例 - IP限制**
```json
{
  "code": 403,
  "message": "subscription amount must be greater than 10,000 USDT for users in this region",
  "errorCode": "REGION_LIMIT_EXCEEDED"
}
```

**响应示例 - 余额不足**
```json
{
  "code": 400,
  "message": "insufficient balance",
  "errorCode": "INSUFFICIENT_BALANCE",
  "data": {
    "required": 1000,
    "current": 500
  }
}
```

---

### 4.2 获取申购列表

**请求**
```
GET /subscriptions?status=active&page=1&limit=20
```

**参数**
| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| status | string | 否 | 状态：active/matured/redeemed |
| page | integer | 否 | 分页页码 |
| limit | integer | 否 | 每页数量 |

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 3,
    "items": [
      {
        "subscriptionId": "sub_2026010601001",
        "productName": "90天稳定理财",
        "amount": 1000,
        "principal": 1000,
        "expectedInterest": 24.66,
        "actualInterest": 24.66,
        "startDate": "2026-01-06T10:30:00Z",
        "endDate": "2026-04-06T00:00:00Z",
        "status": "active",
        "daysRemaining": 90,
        "progressPercentage": 0
      }
    ]
  }
}
```

---

### 4.3 获取申购详情

**请求**
```
GET /subscriptions/:subscriptionId
```

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "subscriptionId": "sub_2026010601001",
    "productId": "prod_001",
    "productName": "90天稳定理财",
    "amount": 1000,
    "principal": 1000,
    "expectedInterest": 24.66,
    "actualInterest": null,
    "startDate": "2026-01-06T10:30:00Z",
    "endDate": "2026-04-06T00:00:00Z",
    "status": "active",
    "autoSubscribe": true,
    "subscribeCycle": "monthly",
    "nextSubscribeDate": "2026-02-06T10:30:00Z",
    "daysRemaining": 90,
    "progressPercentage": 0,
    "interestDetails": {
      "formula": "principal × annualRate × days / 365",
      "principal": 1000,
      "annualRate": 10,
      "days": 90,
      "interest": 24.66
    }
  }
}
```

---

### 4.4 修改自动申购设置

**请求**
```
PUT /subscriptions/:subscriptionId/auto-subscribe
```

**请求体**
```json
{
  "enableAutoSubscribe": false
}
```

**响应示例**
```json
{
  "code": 200,
  "message": "auto-subscribe setting updated",
  "data": {
    "subscriptionId": "sub_2026010601001",
    "autoSubscribe": false
  }
}
```

---

## 5. 充提币 API

### 5.1 获取充币地址

**请求**
```
GET /wallet/deposit-address
```

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "address": "0x1234567890abcdef1234567890abcdef12345678",
    "currency": "USDT",
    "network": "ethereum",
    "qrCode": "data:image/png;base64,...",
    "memo": null,
    "generatedAt": "2026-01-06T10:30:00Z",
    "expiresAt": "2026-01-13T10:30:00Z"
  }
}
```

---

### 5.2 查询充币状态

**请求**
```
GET /wallet/deposit-status/:txHash
```

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "txHash": "0xabcd...ef12",
    "status": "confirmed",
    "confirmations": 12,
    "requiredConfirmations": 6,
    "amount": 1000,
    "currency": "USDT",
    "depositedAt": "2026-01-06T10:30:00Z",
    "confirmedAt": "2026-01-06T10:45:00Z"
  }
}
```

---

### 5.3 申请提币

**请求**
```
POST /wallet/withdraw
```

**请求体**
```json
{
  "address": "0x9876543210fedcba9876543210fedcba98765432",
  "amount": 500,
  "currency": "USDT"
}
```

**参数说明**
| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| address | string | 是 | 目标钱包地址 |
| amount | number | 是 | 提币金额 |
| currency | string | 是 | 币种：USDT/USDC/ETH等 |

**预检查**
```
- 验证用户身份
- 检查地址是否在白名单中
- 检查提币金额限制
- 检查账户余额
- 计算手续费
```

**响应示例 - 成功**
```json
{
  "code": 200,
  "message": "withdrawal initiated",
  "data": {
    "withdrawalId": "wd_2026010601001",
    "status": "pending_confirmation",
    "address": "0x9876543210fedcba9876543210fedcba98765432",
    "amount": 500,
    "fee": 2,
    "netAmount": 498,
    "currency": "USDT",
    "nextStep": "Check your email for confirmation link",
    "expiresAt": "2026-01-06T11:30:00Z"
  }
}
```

**响应示例 - 地址未白名单**
```json
{
  "code": 400,
  "message": "address is not in whitelist",
  "errorCode": "ADDRESS_NOT_WHITELISTED",
  "data": {
    "suggestions": "Add this address to whitelist first"
  }
}
```

---

### 5.4 确认提币

**请求**
```
POST /wallet/withdraw/:withdrawalId/confirm
```

**请求体**
```json
{
  "verificationCode": "123456"
}
```

**响应示例**
```json
{
  "code": 200,
  "message": "withdrawal confirmed",
  "data": {
    "withdrawalId": "wd_2026010601001",
    "status": "submitted_to_safeheron",
    "address": "0x9876543210fedcba9876543210fedcba98765432",
    "amount": 500,
    "safeheronTxId": "sh_txn_12345678",
    "message": "Withdrawal submitted to Safeheron for multi-sig approval"
  }
}
```

---

### 5.5 获取提币历史

**请求**
```
GET /wallet/withdrawals?status=completed&page=1&limit=20
```

**参数**
| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| status | string | 否 | 状态：pending/submitted/completed/failed |
| page | integer | 否 | 分页页码 |
| limit | integer | 否 | 每页数量 |

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 5,
    "items": [
      {
        "withdrawalId": "wd_2026010601001",
        "status": "completed",
        "address": "0x9876543210fedcba9876543210fedcba98765432",
        "amount": 500,
        "fee": 2,
        "netAmount": 498,
        "txHash": "0xefgh...ijkl",
        "safeheronTxId": "sh_txn_12345678",
        "createdAt": "2026-01-06T10:30:00Z",
        "completedAt": "2026-01-06T11:00:00Z"
      }
    ]
  }
}
```

---

### 5.6 管理白名单地址

#### 添加地址到白名单
```
POST /wallet/whitelist
```

**请求体**
```json
{
  "address": "0xnewaddress",
  "label": "我的钱包"
}
```

**响应示例**
```json
{
  "code": 200,
  "message": "address added to whitelist",
  "data": {
    "id": "addr_123",
    "address": "0xnewaddress",
    "label": "我的钱包",
    "verified": false,
    "verificationExpiresAt": "2026-01-07T10:30:00Z",
    "message": "Verification email sent. Address will be available after 24 hours."
  }
}
```

#### 获取白名单地址
```
GET /wallet/whitelist
```

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "id": "addr_123",
        "address": "0xnewaddress",
        "label": "我的钱包",
        "verified": true,
        "verifiedAt": "2026-01-07T10:30:00Z",
        "lastUsedAt": "2026-01-06T11:00:00Z",
        "createdAt": "2026-01-06T10:30:00Z"
      }
    ]
  }
}
```

#### 删除白名单地址
```
DELETE /wallet/whitelist/:addressId
```

---

## 6. 交易历史与审计

### 6.1 获取交易记录

**请求**
```
GET /transactions?type=all&page=1&limit=50
```

**参数**
| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| type | string | 否 | 类型：all/deposit/withdrawal/subscription/interest |
| startDate | string | 否 | 开始日期（ISO 8601） |
| endDate | string | 否 | 结束日期（ISO 8601） |
| page | integer | 否 | 分页页码 |

**响应示例**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 15,
    "items": [
      {
        "id": "txn_001",
        "type": "subscription",
        "description": "申购 - 90天稳定理财",
        "amount": 1000,
        "currency": "USDT",
        "status": "completed",
        "timestamp": "2026-01-06T10:30:00Z"
      },
      {
        "id": "txn_002",
        "type": "deposit",
        "description": "充币 - USDT",
        "amount": 5000,
        "currency": "USDT",
        "status": "completed",
        "txHash": "0xabcd...ef12",
        "timestamp": "2026-01-05T15:20:00Z"
      }
    ]
  }
}
```

---

## 7. 邮件通知 Webhook

### 7.1 邮件发送事件

系统会在以下场景触发邮件：

| 事件 | 时机 | 收件人 | 内容 |
|------|------|--------|------|
| **subscription_created** | 申购成功后 | 用户邮箱 | 申购确认函 |
| **auto_subscribe_success** | 自动申购成功 | 用户邮箱 | 自动申购成功通知 |
| **auto_subscribe_failed** | 自动申购失败 | 用户邮箱 | 失败原因和修复建议 |
| **maturity_reminder** | 到期前3天 | 用户邮箱 | 到期确认邮件 |
| **maturity_completed** | 到期当日或次日 | 用户邮箱 | 还本付息完成通知 |
| **deposit_confirmed** | 充币确认 | 用户邮箱 | 充币成功通知 |
| **withdraw_pending** | 提币待确认 | 用户邮箱 | 提币确认邮件（包含确认链接） |
| **withdraw_completed** | 提币完成 | 用户邮箱 | 提币完成通知 |

---

## 8. 错误代码

| 错误代码 | HTTP 状态 | 说明 | 解决方案 |
|---------|---------|------|---------|
| SUCCESS | 200 | 请求成功 | - |
| INVALID_REQUEST | 400 | 请求参数无效 | 检查请求体参数 |
| UNAUTHORIZED | 401 | 认证失败 | 检查 Token 是否有效 |
| FORBIDDEN | 403 | 无权限或地区限制 | 检查用户权限或地区限制 |
| NOT_FOUND | 404 | 资源不存在 | 检查资源 ID |
| INSUFFICIENT_BALANCE | 400 | 账户余额不足 | 充币后再尝试 |
| PRODUCT_OFFLINE | 400 | 产品已下线 | 选择其他产品 |
| REGION_LIMIT_EXCEEDED | 403 | 区域限制 | 增加申购金额或升级KYC |
| ADDRESS_NOT_WHITELISTED | 400 | 地址未白名单 | 添加地址到白名单 |
| SERVER_ERROR | 500 | 服务器错误 | 稍后重试或联系客服 |

---

**文档版本**：v1.0
**最后更新**：2026-01-06
