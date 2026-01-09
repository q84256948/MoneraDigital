package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"

	_ "github.com/lib/pq"
)

func main() {
	// 1. Load DATABASE_URL
	dbURL := getDatabaseURL()
	if dbURL == "" {
		log.Fatal("DATABASE_URL not found")
	}

	fmt.Println("Connecting to database...")
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Error connecting to database: %v", err)
	}

	// 2. Read SQL file
	sqlFilePath := "cmd/db_migration/create_users.sql"
	content, err := os.ReadFile(sqlFilePath)
	if err != nil {
		log.Fatalf("Error reading SQL file: %v", err)
	}
	sqlScript := string(content)

	// 3. Execute SQL
	fmt.Println("Executing users table migration...")
	_, err = db.Exec(sqlScript)
	if err != nil {
		log.Fatalf("Error executing SQL: %v", err)
	}

	fmt.Println("Successfully created users table!")
}

func getDatabaseURL() string {
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}
	content, err := os.ReadFile(".env")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(content), "\n") {
		if strings.HasPrefix(line, "DATABASE_URL=") {
			return strings.Trim(strings.TrimPrefix(strings.TrimSpace(line), "DATABASE_URL="), "'\"")
		}
	}
	return ""
}
