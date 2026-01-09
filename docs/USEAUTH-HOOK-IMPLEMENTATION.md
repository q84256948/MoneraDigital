# 实现指南：useAuth Hook 提取 (High Risk #1)

**优先级：** P0 - CRITICAL
**状态：** 待实现
**预计工时：** 5-6小时
**关键文件：** src/hooks/useAuth.ts, Hero.tsx, DashboardLayout.tsx, Login.tsx

---

## 问题背景

当前应用在至少8个不同的位置重复实现认证检查逻辑，违反了DRY（Don't Repeat Yourself）原则和SOLID中的单一职责原则。

### 当前代码重复模式

```typescript
// ❌ Hero.tsx
const isLoggedIn = !!localStorage.getItem("token");

// ❌ DashboardLayout.tsx
if (!localStorage.getItem("token")) {
  navigate("/login");
}

// ❌ Lending.tsx
const token = localStorage.getItem("token");
const user = JSON.parse(localStorage.getItem("user") || "{}");

// ❌ Assets.tsx
const [isAuthenticated, setIsAuthenticated] = useState(false);
useEffect(() => {
  const token = localStorage.getItem("token");
  setIsAuthenticated(!!token);
}, []);

// ... 更多重复的代码
```

### 问题

1. **代码重复** - 相同逻辑在多个地方实现
2. **维护困难** - 修改认证逻辑需要改多个文件
3. **不一致性** - 不同组件的认证检查时机不同
4. **缺乏集中管理** - 无单一真实来源（SSOT）
5. **测试困难** - 每个组件都需要单独测试认证逻辑

---

## 解决方案设计

### 目标架构

```
useAuth Hook
    ├─ 管理token状态
    ├─ 管理user状态
    ├─ 管理loading状态
    ├─ 提供login方法
    ├─ 提供logout方法
    └─ 提供isAuthenticated计算属性

应用组件
    ├─ Hero.tsx ← useAuth()
    ├─ Login.tsx ← useAuth()
    ├─ DashboardLayout.tsx ← useAuth()
    └─ 其他组件 ← useAuth()
```

---

## 实现步骤

### 第1步：创建useAuth Hook

**文件：** `src/hooks/useAuth.ts`

