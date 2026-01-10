# Go 后端统一方案 - 实施计划与测试策略

## 4. 实施计划

### 4.1 阶段一：基础设施加固 (Day 1-2)

#### 任务 1.1: 数据库连接池优化
```go
// internal/db/db.go
type Config struct {
    MaxOpenConns    int           // 最大打开连接数
    MaxIdleConns    int           // 最大空闲连接数
    ConnMaxLifetime time.Duration // 连接最大生命周期
}

func InitDB(databaseURL string, cfg Config) (*sql.DB, error) {
    db, err := sql.Open("postgres", databaseURL)
    if err != nil {
        return nil, err
    }

    db.SetMaxOpenConns(cfg.MaxOpenConns)      // 默认 25
    db.SetMaxIdleConns(cfg.MaxIdleConns)      // 默认 5
    db.SetConnMaxLifetime(cfg.ConnMaxLifetime) // 默认 5分钟

    if err := db.Ping(); err != nil {
        return nil, err
    }

    return db, nil
}
```

**测试用例:**
- ✅ 连接池初始化成功
- ✅ 连接数限制生效
- ✅ 连接超时处理

#### 任务 1.2: CORS 安全配置
```go
// internal/middleware/cors.go
func NewCORS(allowedOrigins []string) gin.HandlerFunc {
    origins := make(map[string]bool)
    for _, o := range allowedOrigins {
        origins[o] = true
    }

    return func(c *gin.Context) {
        origin := c.GetHeader("Origin")
        if origins[origin] {
            c.Header("Access-Control-Allow-Origin", origin)
            c.Header("Access-Control-Allow-Credentials", "true")
            c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
            c.Header("Access-Control-Allow-Headers", "Content-Type,Authorization")
        }

        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(204)
            return
        }
    }
}
```

**测试用例:**
- ✅ 允许的源通过 CORS
- ✅ 不允许的源被拒绝
- ✅ OPTIONS 请求处理正确

### 4.2 阶段二：安全加固 (Day 3-4)

#### 任务 2.1: JWT Secret 管理
```go
// internal/config/config.go
func Load() (*Config, error) {
    jwtSecret := viper.GetString("JWT_SECRET")

    if viper.GetString("ENV") == "production" {
        if len(jwtSecret) < 32 {
            return nil, fmt.Errorf("JWT_SECRET must be at least 32 chars in production")
        }
    }

    return &Config{
        JWTSecret: jwtSecret,
    }, nil
}
```

**测试用例:**
- ✅ 生产环境强制 32 字节最小长度
- ✅ 开发环境允许短密钥
- ✅ 缺失密钥返回错误

#### 任务 2.2: 统一错误处理
```go
// internal/errors/errors.go
type AppError struct {
    Code    int    `json:"code"`
    Message string `json:"message"`
}

var (
    ErrInvalidCredentials = &AppError{Code: 401, Message: "Invalid email or password"}
    ErrUnauthorized       = &AppError{Code: 401, Message: "Unauthorized"}
    ErrNotFound           = &AppError{Code: 404, Message: "Resource not found"}
    ErrInvalidInput       = &AppError{Code: 400, Message: "Invalid input data"}
    ErrEmailExists        = &AppError{Code: 400, Message: "Email already exists"}
)
```

**测试用例:**
- ✅ 错误代码正确
- ✅ 错误消息清晰
- ✅ 错误序列化为 JSON

### 4.3 阶段三：核心服务实现 (Day 5-8)

#### 任务 3.1: Auth Service (已在上文详细说明)
**测试用例:**
- ✅ 注册成功
- ✅ 注册失败 - 邮箱已存在
- ✅ 注册失败 - 密码过短
- ✅ 登陆成功
- ✅ 登陆失败 - 邮箱不存在
- ✅ 登陆失败 - 密码错误
- ✅ 2FA 检查

