# 实现快速参考

## 📊 变更清单

| 文件 | 类型 | 修改说明 |
|------|------|--------|
| `src/components/DashboardSidebar.tsx` | 菜单项 | 删除Lending, 替代Investments为Fixed Deposit |
| `src/components/Hero.tsx` | CTA按钮 | 添加Fixed Deposit入口按钮+认证检查 |
| `src/pages/Login.tsx` | 重定向 | 支持returnTo参数自动跳转 |
| `src/i18n/locales/en.json` | 翻译 | 新增fixedDeposit键值（2处） |
| `src/i18n/locales/zh.json` | 翻译 | 新增定期理财键值（2处） |

**总行数变更**：+30 / -198（净-168行）

---

## 🎯 核心功能

### 1. Hero页面入口（已登录）
```
按钮点击 → handleFixedDepositClick() → navigate("/dashboard/lending")
```

### 2. Hero页面入口（未登录）
```
按钮点击 → handleFixedDepositClick() → navigate("/login", { state: { returnTo: "/dashboard/lending" } })
→ 登录 → 自动跳转到 /dashboard/lending
```

### 3. 侧边栏菜单项
```
仪表板菜单 → Fixed Deposit (TrendingUp图标) → /dashboard/lending
```

---

## 📍 菜单结构

**之前**：
```
Overview > Assets > Lending > Investments > Security > Statements
```

**之后**：
```
Overview > Assets > Fixed Deposit > Security > Statements
```

---

## 🌐 翻译键值

### 英文
```json
{
  "dashboard.nav.fixedDeposit": "Fixed Deposit",
  "hero.buttons.fixedDeposit": "Earn Fixed Returns"
}
```

### 中文
```json
{
  "dashboard.nav.fixedDeposit": "定期理财",
  "hero.buttons.fixedDeposit": "赚取固定收益"
}
```

---

## ✅ 验证步骤

### 测试场景1：未登录用户
```
1. 打开 http://localhost:3000
2. 点击 Hero 区域的 "Earn Fixed Returns" 按钮
3. 应跳转到 /login 页面
4. 登录成功
5. 应自动跳转到 /dashboard/lending
```

### 测试场景2：已登录用户
```
1. 已登录的用户访问首页
2. 点击 "Earn Fixed Returns" 按钮
3. 应直接跳转到 /dashboard/lending
```

### 测试场景3：侧边栏菜单
```
1. 打开任何 /dashboard 子页面
2. 点击侧边栏的 "Fixed Deposit" 菜单项
3. 应导航到 /dashboard/lending
4. 菜单项应高亮显示为活跃状态
```

---

## 🔍 代码定位

### handleFixedDepositClick 函数
**文件**：`src/components/Hero.tsx:16-22`
```typescript
const handleFixedDepositClick = () => {
  if (isLoggedIn) {
    navigate("/dashboard/lending");
  } else {
    navigate("/login", { state: { returnTo: "/dashboard/lending" } });
  }
};
```

### returnTo 处理
**文件**：`src/pages/Login.tsx:48, 74`
```typescript
const returnTo = (location.state as any)?.returnTo || "/dashboard";
navigate(returnTo);
```

### 菜单项配置
**文件**：`src/components/DashboardSidebar.tsx:21-27`
```typescript
const menuItems = [
  { icon: LayoutDashboard, label: t("dashboard.nav.overview"), href: "/dashboard" },
  { icon: Wallet, label: t("dashboard.nav.assets"), href: "/dashboard/assets" },
  { icon: TrendingUp, label: t("dashboard.nav.fixedDeposit"), href: "/dashboard/lending" },
  { icon: ShieldCheck, label: t("dashboard.nav.security"), href: "/dashboard/security" },
  { icon: FileText, label: t("dashboard.nav.statements"), href: "/dashboard/statements" },
];
```

---

## 📋 检查清单

- [x] DashboardSidebar.tsx - 菜单项更新
- [x] Hero.tsx - 按钮和认证逻辑
- [x] Login.tsx - returnTo重定向支持
- [x] en.json - 英文翻译
- [x] zh.json - 中文翻译
- [ ] npm run dev - 本地测试（待执行）
- [ ] 三个场景测试（待执行）
- [ ] git push - 推送到远程（待执行）
- [ ] Vercel部署（待执行）

---

## 💡 可能的问题和解决方案

| 问题 | 原因 | 解决方案 |
|------|------|--------|
| 按钮文本显示英文而非中文 | i18n加载延迟 | 已提供fallback文本 |
| 登录后没有跳转到Fixed Deposit | location.state丢失 | 已设置默认值/dashboard |
| 侧边栏菜单项不高亮 | 路由匹配问题 | useLocation已正确配置 |

---

## 📞 部署前清单

```bash
# 1. 确认代码变更
git status

# 2. 构建验证
npm run build

# 3. 开发服务器测试
npm run dev

# 4. 执行三个测试场景

# 5. 提交代码
git add .
git commit -m "feat: implement fixed deposit entry points - plan A approach"

# 6. 推送到远程
git push origin main

# 7. 确认Vercel部署
```

---

## 🎯 成功标志

✅ 当以下条件都满足时，实现完成：

1. 未登录用户可从首页进入Fixed Deposit（经过登录）
2. 已登录用户可从首页直接进入Fixed Deposit
3. 用户可从侧边栏菜单进入Fixed Deposit
4. 菜单项正确显示英文和中文
5. 所有导航都指向正确的/dashboard/lending路由
6. 代码构建成功无errors
7. Vercel部署成功
