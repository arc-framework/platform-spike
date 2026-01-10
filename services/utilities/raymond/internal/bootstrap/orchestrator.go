package bootstrap

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/arc-framework/platform-spike/services/raymond/internal/clients"
	"github.com/arc-framework/platform-spike/services/raymond/internal/config"
	"github.com/arc-framework/platform-spike/services/raymond/internal/health"
	"github.com/arc-framework/platform-spike/services/raymond/internal/telemetry"
	pkgerrors "github.com/arc-framework/platform-spike/services/raymond/pkg/errors"
	"github.com/cenkalti/backoff/v4"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	"golang.org/x/sync/errgroup"
)

// Orchestrator manages the platform bootstrap process.
type Orchestrator struct {
	cfg     *config.Config
	logger  *slog.Logger
	tracer  trace.Tracer
	metrics *telemetry.Metrics
	checker *health.Checker
}

// NewOrchestrator creates a new bootstrap orchestrator.
func NewOrchestrator(
	cfg *config.Config,
	logger *slog.Logger,
	tracer trace.Tracer,
	metrics *telemetry.Metrics,
) *Orchestrator {
	checker := health.NewChecker(cfg.Bootstrap.Dependencies, logger, 5*time.Second)
	return &Orchestrator{
		cfg:     cfg,
		logger:  logger,
		tracer:  tracer,
		metrics: metrics,
		checker: checker,
	}
}

// Run executes the complete bootstrap workflow asynchronously.
// The service will start even if dependencies are not ready.
// Dependencies are checked in the background with automatic retries.
func (o *Orchestrator) Run(ctx context.Context) error {
	ctx, span := o.tracer.Start(ctx, "bootstrap.run")
	defer span.End()

	startTime := time.Now()
	o.logger.Info("starting platform bootstrap (async mode)")

	// Start async dependency monitoring in background
	go o.monitorDependencies(ctx)

	// Phase 1: Quick dependency check (non-blocking)
	o.checkDependenciesAsync(ctx)

	// Phase 2: Initialize NATS JetStream (with retry, non-blocking)
	go o.initializeWithRetry(ctx, "initialize_nats", o.initializeNATS)

	// Phase 3: Initialize Pulsar (with retry, non-blocking)
	go o.initializeWithRetry(ctx, "initialize_pulsar", o.initializePulsar)

	// Phase 4: Validate Database (optional, non-blocking)
	go o.initializeWithRetry(ctx, "validate_database", o.validateDatabase)

	// Phase 5: Cache Warming (optional, non-blocking)
	go o.initializeWithRetry(ctx, "warm_cache", o.warmCache)

	duration := time.Since(startTime).Seconds()
	o.metrics.RecordBootstrapDuration(ctx, duration)
	span.SetAttributes(attribute.Float64("bootstrap.duration_seconds", duration))
	span.SetStatus(codes.Ok, "bootstrap started asynchronously")

	o.logger.Info("platform bootstrap initiated (running in background)",
		"duration_seconds", duration)

	// Wait for shutdown signal
	<-ctx.Done()
	o.logger.Info("bootstrap orchestrator received shutdown signal")

	// Give background tasks a moment to complete gracefully
	time.Sleep(2 * time.Second)

	return nil
}

// runPhase executes a bootstrap phase with timing and error handling.
func (o *Orchestrator) runPhase(ctx context.Context, phaseName string, fn func(context.Context) error) error {
	ctx, span := o.tracer.Start(ctx, fmt.Sprintf("bootstrap.%s", phaseName))
	defer span.End()

	startTime := time.Now()
	o.logger.Info("starting bootstrap phase", "phase", phaseName)

	err := fn(ctx)
	duration := time.Since(startTime).Seconds()

	o.metrics.RecordBootstrapPhase(ctx, phaseName, duration)
	span.SetAttributes(
		attribute.String("phase", phaseName),
		attribute.Float64("duration_seconds", duration),
	)

	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "phase failed")
		o.logger.Error("bootstrap phase failed",
			"phase", phaseName,
			"duration_seconds", duration,
			"error", err)
		return pkgerrors.NewBootstrapError(phaseName, err)
	}

	o.logger.Info("bootstrap phase complete",
		"phase", phaseName,
		"duration_seconds", duration)
	return nil
}

