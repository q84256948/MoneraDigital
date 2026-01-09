# 前后端集成完整指南

## 🎯 系统状态

✅ **所有配置检查通过**
- 环境变量: 正确配置
- 文件结构: 完整
- Vite代理: 正确配置
- 后端配置: 正确配置
- 前端代码: 正确实现
- 后端代码: 正确实现

---

## 🚀 快速开始

### 本地开发环境

#### 1. 启动开发服务器
```bash
npm run dev
```

这个命令会：
- 启动后端服务器 (端口 8081)
- 启动前端Vite服务器 (端口 8080)
- 配置API代理 (/api → localhost:8081)

#### 2. 打开浏览器
```
http://localhost:8080
```

#### 3. 测试注册功能
1. 点击"注册"链接
2. 输入邮箱: `test@example.com`
3. 输入密码: `TestPassword123!`
4. 点击"注册"按钮
5. 应该看到成功提示，然后自动跳转到登陆页面

#### 4. 测试登陆功能
1. 输入刚才注册的邮箱
2. 输入刚才设置的密码
3. 点击"登陆"按钮
4. 应该看到成功提示，然后跳转到仪表板

---

## 📊 系统架构

```
┌─────────────────────────────────────────────────────────┐
│ 浏览器 (http://localhost:8080)                          │
│ ┌───────────────────────────────────────────────────┐  │
│ │ Register.tsx / Login.tsx                          │  │
│ │ 发送: POST /api/auth/register                     │  │
│ │ 发送: POST /api/auth/login                        │  │
│ └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        ↓
            Vite 代理 (/api → :8081)
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 后端服务器 (http://localhost:8081)                      │
│ ┌───────────────────────────────────────────────────┐  │
│ │ api/auth/register.ts                              │  │
│ │ api/auth/login.ts                                 │  │
│ │ AuthService (业务逻辑)                            │  │
│ └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ PostgreSQL 数据库 (Neon)                                │
│ users 表: id, email, password, ...                      │
└─────────────────────────────────────────────────────────┘
```

---

## 🔄 完整的注册流程

```
用户输入邮箱和密码
        ↓
前端验证输入
        ↓
发送 POST /api/auth/register
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
        ↓
Vite代理转发到 http://localhost:8081/api/auth/register
        ↓
后端处理:
  1. 验证邮箱格式 (Zod schema)
  2. 验证密码长度 (最少6个字符)
  3. 哈希密码 (bcryptjs, 10轮)
  4. 插入数据库
  5. 返回 201 + 用户信息
        ↓
前端接收响应
        ↓
显示成功提示
        ↓
1秒后导航到登陆页面
```

---

## 🔄 完整的登陆流程

```
用户输入邮箱和密码
        ↓
前端验证输入
        ↓
发送 POST /api/auth/login
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
        ↓
Vite代理转发到 http://localhost:8081/api/auth/login
        ↓
后端处理:
  1. 验证邮箱格式和密码长度
  2. 查询数据库获取用户
  3. 比较密码 (bcryptjs.compare)
  4. 检查2FA状态
  5. 生成JWT token (24小时过期)
  6. 返回 200 + token + 用户信息
        ↓
前端接收响应
        ↓
存储token到localStorage
存储用户信息到localStorage
        ↓
显示成功提示
        ↓
导航到 /dashboard
```

---

## 🧪 测试检查清单

### 注册测试
- [ ] 成功注册新用户
- [ ] 拒绝无效邮箱格式
- [ ] 拒绝短密码 (< 6字符)
- [ ] 拒绝重复邮箱
- [ ] 成功后导航到登陆页面

### 登陆测试
- [ ] 使用正确凭证成功登陆
- [ ] 拒绝错误密码
- [ ] 拒绝不存在的邮箱
- [ ] Token正确存储在localStorage
- [ ] 成功后导航到仪表板

### 数据验证
- [ ] 密码在数据库中被正确哈希
- [ ] 用户信息正确存储
- [ ] Token包含正确的用户ID和邮箱

