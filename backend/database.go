package main

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/lib/pq" // PostgreSQL driver — imported for side-effects (registers "postgres" driver)
)

// DB is the package-level connection pool, shared across all handlers.
// It is safe for concurrent use by multiple goroutines.
var DB *sql.DB

// DBConfig holds all parameters required to open a PostgreSQL connection.
type DBConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// DefaultDBConfig returns the local-development placeholder credentials.
// Replace the Password field (or set the BPSC_DB_PASSWORD env var) before
// connecting to a real database.
func DefaultDBConfig() DBConfig {
	return DBConfig{
		Host:     "localhost",
		Port:     5432,
		User:     "postgres",
		Password: "", // Set via BPSC_DB_PASSWORD env var
		DBName:   "bpsc_db",
		SSLMode:  "disable",
	}
}

// dsn converts a DBConfig into a lib/pq connection string.
func (c DBConfig) dsn() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode,
	)
}

// InitDB opens a connection pool to PostgreSQL and verifies the connection
// is alive via a ping.  On success it configures sane pool limits and assigns
// the global DB variable.  On failure it returns a non-nil error so the caller
// can decide whether to fatal-exit or degrade gracefully.
func InitDB(connStr string) error {
	log.Println("[DB] Initialising PostgreSQL connection pool...")

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return fmt.Errorf("sql.Open failed: %w", err)
	}

	// ── Connection-pool tuning ────────────────────────────────────────────────
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)
	db.SetConnMaxIdleTime(2 * time.Minute)

	// ── Connectivity check ────────────────────────────────────────────────────
	if err := db.Ping(); err != nil {
		_ = db.Close()
		return fmt.Errorf("database ping failed: %w", err)
	}

	// ── Table Initialization ──────────────────────────────────────────────────
	query := `
CREATE TABLE IF NOT EXISTS user_bookmarks (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    concept_tag VARCHAR(255),
    question_id VARCHAR(255) NOT NULL,
    question_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, question_id)
);`
	if _, err := db.Exec(query); err != nil {
		_ = db.Close()
		return fmt.Errorf("failed to initialize database tables: %w", err)
	}

	DB = db
	log.Println("[DB] ✅ Connected to PostgreSQL Database and tables verified")
	return nil
}

// CloseDB releases the connection pool.  Call this in a defer after InitDB
// succeeds (e.g. defer CloseDB() in main).
func CloseDB() {
	if DB != nil {
		if err := DB.Close(); err != nil {
			log.Printf("[DB] Warning: error closing database connection pool: %v", err)
		} else {
			log.Println("[DB] Connection pool closed.")
		}
	}
}
