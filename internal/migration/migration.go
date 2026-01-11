// internal/migration/migration.go
package migration

import (
	"database/sql"
	"time"
)

// Migration represents a database migration
type Migration interface {
	// Version returns the migration version (e.g., "001", "002")
	Version() string

	// Description returns a human-readable description
	Description() string

	// Up runs the migration
	Up(db *sql.DB) error

	// Down reverts the migration
	Down(db *sql.DB) error
}

// MigrationRecord represents a recorded migration in the database
type MigrationRecord struct {
	ID         int
	Version    string
	Name       string
	ExecutedAt time.Time
}

// MigrationStatus represents the status of a migration
type MigrationStatus struct {
	Version    string
	Name       string
	Status     string // "pending", "applied", "failed"
	ExecutedAt *time.Time
	Error      string
}
