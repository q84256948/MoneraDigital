# Monera Digital

Monera Digital is an institutional-grade digital asset platform offering secure, transparent, and high-yield static finance and lending solutions.

## Getting Started

### Prerequisites

- Node.js (v20.x or later)
- Go (v1.21 or later) - **Required for Backend**
- PostgreSQL (or connection string)

### Installation

1. Clone the repository
2. Install dependencies:
   ```sh
   npm install
   ```
3. Copy `.env.example` to `.env` and fill in the required environment variables.
   - Set `PORT=8081` for the Go backend.
   - Set `DATABASE_URL` for PostgreSQL.

### Development

You need to run **both** the frontend and the backend.

1. **Start the Go Backend** (Terminal 1):
   ```sh
   go run cmd/server/main.go
   ```
   *Server runs on http://localhost:8081*

2. **Start the Frontend** (Terminal 2):
   ```sh
   npm run dev
   ```
   *Frontend runs on http://localhost:8080*

   The frontend is configured to proxy `/api` requests to the backend at `http://localhost:8081`.

### Build

Build the project for production:
```sh
npm run build
```

### Testing

Run unit tests:
```sh
npm run test
```

## Features

- **Static Finance**: Fixed-term investment products with competitive yields.
- **Lending**: Secure lending positions with transparent collateral management.
- **Security**: Multi-factor authentication, address whitelisting, and institutional-grade encryption.
- **Multi-language Support**: English and Chinese support.

## Tech Stack

- **Frontend**: React, TypeScript, Vite, Tailwind CSS, Shadcn UI
- **Backend**: Go (Gin Framework), PostgreSQL
- **Database**: PostgreSQL (Drizzle ORM), Redis (Upstash)
- **Testing**: Vitest, Playwright

## License

All rights reserved.
