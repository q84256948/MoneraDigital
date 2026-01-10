# OpenSpec: Monera Digital 后端统一到 Go 架构方案

## 执行摘要

将 Monera Digital 后端从**双后端并存**（Go + Vercel Serverless）统一到**单一 Go 后端**，实现：
- ✅ 单一架构，消除重复
- ✅ KISS 原则，高内聚低耦合
- ✅ 100% 测试覆盖率
- ✅ 零回归风险

---

## 1. 现状分析

### 1.1 双后端架构问题

```
前端 (Vercel)
    ↓
    ├→ Go 后端 (Replit:8081)
    │   ├ /api/auth/*
    │   ├ /api/lending/*
    │   ├ /api/addresses/*
    │   └ /api/withdrawals/*
    │
    └→ Vercel Serverless (api/)
        ├ /api/auth/register.ts
        ├ /api/auth/login.ts
        ├ /api/auth/me.ts
        └ ... (重复实现)

    ↓
PostgreSQL (Neon)
```

### 1.2 核心问题

| 问题 | 影响 | 优先级 |
|------|------|--------|
| **功能重复** | 两套实现，维护成本 x2 | P0 |
| **逻辑不一致** | 业务行为可能不同 | P0 |
| **配置分散** | 环境变量管理混乱 | P1 |
| **部署复杂** | 两个部署目标，容易出错 | P1 |
| **测试覆盖不足** | Vercel API 缺少测试 | P2 |

### 1.3 代码重复分析

```
Vercel API (api/):
  - auth/register.ts (39 行)
  - auth/login.ts (39 行)
  - auth/me.ts (20 行)
  - auth/2fa/* (多个文件)
  - lending/* (多个文件)
  - addresses/* (多个文件)
  - withdrawals/* (多个文件)
  ≈ 400+ 行重复代码

Go 后端 (internal/):
  - services/auth.go (150 行)
  - services/lending.go (100 行)
  - services/address.go (120 行)
  - services/withdrawal.go (100 行)
  - handlers/* (200 行)
  ≈ 670 行代码

总计：≈ 1070 行代码，其中 ≈ 400 行重复
```

---

## 2. 目标架构

### 2.1 统一后端架构

```
┌─────────────────────────────────────────────────┐
│ 前端 (Vercel)                                   │
│ https://www.moneradigital.com                   │
└────────────────┬────────────────────────────────┘
                 │
                 ↓ HTTP/REST
┌─────────────────────────────────────────────────┐
│ Go 后端 (Replit)                                │
│ https://monera-digital--gyc567.replit.app       │
│                                                 │
│ ┌─────────────────────────────────────────┐   │
│ │ HTTP 层 (handlers)                      │   │
│ │ - AuthHandler                           │   │
│ │ - LendingHandler                        │   │
│ │ - AddressHandler                        │   │
│ │ - WithdrawalHandler                     │   │
│ └─────────────────────────────────────────┘   │
│                 ↓                              │
│ ┌─────────────────────────────────────────┐   │
│ │ 服务层 (services)                       │   │
│ │ - AuthService                           │   │
│ │ - LendingService                        │   │
│ │ - AddressService                        │   │
│ │ - WithdrawalService                     │   │
│ └─────────────────────────────────────────┘   │
│                 ↓                              │
│ ┌─────────────────────────────────────────┐   │
│ │ 数据层 (db)                             │   │
│ │ - Connection Pool                       │   │
│ │ - Query Builders                        │   │
│ └─────────────────────────────────────────┘   │
│                 ↓                              │
│ ┌─────────────────────────────────────────┐   │
│ │ 模型层 (models)                         │   │
│ │ - User, LendingPosition, Address, etc   │   │
│ └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│ PostgreSQL (Neon)                               │
└─────────────────────────────────────────────────┘
```

### 2.2 分层设计原则

| 层 | 职责 | 依赖 | 测试 |
|----|------|------|------|
| **HTTP** | 请求/响应处理 | services | 100% |
| **Services** | 业务逻辑 | db, models | 100% |
| **DB** | 数据库操作 | models | 100% |
| **Models** | 数据定义 | 无 | 100% |

---

## 3. 详细设计

### 3.1 目录结构

```
cmd/
  server/
    main.go                    # 入口点

internal/
  config/
    config.go                  # 配置加载 (viper)
    config_test.go             # 配置测试

  db/
    db.go                      # 数据库连接池
    db_test.go                 # 连接池测试

  errors/
    errors.go                  # 统一错误定义
    errors_test.go             # 错误测试

  handlers/
    auth.go                    # 认证处理器
    auth_test.go               # 认证处理器测试
    lending.go                 # 借贷处理器
    lending_test.go            # 借贷处理器测试
    address.go                 # 地址处理器
    address_test.go            # 地址处理器测试
    withdrawal.go              # 提现处理器
    withdrawal_test.go         # 提现处理器测试
    response.go                # 统一响应格式
    response_test.go           # 响应格式测试

  middleware/
    cors.go                    # CORS 中间件
    cors_test.go               # CORS 测试
    auth.go                    # JWT 认证中间件
    auth_test.go               # JWT 认证测试
    logger.go                  # 日志中间件
    logger_test.go             # 日志测试

  models/
    models.go                  # 数据模型定义
    models_test.go             # 模型测试

  services/
    auth.go                    # 认证服务
    auth_test.go               # 认证服务测试
    lending.go                 # 借贷服务
    lending_test.go            # 借贷服务测试
    address.go                 # 地址服务
    address_test.go            # 地址服务测试
    withdrawal.go              # 提现服务
    withdrawal_test.go         # 提现服务测试

  utils/
    crypto.go                  # 加密工具
    crypto_test.go             # 加密工具测试
    jwt.go                     # JWT 工具
    jwt_test.go                # JWT 工具测试

tests/
  integration_test.go          # 集成测试
  e2e_test.go                  # 端到端测试

.env.example                   # 环境变量示例
go.mod                         # Go 模块定义
go.sum                         # Go 模块锁定
Makefile                       # 构建脚本
```

