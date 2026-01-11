# AGENTS.md

> Context and instructions for AI coding agents working on Monera Digital.

## Project Overview

**Monera Digital** is an institutional-grade digital asset platform offering secure, transparent static finance and lending solutions. It is a full-stack application.

## Tech Stack

- **Frontend**: React 18, TypeScript, Vite, Tailwind CSS, Shadcn UI (Radix Primitives)
- **Backend**: Vercel Serverless Functions (`api/` directory), Node.js environment
- **Database**: PostgreSQL (Neon), Drizzle ORM
- **State/Cache**: Redis (Upstash)
- **Testing**: Vitest (Unit/Integration), Playwright (E2E)
- **Language**: TypeScript (Primary), Go (Legacy/Parallel backend in `internal/`)

## Developer Environment Tips

- **Package Manager**: Use `npm`.
- **Setup**:
    - Copy `.env.example` to `.env`.
    - `npm install` to install dependencies.
- **Development Server**:
    - `npm run dev`: Starts the Vite development server (default port 8080).
- **Building**:
    - `npm run build`: Production build to `dist/`.

## Testing Instructions

- **Unit/Integration Tests**:
    - `npm test`: Runs Vitest.
    - `npm run test -- <file>`: Run specific test file.
- **E2E Tests**:
    - `npm run test:e2e` (Check `package.json` if script exists, otherwise check `playwright.config.ts`).
- **Linting**:
    - `npm run lint`: Run ESLint.

## Directory Structure & Architecture

- **`src/lib/`**: **Core Service Layer**. Business logic lives here. Reused by both frontend and API.
- **`api/`**: Vercel Serverless Functions. Each file is an endpoint.
- **`src/components/ui/`**: Reusable UI components (Shadcn/Radix).
- **`src/db/`**: Drizzle schema definitions.

## Conventions

- **Naming**:
    - "Lending" features are displayed as **"Fixed Deposit"** in the UI (Sidebar, Hero), but internal code still uses `lending` naming.
- **State Management**:
    - `React Query` for server state.
    - `useState` for local UI state.
    - `localStorage` for JWT tokens (no cookies currently).
- **Styling**:
    - Tailwind CSS for styling.
    - `cn()` utility for class merging.

## Key Files

- `GEMINI.md`: Comprehensive AI context (read this for deep dive).
- `CLAUDE.md`: Similar context file.
- `src/db/schema.ts`: Database schema.
- `vite.config.ts`: Build configuration.

---

## Go Code Conventions (Backend in `internal/`)

> Target: Readable, maintainable, consistent Go code. Go 1.20+, Gin framework.

### 1. Project Structure

```
cmd/server/         # Entry point
internal/           # Business logic
  ├── handlers/     # HTTP handlers
  ├── services/     # Business logic
  ├── models/       # Data models
  └── middleware/   # HTTP middleware
```

- All business code in `internal/`
- `cmd` only for dependency assembly and startup

### 2. Naming

- **Package**: lowercase, no underscore, no plural
  ```go
  package user    // ✅
  package users   // ❌
  package user_service  // ❌
  ```
- **Variables/Functions**: camelCase, short but readable
  ```go
  userID, ctx, httpReq  // ✅
  ```
- **Exported identifiers**: MUST have doc comments

### 3. Files & Code Style

- Filename: lowercase + underscore
  `user_service.go`, `auth_handler.go`
- Single file ≤ **300 lines**
- One function = one responsibility

### 4. Error Handling

- **Errors MUST be handled**
- No `panic` for business errors
- Use error wrapping:
  ```go
  return fmt.Errorf("create user failed: %w", err)
  ```

### 5. Context规范

- **All I/O/DB/RPC MUST pass `context.Context`**
- `context` is ALWAYS the first parameter
- Don't store in struct, don't abuse `context.Background()`

### 6. Logging

- Use structured logging ( zap or zerolog )
- **Log only at boundary layer** (handler / job)
- Don't log in底层 libraries

### 7. Interface & Struct

- **Small interfaces**
- Define interface at the consumer side
- Struct only cares about its own responsibilities

### 8. Concurrency

- Goroutine MUST be cancellable
- Prefer `errgroup` when possible
- Never leak goroutines

### 9. Testing

- Test file: `*_test.go`
- Prefer table-driven tests
- Don't depend on real external services

### 10. Required Tools (Mandatory)

```bash
gofmt -w .
go vet ./...
```

Recommended: `golangci-lint`

### 11. Prohibited (Must Follow)

- ❌ No `init()` in business code
- ❌ No global variables for business state
- ❌ No "utils" catch-all packages

---

## Quick Reference

| Category | Rule |
|----------|------|
| Package name | lowercase, no plural |
| File size | ≤ 300 lines |
| Error handling | Never ignore errors |
| Context | First param, for I/O only |
| Logging | Handler layer only |
| Interface | Small, defined at consumer |
