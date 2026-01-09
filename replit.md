# Monera Digital

## Overview
Monera Digital is a full-stack financial services application with a React frontend and Go backend API.

## Project Structure
- `/src` - React frontend (TypeScript, Vite, TailwindCSS)
- `/cmd/server` - Go backend server entry point
- `/internal` - Go backend internal packages (handlers, services, middleware, db, config)
- `/api` - API route definitions (TypeScript)
- `/docs` - Documentation

## Tech Stack
### Frontend
- React 18 with TypeScript
- Vite build tool
- TailwindCSS for styling
- Radix UI components
- React Router DOM
- React Query for data fetching
- i18next for internationalization

### Backend
- Go 1.24 with Gin framework
- PostgreSQL database
- JWT authentication
- 2FA support (TOTP)

## Development
- Frontend runs on port 5000 via `npm run dev`
- Backend builds to `./server` executable
- Database: PostgreSQL (use DATABASE_URL environment variable)

## Scripts
- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run test` - Run tests
- `go build -o server ./cmd/server/main.go` - Build Go backend

## Recent Changes
- 2026-01-09: Configured for Replit environment (Go 1.24, Vite on port 5000)
