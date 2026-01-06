# 静态理财 - Safeheron 集成指南

## 1. 概述

本文档说明如何将 Monera Digital 平台的充提币功能与 Safeheron 多签钱包集成，确保用户资金安全。

### Safeheron 简介
- **多签安全**：2/3 或 3/5 多签机制
- **冷钱包存储**：离线签名，隔离密钥管理
- **审计追踪**：完整的交易审计日志
- **API 集成**：RESTful API 便于系统集成

---

## 2. 集成架构

```
┌─────────────┐
│   用户端     │
│ (Web/App)   │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│   Monera 平台服务               │
│ - 用户账户管理                  │
│ - 订单处理                      │
│ - 邮件通知                      │
└──────┬──────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│   Safeheron API 网关                │
│ - 充币地址生成                     │
│ - 区块链监听                       │
│ - 提币多签审批                     │
│ - 交易签名和发送                   │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│   区块链网络                         │
│ - Ethereum                          │
│ - Polygon                           │
│ - BNB Chain                         │
│ - 其他公链                          │
└──────────────────────────────────────┘
```

---

## 3. 环境配置

### 3.1 生产环境 API 凭证

```bash
SAFEHERON_API_KEY=your_api_key_here
SAFEHERON_API_SECRET=your_api_secret_here
SAFEHERON_BASE_URL=https://api.safeheron.com/v1
SAFEHERON_SIGNATURE_KEY=your_signature_key_here
```

### 3.2 测试环境 API 凭证

```bash
SAFEHERON_SANDBOX_API_KEY=test_api_key
SAFEHERON_SANDBOX_API_SECRET=test_api_secret
SAFEHERON_SANDBOX_BASE_URL=https://sandbox-api.safeheron.com/v1
```

---

## 4. 认证机制

### 4.1 API 签名

所有 Safeheron API 请求都需要 HMAC-SHA256 签名。

**签名步骤**：
```
1. 准备请求数据（JSON 格式）
2. 按字段名称升序排序参数
3. 拼接字符串："key1=value1&key2=value2&..."
4. 使用 API Secret 计算 HMAC-SHA256
5. 将签名添加到请求头中
```

**Python 示例**：
```python
import hashlib
import hmac
import json
from urllib.parse import urlencode
from collections import OrderedDict

def sign_request(data, api_secret):
    # 按字母顺序排序参数
    sorted_data = OrderedDict(sorted(data.items()))

    # 构建签名字符串
    sign_str = urlencode(sorted_data)

    # 计算 HMAC-SHA256
    signature = hmac.new(
        api_secret.encode(),
        sign_str.encode(),
        hashlib.sha256
    ).hexdigest()

    return signature

# 使用示例
data = {
    "apiKey": "your_api_key",
    "bizContent": json.dumps({"amount": 1000}),
    "timestamp": 1609459200
}
signature = sign_request(data, "your_api_secret")
```

---

## 5. 充币集成

### 5.1 生成充币地址

**API 端点**：
```
POST https://api.safeheron.com/v1/wallet/create_deposit_address
```

**请求示例**：
```json
{
  "apiKey": "your_api_key",
  "timestamp": 1609459200,
  "bizContent": {
    "walletId": "wallet_001",
    "chainCode": "ETH",
    "tokenAddress": "0xdac17f958d2ee523a2206206994597c13d831ec7",
    "memo": ""
  },
  "sign": "signature_here"
}
```

**参数说明**：
| 参数 | 类型 | 说明 |
|------|------|------|
| walletId | string | Safeheron 钱包 ID |
| chainCode | string | 区块链标识：ETH/BSC/POLYGON 等 |
| tokenAddress | string | 代币合约地址（ERC20 代币必须） |
| memo | string | 备注（某些链需要） |

**响应示例**：
```json
{
  "success": true,
  "data": {
    "depositAddress": "0x1234567890abcdef1234567890abcdef12345678",
    "depositTag": "",
    "chainCode": "ETH",
    "tokenCode": "USDT"
  }
}
```

### 5.2 监听充币确认

**实现方案**：
1. 定期轮询 Safeheron API 查询交易状态
2. 或使用 Safeheron Webhook 实时通知

