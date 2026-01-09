# 实现指南：Protected Routes 组件 (High Risk #2)

**优先级：** P0 - CRITICAL
**状态：** 实现中
**预计工时：** 3-4小时
**关键文件：** src/components/ProtectedRoute.tsx, src/App.tsx

---

## 问题背景

当前应用缺乏真正的路由保护机制。用户可以直接访问受保护的路由（如`/dashboard/lending`），系统会在组件挂载后进行认证检查，导致以下问题：

### 现有问题

1. **Flash of Content** - 用户会短暂看到仪表板内容，然后才被重定向
2. **性能浪费** - 未授权用户的API请求会到达服务器
3. **SEO问题** - Web爬虫可能索引受保护页面
4. **数据泄露风险** - 受保护数据在重定向前短暂暴露

### 示例：当前问题流程

```
未授权用户直接访问: /dashboard/lending
       ↓
React路由渲染Lending页面组件
       ↓
组件挂载 - useEffect检查认证
       ↓ (短暂显示Lending页面内容!) ⚠️ FLASH OF CONTENT
       ↓
检查失败，重定向到/login
```

---

## 解决方案设计

### 目标架构

```
应用入口 (App.tsx)
    ↓
<Routes>
    <Route path="/" element={<Home />} />
    <Route path="/login" element={<Login />} />

    <Route element={<ProtectedRoute>}>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/dashboard/lending" element={<Lending />} />
        ...
    </Route>
</Routes>
```

**改进的流程：**

```
未授权用户尝试访问: /dashboard/lending
       ↓
ProtectedRoute组件在渲染前检查认证 (没有flash!)
       ↓
认证失败，重定向到/login
       ↓
不会渲染任何受保护的内容
```

---

## 实现步骤

### 第1步：创建ProtectedRoute组件

**文件：** `src/components/ProtectedRoute.tsx`

```typescript
import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useEffect, useState } from "react";

/**
 * Protected Route Component
 *
 * Wraps React Router routes to enforce authentication
 * before rendering components. Prevents flash of content
 * and protects against unauthorized API access.
 *
 * Usage:
 * <Route element={<ProtectedRoute>}>
 *   <Route path="/dashboard" element={<Dashboard />} />
 *   <Route path="/dashboard/lending" element={<Lending />} />
 * </Route>
 */
export const ProtectedRoute: React.FC = () => {
  const [isChecking, setIsChecking] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const location = useLocation();

  useEffect(() => {
    // Check authentication immediately on mount
    const token = localStorage.getItem("token");
    const user = localStorage.getItem("user");

    if (token && user) {
      try {
        // Validate token format (basic check)
        // In production, consider validating token with backend
        JSON.parse(user); // Ensure user data is valid JSON
        setIsAuthenticated(true);
      } catch {
        // Invalid token or user data
        localStorage.removeItem("token");
        localStorage.removeItem("user");
        setIsAuthenticated(false);
      }
    }

    setIsChecking(false);
  }, []);

  // While checking auth, don't render anything
  // This prevents flash of content
  if (isChecking) {
    return null; // Or return a loading spinner if desired
  }

  // If not authenticated, redirect to login
  // Pass returnTo to enable post-login redirect
  if (!isAuthenticated) {
    return (
      <Navigate
        to="/login"
        state={{ returnTo: location.pathname }}
        replace
      />
    );
  }

  // User is authenticated, render the protected content
  return <Outlet />;
};
```

### 第2步：更新路由配置

**文件：** `src/App.tsx`

**修改前：**
```typescript
<Routes>
  <Route path="/" element={<Home />} />
  <Route path="/login" element={<Login />} />
  <Route path="/register" element={<Register />} />

  <Route path="/dashboard" element={<DashboardLayout />}>
    <Route index element={<DashboardOverview />} />
    <Route path="lending" element={<Lending />} />
    <Route path="assets" element={<Assets />} />
    // ... other routes
  </Route>
</Routes>
```

