package telemetry

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Provider manages OpenTelemetry SDK resources.
type Provider struct {
	logger       *slog.Logger
	tracer       trace.Tracer
	meter        metric.Meter
	shutdownFunc func(context.Context) error
}

// NewProvider initializes the OpenTelemetry SDK with OTLP exporters.
func NewProvider(ctx context.Context, endpoint string, useInsecure bool, serviceName string, logLevel string) (*Provider, error) {
	// Create resource with service metadata
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion("1.0.0"),
			semconv.ServiceNamespace("arc"),
		),
		resource.WithHost(),
		resource.WithOS(),
		resource.WithProcess(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// Create shared gRPC connection for all exporters
	var dialOpts []grpc.DialOption
	if useInsecure {
		dialOpts = append(dialOpts, grpc.WithTransportCredentials(insecure.NewCredentials()))
	} else {
		// In production, use TLS credentials
		// TODO: Add proper TLS configuration
		dialOpts = append(dialOpts, grpc.WithTransportCredentials(insecure.NewCredentials()))
	}

	conn, err := grpc.NewClient(endpoint, dialOpts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create gRPC connection: %w", err)
	}

	// Initialize trace exporter and provider
	traceExporter, err := otlptracegrpc.New(ctx, otlptracegrpc.WithGRPCConn(conn))
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to create trace exporter: %w", err)
	}

	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithResource(res),
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)
	otel.SetTracerProvider(tracerProvider)

	// Initialize metric exporter and provider
	metricExporter, err := otlpmetricgrpc.New(ctx, otlpmetricgrpc.WithGRPCConn(conn))
	if err != nil {
		tracerProvider.Shutdown(ctx)
		conn.Close()
		return nil, fmt.Errorf("failed to create metric exporter: %w", err)
	}

	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter,
			sdkmetric.WithInterval(10*time.Second))),
	)
	otel.SetMeterProvider(meterProvider)

	// Set global propagator for context propagation
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	// Create structured logger with JSON output
	// The OTEL collector will capture these logs from stdout
	level := parseLogLevel(logLevel)
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
		ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
			// Add service metadata to all log entries
			if a.Key == slog.SourceKey {
				return slog.Attr{}
			}
			return a
		},
	}))

	// Add service context to logger
	logger = logger.With(
		"service.name", serviceName,
		"service.version", "1.0.0",
		"service.namespace", "arc",
	)

	// Create tracer and meter instances
	tracer := tracerProvider.Tracer(serviceName)
	meter := meterProvider.Meter(serviceName)

	// Define shutdown function for graceful cleanup
	shutdownFunc := func(ctx context.Context) error {
		var errs []error
		if err := meterProvider.Shutdown(ctx); err != nil {
			errs = append(errs, fmt.Errorf("meter provider shutdown: %w", err))
		}
		if err := tracerProvider.Shutdown(ctx); err != nil {
			errs = append(errs, fmt.Errorf("tracer provider shutdown: %w", err))
		}
		if err := conn.Close(); err != nil {
			errs = append(errs, fmt.Errorf("grpc connection close: %w", err))
		}
		if len(errs) > 0 {
			return fmt.Errorf("shutdown errors: %v", errs)
		}
		return nil
	}

	return &Provider{
		logger:       logger,
		tracer:       tracer,
		meter:        meter,
		shutdownFunc: shutdownFunc,
	}, nil
}

// Logger returns the structured logger.
func (p *Provider) Logger() *slog.Logger {
	return p.logger
}

// Tracer returns the OpenTelemetry tracer.
func (p *Provider) Tracer() trace.Tracer {
	return p.tracer
}

// Meter returns the OpenTelemetry meter.
func (p *Provider) Meter() metric.Meter {
	return p.meter
}

// Shutdown gracefully shuts down all telemetry providers.
func (p *Provider) Shutdown(ctx context.Context) error {
	return p.shutdownFunc(ctx)
}

// parseLogLevel converts string log level to slog.Level.
func parseLogLevel(level string) slog.Level {
	switch level {
	case "debug":
		return slog.LevelDebug
	case "info":
		return slog.LevelInfo
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