// waitForDependencies waits for all critical dependencies to become healthy.
func (o *Orchestrator) waitForDependencies(ctx context.Context) error {
	timeout := o.cfg.Bootstrap.Timeout
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	o.logger.Info("waiting for critical dependencies", "timeout", timeout.String())
	return o.checker.WaitForDependencies(ctx)
}

// initializeNATS creates JetStream streams concurrently.
func (o *Orchestrator) initializeNATS(ctx context.Context) error {
	if len(o.cfg.Bootstrap.NATS.Streams) == 0 {
		o.logger.Info("no NATS streams configured, skipping")
		return nil
	}

	client, err := clients.NewNATSClient(ctx, o.cfg.Bootstrap.NATS)
	if err != nil {
		return fmt.Errorf("create NATS client: %w", err)
	}
	defer client.Close()

	// Create streams concurrently
	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(5) // Limit concurrent operations

	for _, streamCfg := range o.cfg.Bootstrap.NATS.Streams {
		streamCfg := streamCfg
		g.Go(func() error {
			return o.createNATSStream(gctx, client, streamCfg)
		})
	}

	return g.Wait()
}

// createNATSStream creates a single NATS stream with retry.
func (o *Orchestrator) createNATSStream(ctx context.Context, client *clients.NATSClient, cfg config.StreamConfig) error {
	ctx, span := o.tracer.Start(ctx, "bootstrap.create_nats_stream")
	defer span.End()

	span.SetAttributes(
		attribute.String("stream.name", cfg.Name),
		attribute.StringSlice("stream.subjects", cfg.Subjects),
	)

	o.logger.Info("creating NATS stream", "name", cfg.Name)

	operation := func() error {
		return client.CreateStream(ctx, cfg)
	}

	b := backoff.WithContext(
		backoff.WithMaxRetries(
			backoff.NewExponentialBackOff(),
			uint64(o.cfg.Bootstrap.RetryAttempts),
		),
		ctx,
	)

	if err := backoff.Retry(operation, b); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "failed to create stream")
		return fmt.Errorf("create stream %s: %w", cfg.Name, err)
	}

	o.logger.Info("NATS stream created", "name", cfg.Name)
	return nil
}

// initializePulsar creates Pulsar topics concurrently.
func (o *Orchestrator) initializePulsar(ctx context.Context) error {
	if len(o.cfg.Bootstrap.Pulsar.Topics) == 0 {
		o.logger.Info("no Pulsar topics configured, skipping")
		return nil
	}

	client, err := clients.NewPulsarClient(ctx, o.cfg.Bootstrap.Pulsar)
	if err != nil {
		return fmt.Errorf("create Pulsar client: %w", err)
	}
	defer client.Close()

	// Create topics concurrently
	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(5)

	for _, topicCfg := range o.cfg.Bootstrap.Pulsar.Topics {
		topicCfg := topicCfg
		g.Go(func() error {
			return o.createPulsarTopic(gctx, client, topicCfg)
		})
	}

	return g.Wait()
}

// createPulsarTopic creates a single Pulsar topic with retry.
func (o *Orchestrator) createPulsarTopic(ctx context.Context, client *clients.PulsarClient, cfg config.TopicConfig) error {
	ctx, span := o.tracer.Start(ctx, "bootstrap.create_pulsar_topic")
	defer span.End()

	span.SetAttributes(
		attribute.String("topic.name", cfg.Name),
		attribute.Int("topic.partitions", cfg.Partitions),
	)

	o.logger.Info("creating Pulsar topic", "name", cfg.Name)

	operation := func() error {
		return client.CreateTopic(ctx, cfg.Name, cfg.Partitions)
	}

	b := backoff.WithContext(
		backoff.WithMaxRetries(
			backoff.NewExponentialBackOff(),
			uint64(o.cfg.Bootstrap.RetryAttempts),
		),
		ctx,
	)

	if err := backoff.Retry(operation, b); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "failed to create topic")
		return fmt.Errorf("create topic %s: %w", cfg.Name, err)
	}

	o.logger.Info("Pulsar topic created", "name", cfg.Name)
	return nil
}

