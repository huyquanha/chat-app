package postgres

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	dbUsernameFile       = "/etc/secrets/db/username"
	dbPasswordFile       = "/etc/secrets/db/password"
	dbConnStringTemplate = "postgres://%s:%s@%s:%d/%s?sslmode=disable"
)

func CreateDatabasePool(dbHost string, dbPort int, dbName string) (*pgxpool.Pool, error) {
	username, err := os.ReadFile(dbUsernameFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read username file: %w", err)
	}

	password, err := os.ReadFile(dbPasswordFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read password file: %w", err)
	}

	dbPool, err := pgxpool.New(context.Background(), fmt.Sprintf(dbConnStringTemplate, username, password, dbHost, dbPort, dbName))
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
