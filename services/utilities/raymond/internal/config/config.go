package config

import (
	"fmt"
	"strings"
	"time"

	"github.com/go-playground/validator/v10"
	"github.com/spf13/viper"
)

// Load reads configuration from file and environment variables.
// Environment variables take precedence and use the format: SECTION_KEY (e.g., SERVER_PORT).
func Load(configPath string) (*Config, error) {
	v := viper.New()

	// Set defaults
	setDefaults(v)

	// Read from config file if provided
	if configPath != "" {
		v.SetConfigFile(configPath)
		if err := v.ReadInConfig(); err != nil {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
	}

	// Environment variables override config file
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	v.AutomaticEnv()

	// Unmarshal into struct
	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Validate configuration
	validate := validator.New()
	if err := validate.Struct(&cfg); err != nil {
		return nil, fmt.Errorf("config validation failed: %w", err)
	}

	return &cfg, nil
}

// setDefaults configures sensible defaults for the service.
func setDefaults(v *viper.Viper) {
	// Server defaults
	v.SetDefault("server.port", 8081)
	v.SetDefault("server.read_timeout", 10*time.Second)
	v.SetDefault("server.write_timeout", 10*time.Second)
	v.SetDefault("server.shutdown_timeout", 30*time.Second)
	v.SetDefault("server.enable_pprof", false)

	// Telemetry defaults
	v.SetDefault("telemetry.otlp_endpoint", "arc-widow:4317")
	v.SetDefault("telemetry.otlp_insecure", true)
	v.SetDefault("telemetry.service_name", "arc-raymond-bootstrap")
	v.SetDefault("telemetry.log_level", "info")

	// Bootstrap defaults
	v.SetDefault("bootstrap.timeout", 5*time.Minute)
	v.SetDefault("bootstrap.retry_attempts", 5)
	v.SetDefault("bootstrap.retry_backoff", 2*time.Second)

	// NATS defaults
	v.SetDefault("bootstrap.nats.url", "nats://arc-flash:4222")

	// Pulsar defaults
	v.SetDefault("bootstrap.pulsar.admin_url", "http://arc-strange:8080")
	v.SetDefault("bootstrap.pulsar.service_url", "pulsar://arc-strange:6650")
	v.SetDefault("bootstrap.pulsar.tenant", "arc")

	// Postgres defaults
	v.SetDefault("bootstrap.postgres.host", "arc-oracle")
	v.SetDefault("bootstrap.postgres.port", 5432)
	v.SetDefault("bootstrap.postgres.user", "arc")
	v.SetDefault("bootstrap.postgres.database", "arc_db")
	v.SetDefault("bootstrap.postgres.ssl_mode", "disable")
	v.SetDefault("bootstrap.postgres.max_conns", 25)
	v.SetDefault("bootstrap.postgres.min_conns", 2)

	// Redis defaults
	v.SetDefault("bootstrap.redis.host", "arc-sonic")
	v.SetDefault("bootstrap.redis.port", 6379)
	v.SetDefault("bootstrap.redis.db", 0)
}