**修改后：**
```typescript
<Routes>
  <Route path="/" element={<Home />} />
  <Route path="/login" element={<Login />} />
  <Route path="/register" element={<Register />} />

  {/* Protected Routes */}
  <Route element={<ProtectedRoute>}>
    <Route path="/dashboard" element={<DashboardLayout />}>
      <Route index element={<DashboardOverview />} />
      <Route path="lending" element={<Lending />} />
      <Route path="assets" element={<Assets />} />
      <Route path="security" element={<Security />} />
      <Route path="addresses" element={<Addresses />} />
      <Route path="withdraw" element={<Withdraw />} />
      <Route path="statements" element={<Statements />} />
    </Route>
  </Route>
</Routes>
```

### 第3步：修改DashboardLayout

**文件：** `src/components/DashboardLayout.tsx`

**移除认证检查：** 删除以下代码（不再需要）

```typescript
// ❌ DELETE THIS - 现在由ProtectedRoute处理
useEffect(() => {
  if (!localStorage.getItem("token")) {
    navigate("/login");
  }
}, [navigate]);
```

因为认证检查已在ProtectedRoute中完成，无需重复。

### 第4步：测试Protected Routes

**新文件：** `src/components/ProtectedRoute.test.tsx`

```typescript
import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import { ProtectedRoute } from "./ProtectedRoute";

describe("ProtectedRoute", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("should render protected content when authenticated", async () => {
    localStorage.setItem("token", "fake-token");
    localStorage.setItem("user", JSON.stringify({ id: 1, email: "test@example.com" }));

    const MockProtectedComponent = () => <div>Protected Content</div>;

    render(
      <MemoryRouter initialEntries={["/dashboard"]}>
        <Routes>
          <Route element={<ProtectedRoute>}>
            <Route path="/dashboard" element={<MockProtectedComponent />} />
          </Route>
        </Routes>
      </MemoryRouter>
    );

    // Should show protected content
    expect(screen.getByText("Protected Content")).toBeInTheDocument();
  });

  it("should redirect to login when not authenticated", async () => {
    const MockLoginComponent = () => <div>Login Page</div>;
    const MockProtectedComponent = () => <div>Protected Content</div>;

    render(
      <MemoryRouter initialEntries={["/dashboard"]}>
        <Routes>
          <Route path="/login" element={<MockLoginComponent />} />
          <Route element={<ProtectedRoute>}>
            <Route path="/dashboard" element={<MockProtectedComponent />} />
          </Route>
        </Routes>
      </MemoryRouter>
    );

    // Should show login page, not protected content
    expect(screen.getByText("Login Page")).toBeInTheDocument();
    expect(screen.queryByText("Protected Content")).not.toBeInTheDocument();
  });

  it("should handle invalid user data gracefully", async () => {
    localStorage.setItem("token", "fake-token");
    localStorage.setItem("user", "invalid-json"); // Invalid JSON

    const MockLoginComponent = () => <div>Login Page</div>;
    const MockProtectedComponent = () => <div>Protected Content</div>;

    render(
      <MemoryRouter initialEntries={["/dashboard"]}>
        <Routes>
          <Route path="/login" element={<MockLoginComponent />} />
          <Route element={<ProtectedRoute>}>
            <Route path="/dashboard" element={<MockProtectedComponent />} />
          </Route>
        </Routes>
      </MemoryRouter>
    );

    // Should clear invalid data and redirect
    expect(localStorage.getItem("user")).toBeNull();
    expect(screen.getByText("Login Page")).toBeInTheDocument();
  });

  it("should preserve returnTo path for post-login redirect", async () => {
    const MockLoginComponent = () => {
      const location = useLocation();
      const returnTo = (location.state as any)?.returnTo || "/dashboard";
      return <div>returnTo: {returnTo}</div>;
    };

    render(
      <MemoryRouter initialEntries={["/dashboard/lending"]}>
        <Routes>
          <Route path="/login" element={<MockLoginComponent />} />
          <Route element={<ProtectedRoute>}>
            <Route path="/dashboard/lending" element={<div>Lending</div>} />
          </Route>
        </Routes>
      </MemoryRouter>
    );

    // Should pass /dashboard/lending as returnTo
    expect(screen.getByText("returnTo: /dashboard/lending")).toBeInTheDocument();
  });
});
```

