package clients

import (
	"context"
	"fmt"
	"time"

	"github.com/arc-framework/platform-spike/services/raymond/internal/config"
	"github.com/redis/go-redis/v9"
	"github.com/sony/gobreaker"
)

// RedisClient wraps Redis client with circuit breaker.
type RedisClient struct {
	client *redis.Client
	cb     *gobreaker.CircuitBreaker
}

// NewRedisClient creates a new Redis client.
func NewRedisClient(ctx context.Context, cfg config.RedisConfig) (*RedisClient, error) {
	client := redis.NewClient(&redis.Options{
		Addr:         fmt.Sprintf("%s:%d", cfg.Host, cfg.Port),
		Password:     cfg.Password,
		DB:           cfg.DB,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
		PoolSize:     10,
		MinIdleConns: 2,
	})

	// Test connection
	if err := client.Ping(ctx).Err(); err != nil {
		client.Close()
		return nil, fmt.Errorf("redis ping failed: %w", err)
	}

	cb := gobreaker.NewCircuitBreaker(gobreaker.Settings{
		Name:        "redis",
		MaxRequests: 3,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
	})

	return &RedisClient{
		client: client,
		cb:     cb,
	}, nil
}

// Ping checks Redis connectivity.
func (c *RedisClient) Ping(ctx context.Context) error {
	_, err := c.cb.Execute(func() (interface{}, error) {
		return nil, c.client.Ping(ctx).Err()
	})
	return err
}

// Set sets a key-value pair with expiration.
func (c *RedisClient) Set(ctx context.Context, key string, value interface{}, expiration time.Duration) error {
	_, err := c.cb.Execute(func() (interface{}, error) {
		return nil, c.client.Set(ctx, key, value, expiration).Err()
	})
	return err
}

// Get retrieves a value by key.
func (c *RedisClient) Get(ctx context.Context, key string) (string, error) {
	val, err := c.cb.Execute(func() (interface{}, error) {
		return c.client.Get(ctx, key).Result()
	})
	if err != nil {
		return "", err
	}
	return val.(string), nil
}

// Close closes the Redis connection.
func (c *RedisClient) Close() error {
	if c.client != nil {
		return c.client.Close()
	}
	return nil
}
