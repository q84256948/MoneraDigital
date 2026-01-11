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
	// 1. Load DATABASE_URL from .env
	dbURL := getDatabaseURL()
	if dbURL == "" {
		log.Fatal("DATABASE_URL not found in .env or environment variables")
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
	fmt.Println("Successfully connected to database.")

	// 2. Read SQL file
	sqlFilePath := "docs/静态理财/需求文档MD/数据库建表脚本.sql"
	fmt.Printf("Reading SQL file: %s\n", sqlFilePath)

	content, err := os.ReadFile(sqlFilePath)
	if err != nil {
		// Try absolute path or check current dir
		cwd, _ := os.Getwd()
		log.Fatalf("Error reading SQL file at %s/%s: %v", cwd, sqlFilePath, err)
	}

	sqlScript := string(content)

	// 3. Execute SQL
	// Postgres driver (lib/pq) supports multiple statements in one Exec
	fmt.Println("Executing SQL script...")

	// We wrap it in a transaction
	tx, err := db.Begin()
	if err != nil {
		log.Fatalf("Error starting transaction: %v", err)
	}

	_, err = tx.Exec(sqlScript)
	if err != nil {
		tx.Rollback()
		log.Fatalf("Error executing SQL script: %v", err)
	}

	if err := tx.Commit(); err != nil {
		log.Fatalf("Error committing transaction: %v", err)
	}

	fmt.Println("Successfully executed database migration script!")
}

func getDatabaseURL() string {
	// First check env var
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}

	// Then check .env file
	content, err := os.ReadFile(".env")
	if err != nil {
		log.Printf("Could not read .env file: %v", err)
		return ""
	}

	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "DATABASE_URL=") {
			// Remove prefix and potential quotes
			val := strings.TrimPrefix(line, "DATABASE_URL=")
			val = strings.Trim(val, `"'`)
			return val
		}
	}

	return ""
}
