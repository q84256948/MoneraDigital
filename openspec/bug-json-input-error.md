# Bug Report: Unexpected end of JSON input during Login

**Priority**: High
**Status**: Open
**Date**: 2026-01-09

## 1. Issue Description

When attempting to login via the frontend, the console reports: `Failed to execute 'json' on 'Response': Unexpected end of JSON input`. This occurs because the `fetch` call to `/api/auth/login` returns a response with an empty body (Content-Length: 0) and likely a 404 status code in the current deployment environment.

## 2. Root Cause Analysis

The investigation identified three potential causes, leading to the confirmation of the "Wrong Backend" theory:

1.  **Frontend Request**: The React frontend (`src/pages/Login.tsx`) calls `fetch("/api/auth/login", ...)`.
2.  **Vite Configuration**: The `vite.config.ts` currently has no `server.proxy` configuration.
3.  **Routing Failure**:
    -   The frontend is served by Vite (port 8080 as configured).
    -   The **Go backend** (which implements the actual logic) runs on a separate process/port (typically 8080 too, which causes a conflict if running locally, or a different port).
    -   Because there is no proxy, the request to `/api/auth/login` is handled by the **Vite dev server** itself.
    -   Vite looks for a file matching that route or falls back to `index.html` (SPA fallback) or returns 404 if not found.
    -   The test script `test_backend.go` confirmed that `/api/auth/login` returns a **404 Not Found** with **Content-Length: 0**.
    -   `response.json()` on an empty body throws "Unexpected end of JSON input".

**Conclusion**: The frontend is not communicating with the Go backend. It is hitting the static server/Vite dev server which returns a 404 with no body.

## 3. Proposed Fix

Configure the Vite development server to proxy `/api` requests to the Go backend.

**Changes Required**:
1.  **Modify `vite.config.ts`**: Add a `server.proxy` rule to forward `/api` to the Go backend URL (e.g., `http://localhost:8081` - we need to ensure the Go server runs on a different port than Vite if running locally).
2.  **Update Go Server Port**: Ensure the Go server listens on a non-conflicting port (e.g., 8081) if Vite uses 8080.
3.  **Documentation**: Update README to instruct developers to run both servers.

## 4. Implementation Steps

1.  Change `cmd/server/main.go` or `.env` to set the Go server port to `8081` (to avoid conflict with Vite's default 8080).
2.  Update `vite.config.ts` to proxy `^/api` to `http://localhost:8081`.
3.  Verify by running both and attempting login.
