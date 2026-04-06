package postgres

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	dbNameFile           = "/etc/secrets/db/dbname"
	dbPortFile           = "/etc/secrets/db/port"
	dbUsernameFile       = "/etc/secrets/db/username"
	dbPasswordFile       = "/etc/secrets/db/password"
	dbConnStringTemplate = "postgres://%s:%s@%s:%s/%s?sslmode=disable"
)

func CreateDatabasePool(dbHost string) (*pgxpool.Pool, error) {
	dbName, err := os.ReadFile(dbNameFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read dbname file: %w", err)
	}

	dbPort, err := os.ReadFile(dbPortFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read dbport file: %w", err)
	}

	username, err := os.ReadFile(dbUsernameFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read username file: %w", err)
	}

	password, err := os.ReadFile(dbPasswordFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read password file: %w", err)
	}

	dbPool, err := pgxpool.New(context.Background(), fmt.Sprintf(dbConnStringTemplate, 
		strings.TrimSpace(string(username)), 
		strings.TrimSpace(string(password)), 
		dbHost, 
		strings.TrimSpace(string(dbPort)), 
		strings.TrimSpace(string(dbName)),
	))
	if err != nil {
		return nil, fmt.Errorf("failed to create database pool: %w", err)
	}

	err = dbPool.Ping(context.Background())
	if err != nil {
		dbPool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return dbPool, nil
}