#### 轮询方案（每 30 秒查询一次）

**API 端点**：
```
POST https://api.safeheron.com/v1/wallet/get_deposit_status
```

**请求示例**：
```json
{
  "apiKey": "your_api_key",
  "timestamp": 1609459200,
  "bizContent": {
    "txHash": "0xabcd1234...",
    "chainCode": "ETH"
  },
  "sign": "signature_here"
}
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "txHash": "0xabcd1234...",
    "status": "confirmed",
    "confirmations": 12,
    "amount": 1000,
    "fee": 2,
    "netAmount": 998
  }
}
```

**Python 实现**：
```python
import time
import requests

def poll_deposit_status(tx_hash, chain_code, max_wait=300):
    """轮询充币状态，最多等待 5 分钟"""

    start_time = time.time()

    while time.time() - start_time < max_wait:
        # 准备请求数据
        biz_content = {
            "txHash": tx_hash,
            "chainCode": chain_code
        }

        data = {
            "apiKey": API_KEY,
            "timestamp": int(time.time()),
            "bizContent": json.dumps(biz_content)
        }

        # 签名
        data["sign"] = sign_request(data, API_SECRET)

        # 发送请求
        response = requests.post(
            f"{BASE_URL}/wallet/get_deposit_status",
            json=data,
            timeout=10
        )

        result = response.json()

        if result.get("success"):
            status = result["data"]["status"]

            if status == "confirmed":
                return result["data"]
            elif status == "failed":
                raise Exception("Deposit failed")

        # 等待 30 秒后重试
        time.sleep(30)

    raise TimeoutError("Deposit confirmation timeout")
```

### 5.3 充币流程图

```
用户点击"充币"
    │
    ▼
调用 Safeheron API 生成地址
    │
    ▼
显示充币地址和二维码
    │
    ▼
用户从交易所/钱包转账
    │
    ▼
系统轮询监听交易状态
    │
    ├─ 已确认 (≥6 个区块确认)
    │   │
    │   ▼
    │  更新数据库：充币记录状态 = "confirmed"
    │   │
    │   ▼
    │  更新用户余额（balance += amount）
    │   │
    │   ▼
    │  发送邮件通知用户
    │   │
    │   ▼
    │  充币完成
    │
    └─ 待确认 (< 6 个区块)
        │
        ▼
       继续轮询...
```

---

## 6. 提币集成

### 6.1 发起提币请求

**API 端点**：
```
POST https://api.safeheron.com/v1/wallet/create_withdraw_request
```

**请求示例**：
```json
{
  "apiKey": "your_api_key",
  "timestamp": 1609459200,
  "bizContent": {
    "walletId": "wallet_001",
    "chainCode": "ETH",
    "tokenAddress": "0xdac17f958d2ee523a2206206994597c13d831ec7",
    "toAddress": "0x9876543210fedcba9876543210fedcba98765432",
    "amount": "500",
    "memo": ""
  },
  "sign": "signature_here"
}
```

**参数说明**：
| 参数 | 类型 | 说明 |
|------|------|------|
| walletId | string | Safeheron 钱包 ID |
| chainCode | string | 区块链标识 |
| tokenAddress | string | 代币合约地址 |
| toAddress | string | 目标钱包地址 |
| amount | string | 提币金额（字符串，避免精度问题） |
| memo | string | 备注 |

**响应示例**：
```json
{
  "success": true,
  "data": {
    "requestId": "req_123456",
    "status": "pending_approval",
    "walletId": "wallet_001",
    "amount": "500",
    "fee": "2"
  }
}
```

### 6.2 查询提币请求状态

**API 端点**：
```
POST https://api.safeheron.com/v1/wallet/get_withdraw_request_status
```

**请求示例**：
```json
{
  "apiKey": "your_api_key",
  "timestamp": 1609459200,
  "bizContent": {
    "requestId": "req_123456"
  },
  "sign": "signature_here"
}
```

