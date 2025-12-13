package config

import "time"

// Config is the root configuration structure for the Raymond bootstrap service.
type Config struct {
	Server    ServerConfig    `mapstructure:"server" validate:"required"`
	Telemetry TelemetryConfig `mapstructure:"telemetry" validate:"required"`
	Bootstrap BootstrapConfig `mapstructure:"bootstrap" validate:"required"`
}

// ServerConfig contains HTTP server configuration.
type ServerConfig struct {
	Port            int           `mapstructure:"port" validate:"required,min=1024,max=65535"`
	ReadTimeout     time.Duration `mapstructure:"read_timeout" validate:"required"`
	WriteTimeout    time.Duration `mapstructure:"write_timeout" validate:"required"`
	ShutdownTimeout time.Duration `mapstructure:"shutdown_timeout" validate:"required"`
	EnablePprof     bool          `mapstructure:"enable_pprof"`
}

// TelemetryConfig contains observability configuration.
type TelemetryConfig struct {
	OTLPEndpoint string `mapstructure:"otlp_endpoint" validate:"required"`
	OTLPInsecure bool   `mapstructure:"otlp_insecure"`
	ServiceName  string `mapstructure:"service_name" validate:"required"`
	LogLevel     string `mapstructure:"log_level" validate:"required,oneof=debug info warn error"`
}

// BootstrapConfig contains platform initialization configuration.
type BootstrapConfig struct {
	Timeout       time.Duration      `mapstructure:"timeout" validate:"required"`
	RetryAttempts int                `mapstructure:"retry_attempts" validate:"required,min=1,max=10"`
	RetryBackoff  time.Duration      `mapstructure:"retry_backoff" validate:"required"`
	Dependencies  []DependencyConfig `mapstructure:"dependencies" validate:"required,dive"`
	NATS          NATSConfig         `mapstructure:"nats" validate:"required"`
	Pulsar        PulsarConfig       `mapstructure:"pulsar" validate:"required"`
	Postgres      PostgresConfig     `mapstructure:"postgres"`
	Redis         RedisConfig        `mapstructure:"redis"`
}

// DependencyConfig defines a service dependency to wait for.
type DependencyConfig struct {
	Name     string        `mapstructure:"name" validate:"required"`
	Type     string        `mapstructure:"type" validate:"required,oneof=tcp http grpc"`
	Address  string        `mapstructure:"address"`
	URL      string        `mapstructure:"url"`
	Critical bool          `mapstructure:"critical"`
	Timeout  time.Duration `mapstructure:"timeout"`
}

// NATSConfig contains NATS JetStream initialization configuration.
type NATSConfig struct {
	URL     string         `mapstructure:"url" validate:"required"`
	Streams []StreamConfig `mapstructure:"streams" validate:"dive"`
}

// StreamConfig defines a NATS JetStream stream to create.
type StreamConfig struct {
	Name      string        `mapstructure:"name" validate:"required"`
	Subjects  []string      `mapstructure:"subjects" validate:"required,min=1"`
	Retention string        `mapstructure:"retention" validate:"required,oneof=limits interest workqueue"`
	MaxAge    time.Duration `mapstructure:"max_age"`
	Replicas  int           `mapstructure:"replicas" validate:"min=1,max=5"`
}

// PulsarConfig contains Apache Pulsar initialization configuration.
type PulsarConfig struct {
	AdminURL   string        `mapstructure:"admin_url" validate:"required"`
	ServiceURL string        `mapstructure:"service_url"`
	Tenant     string        `mapstructure:"tenant" validate:"required"`
	Namespaces []string      `mapstructure:"namespaces" validate:"min=1"`
	Topics     []TopicConfig `mapstructure:"topics" validate:"dive"`
}

// TopicConfig defines a Pulsar topic to create.
type TopicConfig struct {
	Name       string `mapstructure:"name" validate:"required"`
	Partitions int    `mapstructure:"partitions" validate:"min=0"`
}

// PostgresConfig contains database configuration.
type PostgresConfig struct {
	Host     string `mapstructure:"host" validate:"required"`
	Port     int    `mapstructure:"port" validate:"required,min=1,max=65535"`
	User     string `mapstructure:"user" validate:"required"`
	Password string `mapstructure:"password" validate:"required"`
	Database string `mapstructure:"database" validate:"required"`
	SSLMode  string `mapstructure:"ssl_mode" validate:"required,oneof=disable require verify-ca verify-full"`
	MaxConns int    `mapstructure:"max_conns" validate:"min=1,max=100"`
	MinConns int    `mapstructure:"min_conns" validate:"min=0,max=10"`
}

// RedisConfig contains Redis configuration.
type RedisConfig struct {
	Host     string `mapstructure:"host" validate:"required"`
	Port     int    `mapstructure:"port" validate:"required,min=1,max=65535"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db" validate:"min=0,max=15"`
}
