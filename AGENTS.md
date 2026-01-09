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
