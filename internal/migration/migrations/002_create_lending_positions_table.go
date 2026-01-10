// internal/migration/migrations/002_create_lending_positions_table.go
package migrations

import (
	"database/sql"
	"fmt"

	"monera-digital/internal/migration"
)

// CreateLendingPositionsTable migration
type CreateLendingPositionsTable struct{}

func (m *CreateLendingPositionsTable) Version() string {
	return "002"
}

func (m *CreateLendingPositionsTable) Description() string {
	return "Create lending positions table"
}

func (m *CreateLendingPositionsTable) Up(db *sql.DB) error {
	query := `
	CREATE TABLE IF NOT EXISTS lending_positions (
		id SERIAL PRIMARY KEY,
		user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		asset VARCHAR(50) NOT NULL,
		amount DECIMAL(20, 8) NOT NULL,
		duration_days INTEGER NOT NULL,
		apy DECIMAL(5, 2) NOT NULL,
		status VARCHAR(50) DEFAULT 'active',
		accrued_yield DECIMAL(20, 8) DEFAULT 0,
		start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		end_date TIMESTAMP,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)
	`

	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to create lending_positions table: %w", err)
	}

	// Create indexes
	indexes := []string{
		`CREATE INDEX IF NOT EXISTS idx_lending_positions_user_id ON lending_positions(user_id)`,
		`CREATE INDEX IF NOT EXISTS idx_lending_positions_status ON lending_positions(status)`,
		`CREATE INDEX IF NOT EXISTS idx_lending_positions_asset ON lending_positions(asset)`,
	}

	for _, indexQuery := range indexes {
		_, err := db.Exec(indexQuery)
		if err != nil {
			return fmt.Errorf("failed to create index: %w", err)
		}
	}

	return nil
}

func (m *CreateLendingPositionsTable) Down(db *sql.DB) error {
	query := `DROP TABLE IF EXISTS lending_positions`
	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to drop lending_positions table: %w", err)
	}
	return nil
}

// Ensure CreateLendingPositionsTable implements Migration interface
var _ migration.Migration = (*CreateLendingPositionsTable)(nil)
