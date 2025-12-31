# OpenSpec: 修复 Bcrypt 导入导致的运行时错误

## 1. 问题描述
- **现象**: 注册接口返回 400，错误信息为 `bcrypt.hash is not a function`。
- **原因**: 在 ESM 模式下使用 `import * as bcrypt` 导致无法直接访问 `hash` 函数。

## 2. 解决方案
1.  **修改导入方式**: 在 `src/lib/auth-service.ts` 中恢复使用默认导入 `import bcrypt from 'bcryptjs'`。
2.  **保持路径扩展名**: 确保所有内部引用依然保持 `.js` 后缀，以满足 Vercel 的 ESM 运行要求。

## 3. 验证标准
- 注册接口能够成功调用 `bcrypt.hash` 并完成用户创建。
