# 前后端集成分析报告

## 📊 系统架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                    前端 (React + Vite)                       │
│                    Port: 8080                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Register.tsx / Login.tsx                             │  │
│  │ 发送请求到: /api/auth/register, /api/auth/login     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
                    Vite 代理配置
                    /api → http://localhost:8081
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  后端 (Vercel Functions)                     │
│                    Port: 8081                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ api/auth/register.ts                                 │  │
│  │ api/auth/login.ts                                    │  │
│  │ AuthService (业务逻辑)                               │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  PostgreSQL 数据库                           │
│                  (Neon)                                      │
└─────────────────────────────────────────────────────────────┘
```

## ✅ 已验证的正确配置

### 1. 前端代码 (Register.tsx)
- ✅ 正确的API端点: `/api/auth/register`
- ✅ 正确的HTTP方法: POST
- ✅ 正确的请求体: `{ email, password }`
- ✅ 正确的错误处理: 检查响应状态和JSON解析
- ✅ 正确的成功处理: 显示toast并导航到登陆页面

### 2. 前端代码 (Login.tsx)
- ✅ 正确的API端点: `/api/auth/login`
- ✅ 正确的HTTP方法: POST
- ✅ 正确的请求体: `{ email, password }`
- ✅ 正确的token存储: localStorage
- ✅ 正确的用户信息存储: localStorage
- ✅ 正确的重定向: 使用validateRedirectPath验证

### 3. 后端API端点 (api/auth/register.ts)
- ✅ 正确的HTTP方法检查: POST only
- ✅ 正确的速率限制: 5请求/60秒
- ✅ 正确的错误处理: Zod验证错误、业务逻辑错误
- ✅ 正确的响应格式: `{ message, user }`
- ✅ 正确的HTTP状态码: 201 (Created)

### 4. 后端API端点 (api/auth/login.ts)
- ✅ 正确的HTTP方法检查: POST only
- ✅ 正确的速率限制: 5请求/60秒
- ✅ 正确的错误处理: 用户不存在、密码错误
- ✅ 正确的响应格式: `{ token, user }`
- ✅ 正确的HTTP状态码: 200 (OK)

### 5. AuthService 业务逻辑
- ✅ 正确的邮箱验证: Zod schema
- ✅ 正确的密码验证: 最少6个字符
- ✅ 正确的密码哈希: bcryptjs (10轮)
- ✅ 正确的JWT生成: 24小时过期
- ✅ 正确的2FA支持: 检查twoFactorEnabled

### 6. Vite 代理配置
- ✅ 正确的代理目标: `http://localhost:8081`
- ✅ 正确的changeOrigin: true
- ✅ 正确的secure: false (用于本地开发)

## 🔍 可能的问题点

### 问题1: 后端未在正确的端口运行
**症状**: 前端请求返回404或连接拒绝
**原因**: 后端没有在8081端口启动
**解决方案**: 检查 `scripts/start-replit.sh` 中的PORT设置

### 问题2: 数据库连接失败
**症状**: 注册/登陆返回500错误
**原因**: DATABASE_URL环境变量未设置或无效
**解决方案**: 验证 `.env` 文件中的DATABASE_URL

### 问题3: JWT_SECRET未设置
**症状**: 登陆返回错误，token生成失败
**原因**: JWT_SECRET环境变量未设置
**解决方案**: 在 `.env` 中设置JWT_SECRET (最少32字节)

### 问题4: CORS问题
**症状**: 浏览器控制台显示CORS错误
**原因**: 后端未配置CORS头
**解决方案**: 检查后端是否设置了正确的CORS头

### 问题5: 前端代理未生效
**症状**: 请求直接发送到 `/api/...` 而不是代理到后端
**原因**: Vite代理配置未正确加载
**解决方案**: 重启Vite开发服务器

## 🧪 测试检查清单

### 本地开发环境测试
- [ ] 后端在8081端口运行
- [ ] 前端在8080端口运行
- [ ] 数据库连接正常
- [ ] 环境变量已设置 (DATABASE_URL, JWT_SECRET)
- [ ] 注册新用户成功
- [ ] 登陆已注册用户成功
- [ ] 登陆错误密码失败
- [ ] 登陆不存在用户失败
- [ ] Token正确存储在localStorage
- [ ] 登陆后可以访问受保护页面

### Replit部署环境测试
- [ ] 前端在 https://monera-digital--gyc567.replit.app 加载
- [ ] 后端API可访问
- [ ] 注册功能正常
- [ ] 登陆功能正常
- [ ] 速率限制生效

## 📝 集成流程

### 注册流程
```
1. 用户在Register.tsx输入邮箱和密码
2. 点击"注册"按钮
3. 前端发送POST /api/auth/register
4. Vite代理转发到 http://localhost:8081/api/auth/register
5. 后端处理请求:
   - 验证邮箱格式和密码长度
   - 哈希密码
   - 插入数据库
   - 返回201和用户信息
6. 前端显示成功toast
7. 1秒后导航到登陆页面
```

### 登陆流程
```
1. 用户在Login.tsx输入邮箱和密码
2. 点击"登陆"按钮
3. 前端发送POST /api/auth/login
4. Vite代理转发到 http://localhost:8081/api/auth/login
5. 后端处理请求:
   - 验证邮箱格式和密码长度
   - 查询数据库获取用户
   - 比较密码
   - 检查2FA状态
   - 生成JWT token
   - 返回200和token + 用户信息
6. 前端存储token和用户信息到localStorage
7. 前端导航到/dashboard
```

## 🔧 环境变量检查

**必需的环境变量**:
```
DATABASE_URL=postgresql://...  # PostgreSQL连接字符串
JWT_SECRET=...                 # 最少32字节的密钥
```

**可选的环境变量**:
```
UPSTASH_REDIS_REST_URL=...     # Redis连接 (用于速率限制)
UPSTASH_REDIS_REST_TOKEN=...   # Redis认证
```

## 📋 调试步骤

### 1. 检查后端是否运行
```bash
curl http://localhost:8081/api/auth/register -X POST \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### 2. 检查前端代理
打开浏览器DevTools → Network标签，查看请求是否被代理

### 3. 检查localStorage
```javascript
// 在浏览器控制台运行
console.log(localStorage.getItem('token'));
console.log(localStorage.getItem('user'));
```

### 4. 检查数据库
```bash
psql $DATABASE_URL -c "SELECT * FROM users;"
```

### 5. 查看后端日志
检查 `backend.log` 文件中的错误信息