#### 任务 3.2: Lending Service (已在上文详细说明)
**测试用例:**
- ✅ APY 计算正确
- ✅ 长期持有加成生效
- ✅ 申请借贷成功
- ✅ 申请借贷失败 - 期限无效
- ✅ 申请借贷失败 - 金额无效

#### 任务 3.3: Address Service (已在上文详细说明)
**测试用例:**
- ✅ ETH 地址验证
- ✅ BTC 地址验证
- ✅ USDT 地址验证
- ✅ 添加地址成功
- ✅ 添加地址失败 - 格式无效
- ✅ 验证地址成功
- ✅ 验证地址失败 - 不属于用户

#### 任务 3.4: Withdrawal Service (已在上文详细说明)
**测试用例:**
- ✅ 创建提现成功
- ✅ 创建提现失败 - 地址未验证
- ✅ 创建提现失败 - 地址不属于用户
- ✅ 创建提现失败 - 金额无效

### 4.4 阶段四: Handlers 层实现 (Day 9-10)

**测试用例:**
- ✅ 请求验证
- ✅ 响应格式
- ✅ 错误处理
- ✅ 状态码正确

### 4.5 阶段五: 删除 Vercel API (Day 11)

```bash
# 备份 Vercel API
cp -r api/ api.backup/

# 删除 Vercel API
rm -rf api/

# 更新 .vercelignore
echo "# Vercel API 已删除，仅保留前端" > .vercelignore
```

### 4.6 阶段六: 验证和测试 (Day 12)

- ✅ 运行完整测试套件
- ✅ 代码覆盖率检查
- ✅ 性能基准测试
- ✅ 安全审计

---

## 5. 测试策略

### 5.1 测试覆盖率要求

| 模块 | 覆盖率 | 测试用例数 |
|------|--------|-----------|
| services/auth | 100% | 8 |
| services/lending | 100% | 6 |
| services/address | 100% | 7 |
| services/withdrawal | 100% | 4 |
| handlers | 100% | 12 |
| middleware | 100% | 5 |
| errors | 100% | 3 |
| **总计** | **100%** | **45** |

### 5.2 测试示例

```go
// internal/services/auth_test.go
package services

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestAuthService_Register_Success(t *testing.T) {
    // 1. 准备
    db := setupTestDB()
    defer db.Close()

    service := NewAuthService(db, "test-secret")

    // 2. 执行
    user, err := service.Register("test@example.com", "password123")

    // 3. 验证
    assert.NoError(t, err)
    assert.NotNil(t, user)
    assert.Equal(t, "test@example.com", user.Email)
}

func TestAuthService_Register_EmailExists(t *testing.T) {
    db := setupTestDB()
    defer db.Close()

    service := NewAuthService(db, "test-secret")

    // 第一次注册成功
    _, err := service.Register("test@example.com", "password123")
    assert.NoError(t, err)

    // 第二次注册失败
    _, err = service.Register("test@example.com", "password456")
    assert.Error(t, err)
    assert.Equal(t, "email already exists", err.Error())
}

func TestAuthService_Login_Success(t *testing.T) {
    db := setupTestDB()
    defer db.Close()

    service := NewAuthService(db, "test-secret")

    // 注册用户
    _, err := service.Register("test@example.com", "password123")
    assert.NoError(t, err)

    // 登陆
    resp, err := service.Login("test@example.com", "password123")
    assert.NoError(t, err)
    assert.NotNil(t, resp.Token)
    assert.Equal(t, "test@example.com", resp.User.Email)
}

func TestAuthService_Login_InvalidPassword(t *testing.T) {
    db := setupTestDB()
    defer db.Close()

    service := NewAuthService(db, "test-secret")

    // 注册用户
    _, err := service.Register("test@example.com", "password123")
    assert.NoError(t, err)

    // 使用错误密码登陆
    _, err = service.Login("test@example.com", "wrongpassword")
    assert.Error(t, err)
    assert.Equal(t, "invalid email or password", err.Error())
}
```