```typescript
import { useState, useEffect, useCallback, useContext, createContext } from "react";

/**
 * Authentication data structure
 */
export interface AuthUser {
  id: number;
  email: string;
  name?: string;
  twoFactorEnabled?: boolean;
  [key: string]: any;
}

/**
 * useAuth Hook
 *
 * Provides centralized authentication state and methods.
 * Eliminates code duplication across components.
 *
 * Usage:
 * const { user, token, isAuthenticated, isLoading, logout } = useAuth();
 *
 * if (isLoading) return <LoadingSpinner />;
 * if (!isAuthenticated) return <Navigate to="/login" />;
 *
 * return <Dashboard user={user} />;
 */
export const useAuth = () => {
  const [token, setToken] = useState<string | null>(null);
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Initialize auth state from localStorage on mount
  useEffect(() => {
    const initializeAuth = () => {
      try {
        const storedToken = localStorage.getItem("token");
        const storedUser = localStorage.getItem("user");

        if (storedToken && storedUser) {
          // Validate token format
          if (!isValidTokenFormat(storedToken)) {
            throw new Error("Invalid token format");
          }

          // Validate user data
          const parsedUser = JSON.parse(storedUser);
          if (!isValidUserObject(parsedUser)) {
            throw new Error("Invalid user data");
          }

          setToken(storedToken);
          setUser(parsedUser);
        }

        setError(null);
      } catch (err) {
        // Clear invalid auth data
        localStorage.removeItem("token");
        localStorage.removeItem("user");
        setToken(null);
        setUser(null);
        setError(err instanceof Error ? err.message : "Authentication failed");
      } finally {
        setIsLoading(false);
      }
    };

    initializeAuth();
  }, []);

  /**
   * Login user with credentials
   * Called after successful password login (before 2FA if enabled)
   */
  const loginWithCredentials = useCallback(
    (
      newToken: string,
      newUser: AuthUser,
      options?: { validateToken?: boolean }
    ) => {
      try {
        // Validate inputs
        if (!newToken || typeof newToken !== "string") {
          throw new Error("Invalid token");
        }

        if (!newUser || typeof newUser !== "object") {
          throw new Error("Invalid user data");
        }

        // Store in localStorage
        localStorage.setItem("token", newToken);
        localStorage.setItem("user", JSON.stringify(newUser));

        // Update state
        setToken(newToken);
        setUser(newUser);
        setError(null);

        return true;
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : "Login failed";
        setError(errorMessage);
        return false;
      }
    },
    []
  );

  /**
   * Logout user
   * Clears all authentication state
   */
  const logout = useCallback(() => {
    try {
      // Clear localStorage
      localStorage.removeItem("token");
      localStorage.removeItem("user");

      // Clear state
      setToken(null);
      setUser(null);
      setError(null);

      return true;
    } catch (err) {
      console.error("Logout failed:", err);
      return false;
    }
  }, []);

  /**
   * Update user profile
   * Useful when user settings change
   */
  const updateUser = useCallback((updates: Partial<AuthUser>) => {
    setUser((prevUser) => {
      if (!prevUser) return null;

      const updatedUser = { ...prevUser, ...updates };
      localStorage.setItem("user", JSON.stringify(updatedUser));
      return updatedUser;
    });
  }, []);

  /**
   * Check if current token is likely valid
   * Note: This is a client-side check only
   * Server validation should happen on protected endpoints
   */
  const isTokenValid = useCallback(() => {
    if (!token) return false;

    // Check token format
    if (!isValidTokenFormat(token)) return false;

    // Could add JWT expiration check here:
    // const decoded = jwtDecode(token);
    // return decoded.exp * 1000 > Date.now();

    return true;
  }, [token]);

  // Computed properties
  const isAuthenticated = !!token && !!user && isTokenValid();

  return {
    // State
    token,
    user,
    isAuthenticated,
    isLoading,
    error,

    // Methods
    loginWithCredentials,
    logout,
    updateUser,
    isTokenValid,
  };
};

/**
 * Helper: Validate token format (basic JWT format check)
 */
function isValidTokenFormat(token: string): boolean {
  // JWT format: header.payload.signature
  const parts = token.split(".");
  return parts.length === 3;
}

/**
 * Helper: Validate user object structure
 */
function isValidUserObject(user: any): boolean {
  return (
    user &&
    typeof user === "object" &&
    typeof user.id === "number" &&
    typeof user.email === "string"
  );
}
```

### 第2步：创建AuthContext（可选的改进）

**文件：** `src/context/AuthContext.tsx`

```typescript
import { createContext, useContext, ReactNode, FC } from "react";
import { useAuth, AuthUser } from "@/hooks/useAuth";

interface AuthContextType {
  token: string | null;
  user: AuthUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  loginWithCredentials: (token: string, user: AuthUser) => boolean;
  logout: () => boolean;
  updateUser: (updates: Partial<AuthUser>) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

/**
 * AuthProvider Component
 * Wraps application to provide auth context
 *
 * Usage:
 * <AuthProvider>
 *   <App />
 * </AuthProvider>
 */
export const AuthProvider: FC<{ children: ReactNode }> = ({ children }) => {
  const auth = useAuth();

  return (
    <AuthContext.Provider value={auth as AuthContextType}>
      {children}
    </AuthContext.Provider>
  );
};

/**
 * useAuthContext Hook
 * Access auth from any component
 *
 * Usage:
 * const { user, isAuthenticated, logout } = useAuthContext();
 */
export const useAuthContext = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuthContext must be used within AuthProvider");
  }
  return context;
};
```

### 第3步：更新Hero.tsx

**修改前：**
```typescript
const isLoggedIn = !!localStorage.getItem("token");

const handleFixedDepositClick = () => {
  if (isLoggedIn) {
    navigate("/dashboard/lending");
  } else {
    navigate("/login", { state: { returnTo: "/dashboard/lending" } });
  }
};
```

**修改后：**
```typescript
import { useAuth } from "@/hooks/useAuth";

// ... in component

const { isAuthenticated, isLoading } = useAuth();
const navigate = useNavigate();

const handleFixedDepositClick = () => {
  if (isAuthenticated) {
    navigate("/dashboard/lending");
  } else {
    navigate("/login", { state: { returnTo: "/dashboard/lending" } });
  }
};

// Can also use isLoading if needed
if (isLoading) {
  return <HeroSkeleton />;
}

return (
  // ... JSX
);
```

