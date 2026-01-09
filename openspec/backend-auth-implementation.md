# Backend Auth Implementation Proposal

**Goal**: Implement robust user registration and login functionality in the Go backend (`cmd/server`), replacing the current placeholder handlers.

## 1. Context & Analysis

-   **Current State**: Handlers are mocks returning JSON messages.
-   **Database**: The `users` table schema is defined in `src/db/schema.ts` (PostgreSQL) but might not exist in the DB if only `account` tables were created.
    -   Schema: `id` (serial), `email` (text, unique), `password` (text), `two_factor_secret`, `two_factor_enabled`, `two_factor_backup_codes`, `created_at`.
-   **Dependencies**: `golang.org/x/crypto` (bcrypt) and `github.com/golang-jwt/jwt/v5` are available.

## 2. API Contract

### 2.1 Register (`POST /api/auth/register`)

-   **Request Body**:
    ```json
    { "email": "user@example.com", "password": "securePassword123" }
    ```
-   **Success Response (201 Created)**:
    ```json
    { "id": 1, "email": "user@example.com", "created_at": "..." }
    ```
-   **Error Responses**:
    -   `400 Bad Request`: Invalid input (e.g., weak password).
    -   `409 Conflict`: Email already exists.
    -   `500 Internal Server Error`: DB error.

### 2.2 Login (`POST /api/auth/login`)

-   **Request Body**:
    ```json
    { "email": "user@example.com", "password": "securePassword123" }
    ```
-   **Success Response (200 OK)**:
    ```json
    {
      "token": "jwt_token_string",
      "user": { "id": 1, "email": "...", "two_factor_enabled": false }
    }
    ```
-   **Error Responses**:
    -   `400 Bad Request`: Invalid input.
    -   `401 Unauthorized`: Invalid credentials.
    -   `500 Internal Server Error`: Server error.

## 3. Implementation Plan

### 3.1 Step 1: Database Migration (Users Table)
Ensure the `users` table exists. Create a migration script `cmd/db_migration/create_users.go` (or update existing) to create the table if missing, matching `src/db/schema.ts`.

### 3.2 Step 2: Utility Functions (`internal/utils`)
-   `HashPassword(password string) (string, error)`: Using `bcrypt.GenerateFromPassword`.
-   `CheckPassword(password, hash string) bool`: Using `bcrypt.CompareHashAndPassword`.
-   `GenerateJWT(userID int, secret string) (string, error)`: Using `jwt.NewWithClaims`.

### 3.3 Step 3: Service Layer (`internal/services/auth.go`)
-   **Register**:
    1.  Check if email exists.
    2.  Hash password.
    3.  Insert into `users`.
    4.  Return user model (sanitized).
-   **Login**:
    1.  Find user by email.
    2.  Check password.
    3.  Generate JWT.
    4.  Return token + user info.

### 3.4 Step 4: Handler Layer (`internal/handlers/handlers.go`)
-   Update `Register` and `Login` methods to bind JSON, call service, and write JSON response.

## 4. Verification
-   Run local tests (if DB accessible).
-   Deploy and run `test_backend.go`.
