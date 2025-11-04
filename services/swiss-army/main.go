package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/log/global"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"

	"google.golang.org/grpc"
)

// newOtelProvider initializes and configures the OpenTelemetry SDK, returning a shutdown function.
func newOtelProvider(ctx context.Context) (func(context.Context) error, error) {
	// The OTEL_SERVICE_NAME environment variable will be used here.
	res, err := resource.New(ctx,
		resource.WithFromEnv(),
		resource.WithProcess(),
		resource.WithTelemetrySDK(),
		resource.WithHost(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// Define common gRPC connection options to reduce duplication.
	// The endpoint is the address of our OpenTelemetry Collector.
	endpoint := "otel-collector:4317"
	dialOptions := []grpc.DialOption{grpc.WithBlock()}

	// --- TRACER SETUP ---
	traceExporter, err := otlptracegrpc.New(ctx,
		// WithBlock forces the connection to be established on startup.
		// Combined with the docker-compose healthcheck, this ensures the
		// collector is ready before the app tries to connect.
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(),
		otlptracegrpc.WithDialOption(dialOptions...),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create trace exporter: %w", err)
	}

	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
		sdktrace.WithResource(res),
		sdktrace.WithBatcher(traceExporter),
	)
	otel.SetTracerProvider(tracerProvider)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	// --- METER SETUP ---
	metricExporter, err := otlpmetricgrpc.New(ctx,
		// Use the same blocking dial option for metrics.
		otlpmetricgrpc.WithEndpoint(endpoint),
		otlpmetricgrpc.WithInsecure(),
		otlpmetricgrpc.WithDialOption(dialOptions...),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create metrics exporter: %w", err)
	}

	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter, sdkmetric.WithInterval(5*time.Second))),
		sdkmetric.WithResource(res),
	)
	otel.SetMeterProvider(meterProvider)

	// --- LOGGER SETUP ---
	// This is the missing piece. We set up a third exporter for logs.
	logExporter, err := otlploggrpc.New(ctx,
		otlploggrpc.WithEndpoint(endpoint),
		otlploggrpc.WithInsecure(),
		otlploggrpc.WithDialOption(dialOptions...),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create log exporter: %w", err)
	}

	loggerProvider := sdklog.NewLoggerProvider(
		sdklog.WithResource(res),
		sdklog.WithProcessor(sdklog.NewBatchProcessor(logExporter)),
	)
	// Set the global logger provider. After this, any calls to the standard log package
	// will be routed through the OpenTelemetry pipeline.
	global.SetLoggerProvider(loggerProvider)

	// Return a function that gracefully shuts down both providers.
	return func(ctx context.Context) error {
		// Shutdown providers in reverse order of initialization.
		if err := meterProvider.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown MeterProvider: %w", err)
		}
		if err := loggerProvider.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown LoggerProvider: %w", err)
		}
		if err := tracerProvider.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown TracerProvider: %w", err)
		}
		return nil
	}, nil
}

func waitForDNS(host string) {
	for {
		log.Printf("Attempting to resolve DNS for %s...", host)
		_, err := net.LookupHost(host)
		if err == nil {
			log.Printf("DNS for %s resolved successfully.", host)
			return
		}
		log.Printf("DNS resolution failed for %s: %v. Retrying in 2 seconds...", host, err)
		time.Sleep(2 * time.Second)
	}
}

func main() {
	// This is a robust, brute-force method to ensure the otel-collector
	// is resolvable in the Docker network before we proceed.
	waitForDNS("otel-collector")

	log.Println("Starting swiss-army-go service...")

	// Set up a context that is canceled on an interrupt signal.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	// Set up OpenTelemetry.
	shutdown, err := newOtelProvider(ctx)
	if err != nil {
		log.Fatal(err)
	}
	// Defer the shutdown function to be called when main exits.
	defer func() {
		// Allow 10 seconds for a graceful shutdown.
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := shutdown(shutdownCtx); err != nil {
			log.Fatalf("failed to shutdown OpenTelemetry provider: %s", err)
		}
	}()

	// Use the service name from the resource for the tracer/meter names.
	// It's conventional to use a static name for the tracer/meter.
	tracer := otel.Tracer("github.com/arc-framework/platform-spike/swiss-army")
	meter := otel.Meter("github.com/arc-framework/platform-spike/swiss-army")

	// Attributes represent additional key-value descriptors that can be bound
	// to a metric observer or recorder.
	commonAttrs := []attribute.KeyValue{
		attribute.String("attrA", "chocolate"),
		attribute.String("attrB", "raspberry"),
		attribute.String("attrC", "vanilla"),
	}

	runCount, err := meter.Int64Counter("run.count", metric.WithDescription("The number of times the iteration ran"))
	if err != nil {
		log.Fatal(err)
	}

	// Work begins
	ctx, span := tracer.Start(
		ctx,
		"CollectorExporter-Example",
		trace.WithAttributes(commonAttrs...),
	)
	defer span.End()
	for i := 0; i < 10; i++ {
		_, iSpan := tracer.Start(ctx, fmt.Sprintf("Sample-%d", i))
		runCount.Add(ctx, 1, metric.WithAttributes(commonAttrs...))
		log.Printf("Doing really hard work (%d / 10)\n", i+1)

		<-time.After(time.Second)
		iSpan.End()
	}

	log.Printf("Done!")
}