---

## 验证清单

### 功能验证

- [ ] 未登录用户无法访问受保护路由
- [ ] 未登录用户直接访问/dashboard被重定向到/login
- [ ] 登录后自动重定向到之前尝试访问的页面（returnTo）
- [ ] 不再有"flash of content"（页面内容短暂闪现）
- [ ] 受保护路由不会发送API请求

### 代码质量

- [ ] ProtectedRoute组件编译无错误
- [ ] 所有路由配置正确
- [ ] TypeScript类型检查通过
- [ ] 单元测试100%通过
- [ ] 集成测试通过

### 性能

- [ ] 路由导航延迟 < 50ms
- [ ] 认证检查延迟 < 100ms
- [ ] 无内存泄漏

### 安全性

- [ ] 认证检查不能被绕过
- [ ] token过期时正确重定向
- [ ] 无TOCTOU（Time of Check, Time of Use）漏洞

---

## 常见问题

### Q1: 如何加载动画（可选的改进）

如果希望在认证检查时显示加载动画而不是空白页面：

```typescript
if (isChecking) {
  return (
    <div className="flex items-center justify-center min-h-screen">
      <Loader className="animate-spin" size={40} />
    </div>
  );
}
```

### Q2: 如何处理token过期

在ProtectedRoute中添加token有效性检查：

```typescript
const validateToken = async (token: string): Promise<boolean> => {
  try {
    const response = await fetch("/api/auth/verify", {
      headers: { Authorization: `Bearer ${token}` }
    });
    return response.ok;
  } catch {
    return false;
  }
};
```

### Q3: 如何支持权限检查

扩展ProtectedRoute以支持权限：

```typescript
interface ProtectedRouteProps {
  requiredRole?: "admin" | "user";
  requiredPermissions?: string[];
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  requiredRole,
  requiredPermissions
}) => {
  // ... 检查认证

  const user = JSON.parse(localStorage.getItem("user") || "{}");

  if (requiredRole && user.role !== requiredRole) {
    return <Navigate to="/unauthorized" replace />;
  }

  // ... 继续
};
```

---

## 与现有代码集成

### 兼容性检查

✅ **React Router v6** - 完全兼容（使用Outlet和Navigate）
✅ **Vite** - 无构建问题
✅ **TypeScript** - 完全类型安全
✅ **存在的认证逻辑** - 可以保留作为二级检查

### 迁移路径

1. 创建ProtectedRoute组件
2. 在App.tsx中添加新的Route结构（保持旧的暂时）
3. 逐步将受保护路由移到新结构
4. 删除DashboardLayout中的冗余认证检查
5. 移除旧的Route配置

---

## 性能影响分析

### 积极影响

- ✅ 减少浪费的API调用
- ✅ 减少不必要的组件渲染
- ✅ 更快的初始加载（不加载受保护内容）
- ✅ 更好的SEO（爬虫不索引受保护页面）

### 负面影响

- ⚠️ 认证检查从组件级别移到路由级别，轻微增加初始化延迟
- 预期影响：< 10ms

---

## 下一步

1. 实现ProtectedRoute组件
2. 更新App.tsx路由配置
3. 运行单元测试和集成测试
4. 本地测试所有三个用户流程
5. 提交PR审查

---

## 参考资源

- [React Router Protected Routes Pattern](https://reactrouter.com/en/main/start/tutorial#protecting-routes)
- [Authentication in React Router v6](https://stackoverflow.com/questions/69865481/how-do-i-protect-my-routes-in-react-router-v6)
- [Flash of Unstyled Content (FOUC)](https://en.wikipedia.org/wiki/Flash_of_unstyled_content)