**响应状态**：
| 状态 | 说明 |
|------|------|
| pending_approval | 等待多签审批 |
| approved | 已批准 |
| signed | 已签名 |
| broadcasting | 广播中 |
| confirmed | 已确认 |
| failed | 失败 |
| rejected | 被拒绝 |

### 6.3 提币流程图

```
用户点击"提币"
    │
    ▼
验证：地址白名单、金额限制、账户余额
    │
    ▼
发送确认邮件（含确认链接）
    │
    ▼（用户点击邮件链接）
用户二次验证
    │
    ▼
发起 Safeheron 提币请求 (pending_approval)
    │
    ▼
记录提币订单：status = "pending_approval"
    │
    ▼
Safeheron 多签人审批
    │
├─ 批准
│   │
│   ▼
│  状态更新为 "approved"
│   │
│   ▼
│  Safeheron 签名交易
│   │
│   ▼
│  状态更新为 "signed"
│   │
│   ▼
│  Safeheron 广播交易到链上
│   │
│   ▼
│  状态更新为 "broadcasting"
│   │
│   ▼
│  监听区块链确认 (≥6 个区块)
│   │
│   ▼
│  状态更新为 "confirmed"
│   │
│   ▼
│  从用户余额扣除：balance -= (amount + fee)
│   │
│   ▼
│  发送提币完成邮件
│   │
│   ▼
│  提币完成
│
└─ 拒绝
    │
    ▼
   状态更新为 "rejected"
    │
    ▼
   发送拒绝通知邮件
    │
    ▼
   金额返还到用户账户
```

---

## 7. Webhook 集成（实时推送）

### 7.1 配置 Webhook

在 Safeheron 后台配置以下 Webhook 地址：

```
https://api.monera.digital/v1/webhooks/safeheron/deposit
https://api.monera.digital/v1/webhooks/safeheron/withdraw
```

### 7.2 处理 Webhook 推送

**充币完成 Webhook**：
```json
{
  "eventType": "deposit_confirmed",
  "data": {
    "txHash": "0xabcd1234...",
    "depositAddress": "0x1234567890abcdef1234567890abcdef12345678",
    "amount": "1000",
    "fee": "2",
    "chainCode": "ETH",
    "status": "confirmed",
    "confirmations": 12,
    "timestamp": 1609459200
  },
  "signature": "webhook_signature"
}
```

**提币完成 Webhook**：
```json
{
  "eventType": "withdraw_confirmed",
  "data": {
    "requestId": "req_123456",
    "txHash": "0xefgh5678...",
    "toAddress": "0x9876543210fedcba9876543210fedcba98765432",
    "amount": "500",
    "fee": "2",
    "status": "confirmed",
    "chainCode": "ETH",
    "timestamp": 1609459200
  },
  "signature": "webhook_signature"
}
```

**验证 Webhook 签名**（Python）：
```python
import hmac
import hashlib
import json

def verify_webhook_signature(webhook_data, signature, secret):
    """验证 Webhook 签名"""

    # 获取原始字符串（Safeheron 会指定格式）
    sign_str = json.dumps(webhook_data, separators=(',', ':'), sort_keys=True)

    # 计算签名
    expected_signature = hmac.new(
        secret.encode(),
        sign_str.encode(),
        hashlib.sha256
    ).hexdigest()

    # 比较签名
    return hmac.compare_digest(signature, expected_signature)

# 使用示例
webhook_data = {
    "eventType": "deposit_confirmed",
    "data": {...}
}
signature = "webhook_signature_from_request"

if verify_webhook_signature(webhook_data, signature, WEBHOOK_SECRET):
    print("✓ 签名验证通过，处理 Webhook")
else:
    print("❌ 签名验证失败，拒绝处理")
```

---

## 8. 错误处理

### 8.1 常见错误代码

| 错误代码 | 说明 | 解决方案 |
|---------|------|---------|
| INVALID_SIGNATURE | 签名错误 | 检查 API Key 和 Secret |
| INVALID_WALLET | 钱包不存在 | 确认 walletId 正确 |
| INSUFFICIENT_BALANCE | 钱包余额不足 | 检查 Safeheron 冷钱包余额 |
| INVALID_ADDRESS | 无效的目标地址 | 验证地址格式 |
| RATE_LIMITED | 请求过于频繁 | 实现指数退避重试 |
| NETWORK_ERROR | 网络错误 | 重试请求 |
| TIMEOUT | 请求超时 | 增加超时时间或重试 |