### 错误处理
- [ ] 网络错误显示适当的错误消息
- [ ] 服务器错误显示适当的错误消息
- [ ] 验证错误显示具体的错误信息

---

## 🔍 调试技巧

### 1. 检查浏览器控制台
```javascript
// 查看存储的token
console.log(localStorage.getItem('token'));

// 查看存储的用户信息
console.log(JSON.parse(localStorage.getItem('user')));

// 解码JWT token (需要安装jwt-decode)
import { jwtDecode } from 'jwt-decode';
console.log(jwtDecode(localStorage.getItem('token')));
```

### 2. 检查网络请求
1. 打开DevTools → Network标签
2. 执行注册或登陆
3. 查看请求:
   - URL: 应该是 `/api/auth/register` 或 `/api/auth/login`
   - Method: POST
   - Status: 201 (注册) 或 200 (登陆)
   - Response: 应该包含 `user` 和 `token`

### 3. 检查后端日志
```bash
# 查看后端日志
tail -f backend.log

# 或查看输出
cat backend.out
```

### 4. 检查数据库
```bash
# 连接到数据库
psql $DATABASE_URL

# 查看用户表
SELECT id, email, created_at FROM users;

# 查看特定用户
SELECT * FROM users WHERE email = 'test@example.com';
```

---

## ⚠️ 常见问题

### 问题1: 注册返回404
**原因**: 后端未在8081端口运行
**解决**:
```bash
# 检查后端是否运行
lsof -i :8081

# 如果没有运行，重启开发服务器
npm run dev
```

### 问题2: 注册返回500错误
**原因**: 数据库连接失败
**解决**:
```bash
# 检查DATABASE_URL
echo $DATABASE_URL

# 测试数据库连接
psql $DATABASE_URL -c "SELECT 1"
```

### 问题3: 登陆后没有token
**原因**: JWT_SECRET未设置或无效
**解决**:
```bash
# 检查JWT_SECRET
echo $JWT_SECRET

# 确保长度至少32字节
```

### 问题4: CORS错误
**原因**: 代理配置不正确
**解决**:
```bash
# 检查vite.config.ts中的代理配置
grep -A 5 "proxy:" vite.config.ts

# 重启Vite开发服务器
npm run dev
```

### 问题5: 密码验证失败
**原因**: 密码哈希或比较出错
**解决**:
```bash
# 检查bcryptjs是否正确安装
npm list bcryptjs

# 重新安装依赖
npm install
```

---

## 📝 API参考

### 注册端点
```
POST /api/auth/register

请求体:
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}

成功响应 (201):
{
  "message": "User created successfully",
  "user": {
    "id": 1,
    "email": "user@example.com"
  }
}

错误响应 (400):
{
  "error": "Invalid email format" | "Password must be at least 6 characters" | "User already exists"
}
```

### 登陆端点
```
POST /api/auth/login

请求体:
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}

成功响应 (200):
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com"
  }
}

错误响应 (401):
{
  "error": "Invalid email or password"
}
```

### 获取当前用户
```
GET /api/auth/me

请求头:
Authorization: Bearer {token}

成功响应 (200):
{
  "id": 1,
  "email": "user@example.com",
  "twoFactorEnabled": false
}

错误响应 (401):
{
  "error": "Unauthorized"
}
```

---

## 🎓 学习资源

- **Vite代理文档**: https://vitejs.dev/config/server-options.html#server-proxy
- **React Router文档**: https://reactrouter.com/
- **JWT文档**: https://jwt.io/
- **bcryptjs文档**: https://github.com/dcodeIO/bcrypt.js
- **Drizzle ORM文档**: https://orm.drizzle.team/

---

## ✅ 验证清单

在部署到生产环境之前，请确保:

- [ ] 所有测试都通过
- [ ] 没有控制台错误
- [ ] 密码正确哈希
- [ ] Token正确生成和验证
- [ ] 数据库连接正常
- [ ] 环境变量已设置
- [ ] 速率限制生效
- [ ] 错误处理正确
- [ ] 安全头已配置
- [ ] CORS已正确配置