### 第4步：更新Login.tsx

**修改后：**
```typescript
import { useAuth } from "@/hooks/useAuth";
import { validateRedirectPath } from "@/lib/redirect-validator";

export default function Login() {
  const { loginWithCredentials } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { t } = useTranslation();

  // ... existing state

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      if (requires2FA) {
        // Verify 2FA and get token
        const res = await fetch("/api/auth/2fa/verify-login", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ userId: tempUserId, token: twoFactorToken }),
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error);

        // Use useAuth hook instead of localStorage
        const success = loginWithCredentials(data.token, data.user);
        if (!success) throw new Error("Failed to save authentication");

        toast.success(t("auth.login.successMessage"));

        const returnTo = validateRedirectPath((location.state as any)?.returnTo);
        navigate(returnTo);
        return;
      }

      // Password Login
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error);

      if (data.requires2FA) {
        setRequires2FA(true);
        setTempUserId(data.userId);
        toast.info(t("dashboard.security.enterCode"));
        return;
      }

      // Use useAuth hook
      const success = loginWithCredentials(data.token, data.user);
      if (!success) throw new Error("Failed to save authentication");

      toast.success(t("auth.login.successMessage"));

      const returnTo = validateRedirectPath((location.state as any)?.returnTo);
      navigate(returnTo);
    } catch (error: any) {
      toast.error(error.message);
    } finally {
      setIsLoading(false);
    }
  };

  // ... rest of component
}
```

### 第5步：更新DashboardLayout.tsx

**移除重复的认证检查：**
```typescript
// ❌ DELETE THIS - 现在由ProtectedRoute和useAuth处理
useEffect(() => {
  if (!localStorage.getItem("token")) {
    navigate("/login");
  }
}, [navigate]);
```

**如果需要访问用户数据：**
```typescript
import { useAuth } from "@/hooks/useAuth";

export const DashboardLayout = () => {
  const { user, isLoading, logout } = useAuth();
  // ... use user data and logout method
};
```

### 第6步：创建单元测试

**文件：** `src/hooks/useAuth.test.ts`

```typescript
import { describe, it, expect, beforeEach, vi } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useAuth, AuthUser } from "./useAuth";

describe("useAuth", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  const mockUser: AuthUser = {
    id: 1,
    email: "test@example.com",
    name: "Test User",
  };

  const mockToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature";

  it("should initialize with no auth state", () => {
    const { result } = renderHook(() => useAuth());

    expect(result.current.token).toBeNull();
    expect(result.current.user).toBeNull();
    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.isLoading).toBe(false);
  });

  it("should load auth state from localStorage", () => {
    localStorage.setItem("token", mockToken);
    localStorage.setItem("user", JSON.stringify(mockUser));

    const { result } = renderHook(() => useAuth());

    expect(result.current.token).toBe(mockToken);
    expect(result.current.user).toEqual(mockUser);
    expect(result.current.isAuthenticated).toBe(true);
  });

  it("should login with credentials", () => {
    const { result } = renderHook(() => useAuth());

    act(() => {
      const success = result.current.loginWithCredentials(mockToken, mockUser);
      expect(success).toBe(true);
    });

    expect(result.current.token).toBe(mockToken);
    expect(result.current.user).toEqual(mockUser);
    expect(result.current.isAuthenticated).toBe(true);
    expect(localStorage.getItem("token")).toBe(mockToken);
  });

  it("should logout", () => {
    localStorage.setItem("token", mockToken);
    localStorage.setItem("user", JSON.stringify(mockUser));

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(true);

    act(() => {
      const success = result.current.logout();
      expect(success).toBe(true);
    });

    expect(result.current.token).toBeNull();
    expect(result.current.user).toBeNull();
    expect(result.current.isAuthenticated).toBe(false);
    expect(localStorage.getItem("token")).toBeNull();
  });

  it("should update user", () => {
    localStorage.setItem("token", mockToken);
    localStorage.setItem("user", JSON.stringify(mockUser));

    const { result } = renderHook(() => useAuth());

    act(() => {
      result.current.updateUser({ name: "Updated Name" });
    });

    expect(result.current.user?.name).toBe("Updated Name");
    expect(result.current.user?.id).toBe(1); // Other fields preserved
  });

  it("should handle invalid token format", () => {
    localStorage.setItem("token", "invalid-token");
    localStorage.setItem("user", JSON.stringify(mockUser));

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(false);
    expect(localStorage.getItem("token")).toBeNull();
  });

  it("should handle invalid user JSON", () => {
    localStorage.setItem("token", mockToken);
    localStorage.setItem("user", "invalid-json");

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(false);
    expect(localStorage.getItem("user")).toBeNull();
  });
});
```

