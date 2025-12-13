package clients

import (
	"context"
	"fmt"
	"time"

	"github.com/apache/pulsar-client-go/pulsar"
	"github.com/arc-framework/platform-spike/services/raymond/internal/config"
	"github.com/sony/gobreaker"
)

// PulsarClient wraps Apache Pulsar admin and producer clients.
type PulsarClient struct {
	client pulsar.Client
	cb     *gobreaker.CircuitBreaker
}

// NewPulsarClient creates a new Pulsar client.
func NewPulsarClient(ctx context.Context, cfg config.PulsarConfig) (*PulsarClient, error) {
	serviceURL := cfg.ServiceURL
	if serviceURL == "" {
		serviceURL = "pulsar://arc-strange:6650"
	}

	client, err := pulsar.NewClient(pulsar.ClientOptions{
		URL:               serviceURL,
		OperationTimeout:  30 * time.Second,
		ConnectionTimeout: 10 * time.Second,
	})
	if err != nil {
		return nil, fmt.Errorf("pulsar client creation failed: %w", err)
	}

	cb := gobreaker.NewCircuitBreaker(gobreaker.Settings{
		Name:        "pulsar",
		MaxRequests: 3,
		Interval:    10 * time.Second,
		Timeout:     30 * time.Second,
	})

	return &PulsarClient{
		client: client,
		cb:     cb,
	}, nil
}

// CreateTopic creates a partitioned topic (admin operation requires HTTP API).
// For simplicity, we'll just verify connectivity here. Full admin operations
// would require using the Pulsar admin HTTP API.
func (c *PulsarClient) CreateTopic(ctx context.Context, topic string, partitions int) error {
	_, err := c.cb.Execute(func() (interface{}, error) {
		// Create a producer to verify the topic exists (Pulsar auto-creates topics)
		producer, err := c.client.CreateProducer(pulsar.ProducerOptions{
			Topic: topic,
		})
		if err != nil {
			return nil, fmt.Errorf("create producer for topic %s: %w", topic, err)
		}
		producer.Close()
		return nil, nil
	})
	return err
}

// Close closes the Pulsar client.
func (c *PulsarClient) Close() {
	if c.client != nil {
		c.client.Close()
	}
}