### 8.2 重试策略

```python
import time
from functools import wraps

def retry_with_backoff(max_retries=3, initial_delay=1):
    """指数退避重试装饰器"""

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            delay = initial_delay

            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_retries - 1:
                        raise  # 最后一次仍失败，抛出异常

                    print(f"❌ 请求失败，{delay} 秒后重试... ({attempt + 1}/{max_retries})")
                    time.sleep(delay)
                    delay *= 2  # 指数退避

        return wrapper
    return decorator

# 使用示例
@retry_with_backoff(max_retries=3)
def create_deposit_address():
    # API 请求代码
    pass
```

---

## 9. 安全最佳实践

### 9.1 密钥管理

```bash
# ❌ 不要在代码中硬编码密钥
API_KEY = "your_api_key"  # 错误

# ✓ 使用环境变量
import os
API_KEY = os.getenv("SAFEHERON_API_KEY")

# ✓ 使用密钥管理系统（AWS Secrets Manager、Vault 等）
from aws_secrets_manager import get_secret
API_KEY = get_secret("safeheron-api-key")
```

### 9.2 地址白名单

```
提币流程：
1. 用户只能提币到预先添加的白名单地址
2. 新增地址需要邮件验证
3. 新增地址添加后需 24 小时冷却期
4. 定期审计用户的地址变更
```

### 9.3 金额限制

```
根据用户风险等级设置提币限额：
- 新用户：单日 5,000 USDT
- 普通用户（KYC 认证）：单日 50,000 USDT
- VIP 用户：单日 500,000 USDT
```

### 9.4 日志和监控

```python
import logging

# 配置日志
logger = logging.getLogger(__name__)
handler = logging.handlers.RotatingFileHandler(
    'safeheron.log',
    maxBytes=10485760,  # 10MB
    backupCount=10
)

logger.addHandler(handler)

# 记录敏感操作
def log_withdrawal(user_id, amount, address, status):
    logger.info(f"Withdrawal: user={user_id}, amount={amount}, "
                f"address={address[-8:]}, status={status}")
```

---

## 10. 测试清单

- [ ] 在 Safeheron 测试环境创建测试钱包
- [ ] 测试充币地址生成
- [ ] 测试充币监听和确认
- [ ] 测试提币请求创建
- [ ] 测试提币状态查询
- [ ] 测试 Webhook 推送和签名验证
- [ ] 测试错误处理和重试机制
- [ ] 测试并发请求处理
- [ ] 执行安全测试（注入、XSS 等）
- [ ] 压力测试（日均 10万+ 用户）

---

## 11. 监控和告警

### 11.1 关键指标

| 指标 | 告警阈值 | 说明 |
|------|---------|------|
| 充币确认时间 | > 5 分钟 | 监听是否延迟 |
| 提币批准时间 | > 30 分钟 | 多签审批是否卡住 |
| API 请求失败率 | > 1% | Safeheron 服务可用性 |
| 交易异常 | 任何异常 | 立即告警 |

### 11.2 告警配置

```python
import alerting  # 假设使用的告警系统

def monitor_safeheron_health():
    """监控 Safeheron 服务健康状态"""

    # 检查 API 可用性
    try:
        response = requests.get(
            f"{BASE_URL}/health",
            timeout=5
        )
        if response.status_code != 200:
            alerting.send_alert(
                level="critical",
                title="Safeheron API 不可用",
                message=f"HTTP {response.status_code}"
            )
    except Exception as e:
        alerting.send_alert(
            level="critical",
            title="无法连接到 Safeheron API",
            message=str(e)
        )
```

---

## 12. 支持联系

- **Safeheron 文档**：https://docs.safeheron.com
- **API 支持**：api-support@safeheron.com
- **技术支持**：tech-support@safeheron.com

---

**文档版本**：v1.0
**最后更新**：2026-01-06
**维护人**：技术团队
