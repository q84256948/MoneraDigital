// internal/migration/migrations/001_create_users_table.go
package migrations

import (
	"database/sql"
	"fmt"

	"monera-digital/internal/migration"
)

// CreateUsersTable migration
type CreateUsersTable struct{}

func (m *CreateUsersTable) Version() string {
	return "001"
}

func (m *CreateUsersTable) Description() string {
	return "Create users table"
}

func (m *CreateUsersTable) Up(db *sql.DB) error {
	query := `
	CREATE TABLE IF NOT EXISTS users (
		id SERIAL PRIMARY KEY,
		email VARCHAR(255) UNIQUE NOT NULL,
		password VARCHAR(255) NOT NULL,
		two_factor_secret VARCHAR(255),
		two_factor_enabled BOOLEAN DEFAULT FALSE,
		two_factor_backup_codes TEXT,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)
	`

	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to create users table: %w", err)
	}

	// Create index on email
	indexQuery := `CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)`
	_, err = db.Exec(indexQuery)
	if err != nil {
		return fmt.Errorf("failed to create email index: %w", err)
	}

	return nil
}

func (m *CreateUsersTable) Down(db *sql.DB) error {
	query := `DROP TABLE IF EXISTS users`
	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to drop users table: %w", err)
	}
	return nil
}

// Ensure CreateUsersTable implements Migration interface
var _ migration.Migration = (*CreateUsersTable)(nil)
