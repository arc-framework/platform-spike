package telemetry

import (
	"context"
	"fmt"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
)

// Metrics holds all application metrics.
type Metrics struct {
	BootstrapDuration      metric.Float64Histogram
	BootstrapPhaseDuration metric.Float64Histogram
	BootstrapErrors        metric.Int64Counter
	DependencyHealthy      metric.Int64Gauge
	HTTPRequestsTotal      metric.Int64Counter
	HTTPRequestDuration    metric.Float64Histogram
}

// NewMetrics creates and registers all application metrics.
func NewMetrics(meter metric.Meter) (*Metrics, error) {
	bootstrapDuration, err := meter.Float64Histogram(
		"raymond.bootstrap.duration_seconds",
		metric.WithDescription("Total bootstrap time in seconds"),
		metric.WithUnit("s"),
	)
	if err != nil {
		return nil, fmt.Errorf("create bootstrap_duration metric: %w", err)
	}

	bootstrapPhaseDuration, err := meter.Float64Histogram(
		"raymond.bootstrap.phase_duration_seconds",
		metric.WithDescription("Per-phase bootstrap duration in seconds"),
		metric.WithUnit("s"),
	)
	if err != nil {
		return nil, fmt.Errorf("create phase_duration metric: %w", err)
	}

	bootstrapErrors, err := meter.Int64Counter(
		"raymond.bootstrap.errors_total",
		metric.WithDescription("Bootstrap failures by phase"),
	)
	if err != nil {
		return nil, fmt.Errorf("create bootstrap_errors metric: %w", err)
	}

	dependencyHealthy, err := meter.Int64Gauge(
		"raymond.dependency.healthy",
		metric.WithDescription("Dependency health status (1=healthy, 0=unhealthy)"),
	)
	if err != nil {
		return nil, fmt.Errorf("create dependency_healthy metric: %w", err)
	}

	httpRequestsTotal, err := meter.Int64Counter(
		"raymond.http.requests_total",
		metric.WithDescription("HTTP requests by endpoint and status"),
	)
	if err != nil {
		return nil, fmt.Errorf("create http_requests_total metric: %w", err)
	}

	httpRequestDuration, err := meter.Float64Histogram(
		"raymond.http.request_duration_seconds",
		metric.WithDescription("HTTP request latency in seconds"),
		metric.WithUnit("s"),
	)
	if err != nil {
		return nil, fmt.Errorf("create http_request_duration metric: %w", err)
	}

	return &Metrics{
		BootstrapDuration:      bootstrapDuration,
		BootstrapPhaseDuration: bootstrapPhaseDuration,
		BootstrapErrors:        bootstrapErrors,
		DependencyHealthy:      dependencyHealthy,
		HTTPRequestsTotal:      httpRequestsTotal,
		HTTPRequestDuration:    httpRequestDuration,
	}, nil
}

// RecordBootstrapDuration records the total bootstrap time.
func (m *Metrics) RecordBootstrapDuration(ctx context.Context, seconds float64) {
	m.BootstrapDuration.Record(ctx, seconds)
}

// RecordBootstrapPhase records a phase duration with phase label.
func (m *Metrics) RecordBootstrapPhase(ctx context.Context, phase string, seconds float64) {
	attrs := attribute.NewSet(attribute.String("phase", phase))
	m.BootstrapPhaseDuration.Record(ctx, seconds, metric.WithAttributeSet(attrs))
}

// RecordBootstrapError increments error counter for a phase.
func (m *Metrics) RecordBootstrapError(ctx context.Context, phase string) {
	attrs := attribute.NewSet(attribute.String("phase", phase))
	m.BootstrapErrors.Add(ctx, 1, metric.WithAttributeSet(attrs))
}

// RecordHTTPRequest records HTTP request metrics.
func (m *Metrics) RecordHTTPRequest(ctx context.Context, method, path string, status int, duration float64) {
	attrs := attribute.NewSet(
		attribute.String("method", method),
		attribute.String("path", path),
		attribute.Int("status", status),
	)
	m.HTTPRequestsTotal.Add(ctx, 1, metric.WithAttributeSet(attrs))

	durationAttrs := attribute.NewSet(
		attribute.String("method", method),
		attribute.String("path", path),
	)
	m.HTTPRequestDuration.Record(ctx, duration, metric.WithAttributeSet(durationAttrs))
}
