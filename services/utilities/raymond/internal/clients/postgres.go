package clients

import (
	"context"
	"fmt"
	"time"

	"github.com/arc-framework/platform-spike/services/raymond/internal/config"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sony/gobreaker"
)

// PostgresClient wraps pgx connection pool with circuit breaker.
type PostgresClient struct {
	pool *pgxpool.Pool
	cb   *gobreaker.CircuitBreaker
}

// NewPostgresClient creates a new Postgres client with connection pool.
func NewPostgresClient(ctx context.Context, cfg config.PostgresConfig) (*PostgresClient, error) {
	connString := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Database, cfg.SSLMode,
	)

	poolCfg, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("parse postgres config: %w", err)
	}

	poolCfg.MaxConns = int32(cfg.MaxConns)
	poolCfg.MinConns = int32(cfg.MinConns)
	poolCfg.MaxConnLifetime = 1 * time.Hour
	poolCfg.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("create postgres pool: %w", err)
	}

	// Test connection
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}

	cb := gobreaker.NewCircuitBreaker(gobreaker.Settings{
		Name:        "postgres",
		MaxRequests: 3,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
	})

	return &PostgresClient{
		pool: pool,
		cb:   cb,
	}, nil
}

// ValidateSchema checks if a schema exists in the database.
func (c *PostgresClient) ValidateSchema(ctx context.Context, schema string) error {
	_, err := c.cb.Execute(func() (interface{}, error) {
		var exists bool
		query := "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = $1)"
		err := c.pool.QueryRow(ctx, query, schema).Scan(&exists)
		if err != nil {
			return nil, fmt.Errorf("query schema: %w", err)
		}
		if !exists {
			return nil, fmt.Errorf("schema %s does not exist", schema)
		}
		return nil, nil
	})
	return err
}

// Ping checks database connectivity.
func (c *PostgresClient) Ping(ctx context.Context) error {
	return c.pool.Ping(ctx)
}

// Close closes the connection pool.
func (c *PostgresClient) Close() {
	if c.pool != nil {
		c.pool.Close()
	}
}
