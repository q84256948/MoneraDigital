# GEMINI.md

This file provides context and guidance for Gemini when working with the Monera Digital codebase.

## Project Overview

**Monera Digital** is an institutional-grade digital asset platform focused on static finance and lending solutions.
It is a **full-stack application** utilizing a TypeScript/Node.js ecosystem for both frontend and the primary backend (Serverless), with a legacy/parallel Go backend also present.

**Primary Stack:**
*   **Frontend:** React 18, TypeScript, Vite, Tailwind CSS, Shadcn/Radix UI.
*   **Backend (Active):** Vercel Serverless Functions (`api/` directory), Node.js.
*   **Backend (Legacy/Parallel):** Go (Gin framework) in `cmd/` and `internal/`. *Note: The frontend primarily interacts with the Vercel functions.*
*   **Database:** PostgreSQL (Neon) via Drizzle ORM.
*   **Caching/State:** Redis (Upstash) for rate limiting and session management.
*   **Testing:** Vitest (Unit/Integration), Playwright (E2E).

## Key Directory Structure

*   **`src/`**: Frontend source code and shared business logic.
    *   `src/components/`: React components (UI primitives in `ui/`, feature components elsewhere).
    *   `src/pages/`: Route components (Login, Register, Dashboard views).
    *   `src/lib/`: **Core Service Layer**. Contains business logic (auth, lending, withdrawals) reused by *both* the frontend and the `api/` serverless functions.
    *   `src/db/`: Drizzle ORM schema (`schema.ts`) and connection setup.
    *   `src/i18n/`: Internationalization (English/Chinese).
*   **`api/`**: Vercel Serverless Functions.
    *   Maps directly to API endpoints (e.g., `api/auth/login.ts` -> `/api/auth/login`).
    *   Handlers typically validate input (Zod) and delegate to `src/lib/` services.
*   **`docs/`**: Extensive project documentation (Architecture, PRDs, Security).
*   **`internal/` & `cmd/`**: Go backend code. Consult this only if specifically tasked with Go-related changes.

## Development Workflow

### Commands
*   **Start Dev Server:** `npm run dev` (Vite, defaults to port 8080).
*   **Build:** `npm run build` (Production build to `dist/`).
*   **Test:** `npm test` (Runs Vitest).
*   **Lint:** `npm run lint`.

### Architecture & Patterns

1.  **Service Layer Pattern (`src/lib/`)**:
    *   Business logic is centralized here, *not* in the API handlers or React components.
    *   Services are dependency-injected (accept `db`, `redis` instances).
    *   Example: `auth-service.ts` handles the actual login logic, used by `api/auth/login.ts`.

2.  **Authentication**:
    *   JWT-based. Tokens are stored in `localStorage` (known limitation/choice).
    *   Flow: Login -> JWT -> LocalStorage -> Attached to headers in API calls.
    *   Includes 2FA (TOTP) support.

3.  **Database (Drizzle)**:
    *   Schema defined in `src/db/schema.ts`.
    *   Uses PostgreSQL native enums for status fields.

4.  **UI/UX**:
    *   **Naming Convention:** "Lending" features are exposed to the user as **"Fixed Deposit"** (Sidebar, Hero buttons), though internal code variables often still use `lending`.
    *   **Theme:** Shadcn UI + Tailwind.

## Important Context (Recent Changes)

*   **Fixed Deposit vs. Lending:** As of Jan 2026, the UI term "Lending" has been renamed to "Fixed Deposit" to clarify the product offering. The internal routes (`/dashboard/lending`) and API paths (`api/lending`) remain unchanged.
*   **Legacy Go Backend:** The `internal/` directory contains a Go implementation that is not currently the primary backend for the frontend application. Assume Node.js/Vercel functions for backend tasks unless specified otherwise.