// validateDatabase validates database schema existence.
func (o *Orchestrator) validateDatabase(ctx context.Context) error {
	client, err := clients.NewPostgresClient(ctx, o.cfg.Bootstrap.Postgres)
	if err != nil {
		return fmt.Errorf("create postgres client: %w", err)
	}
	defer client.Close()

	o.logger.Info("validating database schema")
	return client.ValidateSchema(ctx, "public")
}

// warmCache performs optional cache warming operations.
func (o *Orchestrator) warmCache(ctx context.Context) error {
	client, err := clients.NewRedisClient(ctx, o.cfg.Bootstrap.Redis)
	if err != nil {
		return fmt.Errorf("create redis client: %w", err)
	}
	defer client.Close()

	o.logger.Info("warming cache")
	return client.Ping(ctx)
}

// checkDependenciesAsync performs a quick non-blocking check of dependencies.
func (o *Orchestrator) checkDependenciesAsync(ctx context.Context) {
	results := o.checker.RunAll(ctx)

	for name, result := range results {
		if result.OK {
			o.logger.Info("dependency available",
				"service", name,
				"latency_ms", result.LatencyMS)
		} else {
			o.logger.Warn("dependency not ready (will retry in background)",
				"service", name,
				"error", result.Error)
		}
	}
}

// monitorDependencies continuously monitors dependency health in the background.
func (o *Orchestrator) monitorDependencies(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	o.logger.Info("starting background dependency monitoring")

	for {
		select {
		case <-ctx.Done():
			o.logger.Info("stopping dependency monitoring")
			return
		case <-ticker.C:
			results := o.checker.RunAll(ctx)

			healthyCount := 0
			totalCount := len(results)

			for name, result := range results {
				if result.OK {
					healthyCount++
					o.logger.Debug("dependency health check",
						"service", name,
						"status", "healthy",
						"latency_ms", result.LatencyMS)
				} else {
					o.logger.Warn("dependency unhealthy",
						"service", name,
						"error", result.Error)
				}
			}

			o.logger.Info("dependency health summary",
				"healthy", healthyCount,
				"total", totalCount)
		}
	}
}

// initializeWithRetry runs an initialization function with exponential backoff retry.
// Uses a timeout-based context instead of the parent context to allow retries to complete.
func (o *Orchestrator) initializeWithRetry(ctx context.Context, phaseName string, fn func(context.Context) error) {
	o.logger.Info("starting async initialization", "phase", phaseName)

	// Create a new context with timeout instead of using parent context
	// This prevents premature cancellation during service shutdown
	retryCtx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	// But still respect the parent context cancellation
	go func() {
		select {
		case <-ctx.Done():
			// Parent context canceled - give current operation 30s to finish gracefully
			time.Sleep(30 * time.Second)
			cancel()
		case <-retryCtx.Done():
			// Retry context timed out naturally
		}
	}()

	backoffStrategy := backoff.NewExponentialBackOff()
	backoffStrategy.InitialInterval = 2 * time.Second
	backoffStrategy.MaxInterval = 30 * time.Second
	backoffStrategy.MaxElapsedTime = 5 * time.Minute // Retry for up to 5 minutes

	operation := func() error {
		// Use a fresh context for each attempt
		phaseCtx, phaseCancel := context.WithTimeout(retryCtx, 30*time.Second)
		defer phaseCancel()

		startTime := time.Now()
		err := fn(phaseCtx)
		duration := time.Since(startTime).Seconds()

		o.metrics.RecordBootstrapPhase(ctx, phaseName, duration)

		if err != nil {
			// Check if it's a context cancellation - if so, don't retry
			if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
				o.logger.Warn("initialization phase context canceled",
					"phase", phaseName,
					"error", err)
				return backoff.Permanent(err) // Don't retry on context cancellation
			}

			o.logger.Warn("initialization phase failed, will retry",
				"phase", phaseName,
				"error", err,
				"duration_seconds", duration)
			o.metrics.RecordBootstrapError(ctx, phaseName)
			return err
		}

		o.logger.Info("initialization phase complete",
			"phase", phaseName,
			"duration_seconds", duration)
		return nil
	}

	// Run with backoff
	if err := backoff.Retry(operation, backoff.WithContext(backoffStrategy, retryCtx)); err != nil {
		o.logger.Error("initialization phase failed after retries",
			"phase", phaseName,
			"error", err)
	}
}