---

## 验证清单

### 功能验证

- [ ] useAuth Hook正确初始化auth状态
- [ ] loginWithCredentials方法正确保存token和user
- [ ] logout方法正确清除所有auth数据
- [ ] updateUser方法正确更新用户信息
- [ ] isAuthenticated计算属性正确反映认证状态
- [ ] 无代码重复（所有组件使用同一个useAuth）

### 代码质量

- [ ] 所有TypeScript类型检查通过
- [ ] 单元测试100%通过
- [ ] 集成测试通过
- [ ] 构建无错误

### 兼容性

- [ ] Hero.tsx正确使用useAuth
- [ ] Login.tsx正确使用loginWithCredentials
- [ ] DashboardLayout.tsx移除冗余认证检查
- [ ] 所有dashboard页面可以访问useAuth

### 性能

- [ ] 无内存泄漏
- [ ] 无多余的render
- [ ] localStorage操作时间< 5ms

---

## 迁移路径

### 第一阶段：创建新Hook
1. 创建useAuth.ts
2. 创建useAuth.test.ts
3. 运行测试验证

### 第二阶段：迁移到新Hook
1. 更新Login.tsx使用loginWithCredentials
2. 更新Hero.tsx使用isAuthenticated
3. 更新DashboardLayout.tsx移除重复代码
4. 更新其他dashboard页面

### 第三阶段：清理
1. 删除所有重复的localStorage调用
2. 删除重复的useEffect认证检查
3. 删除重复的isLoading状态

### 第四阶段：优化（可选）
1. 创建AuthContext（全应用状态）
2. 创建AuthProvider
3. 迁移到useAuthContext

---

## 与其他修复的集成

### 与ProtectedRoute的交互

```
ProtectedRoute（检查是否登录）
    ↓
渲染受保护组件
    ↓
组件使用useAuth获取用户信息
    ↓
useAuth返回当前auth状态
```

### 与OpenRedirect修复的交互

```
Login.tsx接收returnTo参数
    ↓
validateRedirectPath验证路径
    ↓
loginWithCredentials更新auth状态
    ↓
navigate到验证后的路径
```

---

## 常见问题

### Q1: 是否需要AuthContext？

**简短答案：** 不必须，但推荐

- **不用Context：** 简单应用，在需要的组件中调用useAuth
- **用Context：** 需要全局auth状态，避免prop drilling

### Q2: 如何处理token刷新？

可以在useAuth中添加自动token刷新逻辑：

```typescript
useEffect(() => {
  if (!token) return;

  const interval = setInterval(async () => {
    const newToken = await refreshToken(token);
    if (newToken) {
      setToken(newToken);
      localStorage.setItem("token", newToken);
    }
  }, 5 * 60 * 1000); // 每5分钟刷新

  return () => clearInterval(interval);
}, [token]);
```

### Q3: 如何在非React代码中访问auth？

创建一个auth管理器：

```typescript
// src/lib/auth-manager.ts
export const authManager = {
  getToken: () => localStorage.getItem("token"),
  getUser: () => JSON.parse(localStorage.getItem("user") || "null"),
  isAuthenticated: () => !!localStorage.getItem("token"),
};
```

---

## 下一步

1. 创建useAuth Hook
2. 创建单元测试
3. 更新Login.tsx
4. 更新Hero.tsx
5. 更新DashboardLayout.tsx
6. 删除重复代码
7. 运行完整测试套件
8. 提交PR审查

---

## 预期收益

- ✅ **代码减少** - 删除至少200行重复代码
- ✅ **维护性提升** - 统一的认证逻辑管理
- ✅ **可测试性** - 易于单元测试认证逻辑
- ✅ **可扩展性** - 容易添加新的认证功能（如token刷新）
- ✅ **类型安全** - 类型化的auth状态和方法

