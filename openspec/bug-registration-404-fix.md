# Bug Report: Registration API 404 Error

**Priority**: High
**Status**: Fixed
**Date**: 2026-01-10

## 1. Issue Description

The registration functionality failed with the following errors:
- `POST /api/auth/register` returned 404 (Not Found)
- Console error: "Non-JSON response received"
- Error message: "Registration failed"

## 2. Root Cause Analysis

### Primary Issue: Static Deployment Configuration
The production deployment was configured as `static`, which only serves frontend files from the `dist` directory. The Go backend API was never started in production.

### Secondary Issues:
1. **AuthService Compilation Errors**: The `AuthService` struct was missing required fields (`jwtSecret`, `tokenBlacklist`) that were referenced in `auth_refresh.go`
2. **Constructor Mismatch**: `NewAuthService` was called with wrong number of arguments in different parts of the codebase
3. **Missing Redis Package**: The `github.com/redis/go-redis/v9` package was not in go.mod

## 3. Solution Applied

### 3.1 Fixed AuthService Structure
Updated `internal/services/auth.go` to include:
- Added `jwtSecret` and `tokenBlacklist` fields to `AuthService` struct
- Updated `NewAuthService` constructor to accept `jwtSecret` parameter
- Added `SetTokenBlacklist` method

### 3.2 Updated Deployment Configuration
Changed from `static` to `autoscale` deployment:
- Build command: `npm run build && go build -o server ./cmd/server/main.go`
- Run command: `PORT=5000 GIN_MODE=release ./server`

### 3.3 Go Backend Static File Serving
Updated `cmd/server/main.go` to serve static frontend files:
- Serves `/assets/*` from `dist/assets`
- Serves static files (favicon.ico, robots.txt, etc.)
- Falls back to `index.html` for SPA routing

### 3.4 Added Missing Dependencies
- Added `github.com/redis/go-redis/v9` package

## 4. Files Modified

- `internal/services/auth.go` - Added missing fields and methods
- `cmd/server/main.go` - Added static file serving, fixed NewAuthService call
- `internal/container/container.go` - Removed unused import
- `scripts/start.sh` - Development startup script
- `scripts/start-prod.sh` - Production startup script

## 5. Verification

After applying fixes:
1. Backend compiles successfully
2. Development workflow starts both frontend (port 5000) and backend (port 8081)
3. Vite proxies API requests to backend
4. Production deployment serves both API and static frontend