### 5.3 集成测试

```go
// tests/integration_test.go
package tests

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestAuthFlow_RegisterAndLogin(t *testing.T) {
    // 1. 注册
    registerResp := POST("/api/auth/register", map[string]string{
        "email":    "test@example.com",
        "password": "password123",
    })
    assert.Equal(t, 201, registerResp.StatusCode)

    // 2. 登陆
    loginResp := POST("/api/auth/login", map[string]string{
        "email":    "test@example.com",
        "password": "password123",
    })
    assert.Equal(t, 200, loginResp.StatusCode)
    assert.NotEmpty(t, loginResp.Body["token"])

    // 3. 获取用户信息
    token := loginResp.Body["token"]
    meResp := GET("/api/auth/me", map[string]string{
        "Authorization": "Bearer " + token,
    })
    assert.Equal(t, 200, meResp.StatusCode)
    assert.Equal(t, "test@example.com", meResp.Body["email"])
}

func TestLendingFlow_ApplyAndGetPositions(t *testing.T) {
    // 1. 注册并登陆
    token := registerAndLogin()

    // 2. 申请借贷
    applyResp := POST("/api/lending/apply", map[string]interface{}{
        "asset":         "BTC",
        "amount":        "1.5",
        "duration_days": 180,
    }, token)
    assert.Equal(t, 201, applyResp.StatusCode)

    // 3. 获取借贷头寸
    positionsResp := GET("/api/lending/positions", token)
    assert.Equal(t, 200, positionsResp.StatusCode)
    assert.Greater(t, len(positionsResp.Body["positions"]), 0)
}
```

---

## 6. 代码统计

| 模块 | 代码行数 | 测试行数 | 总计 |
|------|---------|---------|------|
| db | 50 | 30 | 80 |
| errors | 40 | 20 | 60 |
| middleware | 80 | 50 | 130 |
| services | 400 | 300 | 700 |
| handlers | 200 | 150 | 350 |
| models | 100 | 50 | 150 |
| utils | 80 | 60 | 140 |
| **总计** | **950** | **660** | **1,610** |

---

## 7. 风险控制

### 7.1 零回归风险

- ✅ 每次提交前运行完整测试套件
- ✅ 代码覆盖率必须 ≥ 95%
- ✅ 所有测试必须通过

### 7.2 回滚方案

```bash
# 保留 Vercel API 备份 1 周
git tag -a backup-vercel-api -m "Backup before Go unification"
git push origin backup-vercel-api

# 如需回滚
git checkout backup-vercel-api
```

### 7.3 灰度发布

1. **第一阶段**: 内部测试 (Day 1-12)
2. **第二阶段**: Beta 用户测试 (Day 13-14)
3. **第三阶段**: 全量发布 (Day 15)

---

## 8. 预期收益

| 指标 | 当前 | 目标 | 改进 |
|------|------|------|------|
| 代码重复率 | 40% | 0% | ↓ 100% |
| 维护成本 | 2x | 1x | ↓ 50% |
| 测试覆盖率 | 60% | 100% | ↑ 67% |
| 部署目标 | 2 个 | 1 个 | ↓ 50% |
| 代码一致性 | 低 | 高 | ↑ 显著 |

---

## 9. 时间表

| 阶段 | 内容 | 时间 | 状态 |
|------|------|------|------|
| P0 | 基础设施加固 | Day 1-2 | 📋 计划中 |
| P1 | 安全加固 | Day 3-4 | 📋 计划中 |
| P2 | 核心服务实现 | Day 5-8 | 📋 计划中 |
| P3 | Handlers 实现 | Day 9-10 | 📋 计划中 |
| P4 | 删除 Vercel API | Day 11 | 📋 计划中 |
| P5 | 验证和测试 | Day 12 | 📋 计划中 |
| P6 | Beta 测试 | Day 13-14 | 📋 计划中 |
| P7 | 全量发布 | Day 15 | 📋 计划中 |
