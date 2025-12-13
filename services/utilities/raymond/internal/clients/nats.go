package clients

import (
	"context"
	"fmt"
	"time"

	"github.com/arc-framework/platform-spike/services/raymond/internal/config"
	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"
	"github.com/sony/gobreaker"
)

// NATSClient wraps NATS JetStream client with circuit breaker.
type NATSClient struct {
	conn *nats.Conn
	js   jetstream.JetStream
	cb   *gobreaker.CircuitBreaker
}

// NewNATSClient creates a new NATS client with connection.
func NewNATSClient(ctx context.Context, cfg config.NATSConfig) (*NATSClient, error) {
	opts := []nats.Option{
		nats.Name("raymond-bootstrap"),
		nats.Timeout(10 * time.Second),
		nats.ReconnectWait(2 * time.Second),
		nats.MaxReconnects(5),
	}

	conn, err := nats.Connect(cfg.URL, opts...)
	if err != nil {
		return nil, fmt.Errorf("nats connect failed: %w", err)
	}

	js, err := jetstream.New(conn)
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("jetstream context failed: %w", err)
	}

	cb := gobreaker.NewCircuitBreaker(gobreaker.Settings{
		Name:        "nats-jetstream",
		MaxRequests: 3,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
	})

	return &NATSClient{
		conn: conn,
		js:   js,
		cb:   cb,
	}, nil
}

// CreateStream creates a JetStream stream with the given configuration.
func (c *NATSClient) CreateStream(ctx context.Context, cfg config.StreamConfig) error {
	_, err := c.cb.Execute(func() (interface{}, error) {
		retention := jetstream.LimitsPolicy
		switch cfg.Retention {
		case "interest":
			retention = jetstream.InterestPolicy
		case "workqueue":
			retention = jetstream.WorkQueuePolicy
		}

		replicas := cfg.Replicas
		if replicas == 0 {
			replicas = 1
		}

		streamCfg := jetstream.StreamConfig{
			Name:      cfg.Name,
			Subjects:  cfg.Subjects,
			Retention: retention,
			MaxAge:    cfg.MaxAge,
			Replicas:  replicas,
		}

		_, err := c.js.CreateStream(ctx, streamCfg)
		if err != nil {
			// If stream already exists, update it
			_, err = c.js.UpdateStream(ctx, streamCfg)
			if err != nil {
				return nil, fmt.Errorf("create/update stream: %w", err)
			}
		}
		return nil, nil
	})

	return err
}

// Close closes the NATS connection.
func (c *NATSClient) Close() {
	if c.conn != nil {
		c.conn.Close()
	}
}
