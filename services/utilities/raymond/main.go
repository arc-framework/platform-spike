package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/log"
	"go.opentelemetry.io/otel/log/global"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// multiSlogHandler is a custom slog.Handler that writes to multiple handlers.
type multiSlogHandler struct {
	handlers []slog.Handler
}

// NewMultiSlogHandler creates a handler that duplicates its writes to all the
// provided handlers.
func NewMultiSlogHandler(handlers ...slog.Handler) slog.Handler {
	return &multiSlogHandler{handlers: handlers}
}

// Implement the slog.Handler interface for multiSlogHandler
func (h *multiSlogHandler) Enabled(ctx context.Context, level slog.Level) bool {
	// Enabled if any of the underlying handlers are enabled.
	for _, handler := range h.handlers {
		if handler.Enabled(ctx, level) {
			return true
		}
	}
	return false
}
func (h *multiSlogHandler) Handle(ctx context.Context, r slog.Record) error {
	for _, handler := range h.handlers {
		if err := handler.Handle(ctx, r); err != nil {
			return err
		}
	}
	return nil
}
func (h *multiSlogHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	newHandlers := make([]slog.Handler, len(h.handlers))
	for i, handler := range h.handlers {
		newHandlers[i] = handler.WithAttrs(attrs)
	}
	return &multiSlogHandler{handlers: newHandlers}
}
func (h *multiSlogHandler) WithGroup(name string) slog.Handler {
	newHandlers := make([]slog.Handler, len(h.handlers))
	for i, handler := range h.handlers {
		newHandlers[i] = handler.WithGroup(name)
	}
	return &multiSlogHandler{handlers: newHandlers}
}

// slogOtelHandler is a custom slog.Handler that sends log records to an OpenTelemetry Logger.
type slogOtelHandler struct {
	logger log.Logger
}

// NewSlogOtelHandler creates a new handler that wraps the given OpenTelemetry Logger.
func NewSlogOtelHandler(l log.Logger) slog.Handler {
	return &slogOtelHandler{logger: l}
}

// Enabled reports whether the handler handles records at the given level.
func (h *slogOtelHandler) Enabled(_ context.Context, level slog.Level) bool {
	return level >= slog.LevelInfo // Adjust level as needed
}

// Handle processes the log record and sends it to the OpenTelemetry logger.
func (h *slogOtelHandler) Handle(ctx context.Context, rec slog.Record) error {
	logRecord := log.Record{}
	logRecord.SetTimestamp(rec.Time)
	logRecord.SetObservedTimestamp(time.Now())
	logRecord.SetSeverity(slogLevelToOtelSeverity(rec.Level))
	logRecord.SetBody(log.StringValue(rec.Message))
	rec.Attrs(func(attr slog.Attr) bool {
		logRecord.AddAttributes(log.String(attr.Key, attr.Value.String()))
		return true
	})
	h.logger.Emit(ctx, logRecord)
	return nil
}

// WithAttrs returns a new handler with the given attributes.
func (h *slogOtelHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	// For simplicity, this example doesn't handle nested attributes.
	// A production-ready handler would need to manage these.
	return h
}

// WithGroup returns a new handler with the given group name.
func (h *slogOtelHandler) WithGroup(name string) slog.Handler {
	// For simplicity, this example doesn't handle groups.
	return h
}

// slogLevelToOtelSeverity converts slog levels to OpenTelemetry severity numbers.
func slogLevelToOtelSeverity(l slog.Level) log.Severity {
	switch l {
	case slog.LevelDebug:
		return log.SeverityDebug
	case slog.LevelInfo:
		return log.SeverityInfo
	case slog.LevelWarn:
		return log.SeverityWarn
	case slog.LevelError:
		return log.SeverityError
	default:
		return log.SeverityInfo
	}
}

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

	// --- gRPC CONNECTION SETUP ---
	// Create a single, shared gRPC connection for all OTLP exporters.
	// This is more efficient and ensures consistent configuration.
	// The endpoint is configured via the OTEL_EXPORTER_OTLP_ENDPOINT env var.
	// The connection security is configured via the OTEL_EXPORTER_OTLP_INSECURE env var.
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "otel-collector:4317" // Default for Docker Compose environment
		slog.Warn("OTEL_EXPORTER_OTLP_ENDPOINT not set, using default", "endpoint", endpoint)
	}

	// Conditionally set transport security based on the OTEL_EXPORTER_OTLP_INSECURE env var.
	dialOptions := []grpc.DialOption{grpc.WithBlock()}
	if os.Getenv("OTEL_EXPORTER_OTLP_INSECURE") == "true" {
		// This is the crucial part: explicitly tell gRPC not to use TLS.
		dialOptions = append(dialOptions, grpc.WithTransportCredentials(insecure.NewCredentials()))
	}

	conn, err := grpc.NewClient(endpoint, dialOptions...)
	if err != nil {
		return nil, fmt.Errorf("failed to create gRPC connection to collector: %w", err)
	}

	// --- TRACER SETUP ---
	// The exporter will be configured using environment variables:
	// - OTEL_EXPORTER_OTLP_ENDPOINT
	// - OTEL_EXPORTER_OTLP_INSECURE
	traceExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithGRPCConn(conn),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create trace exporter: %w", err)
	}

	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
		sdktrace.WithResource(res),
		// Use a Batcher for efficiency, but a SimpleSpanProcessor for local dev
		// can be useful to see traces immediately.
		sdktrace.WithBatcher(traceExporter, sdktrace.WithBatchTimeout(1*time.Second)),
	)
	otel.SetTracerProvider(tracerProvider)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	// --- METER SETUP ---
	metricExporter, err := otlpmetricgrpc.New(ctx,
		// The exporter will be configured using the same environment variables.
		otlpmetricgrpc.WithGRPCConn(conn),
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
		// The exporter will be configured using the same environment variables.
		otlploggrpc.WithGRPCConn(conn),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create log exporter: %w", err)
	}

	loggerProvider := sdklog.NewLoggerProvider(
		sdklog.WithResource(res),
		sdklog.WithProcessor(sdklog.NewBatchProcessor(logExporter)),
	)
	global.SetLoggerProvider(loggerProvider)

	// Create a multi-handler to log to both the console (for local dev) and OTel.
	otelHandler := NewSlogOtelHandler(loggerProvider.Logger("main"))
	consoleHandler := slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})

	// Set the default logger to use the multi-handler.
	slog.SetDefault(slog.New(NewMultiSlogHandler(consoleHandler, otelHandler)))

	// Return a function that gracefully shuts down both providers.
	return func(ctx context.Context) error {
		// Close the gRPC connection.
		if err := conn.Close(); err != nil {
			slog.Error("failed to close gRPC connection", "error", err)
		}
		// Shutdown providers in reverse order of initialization: logger, meter, tracer.
		if err := loggerProvider.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown LoggerProvider: %w", err)
		}
		if err := meterProvider.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown MeterProvider: %w", err)
		}
		if err := tracerProvider.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown TracerProvider: %w", err)
		}
		return nil
	}, nil
}

// App holds the application's dependencies.
type App struct {
	tracer         trace.Tracer
	meter          metric.Meter
	backgroundRuns metric.Int64Counter
	onDemandRuns   metric.Int64Counter
}

// runBackgroundWorker starts a ticker to perform a unit of work at a regular interval.
func (a *App) runBackgroundWorker(ctx context.Context) {
	// Start a ticker to run the work every 10 seconds.
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	slog.Info("Background worker started. Will run every 10 seconds.")

	for {
		select {
		case <-ticker.C:
			// Start a new trace for this unit of work.
			workCtx, span := a.tracer.Start(ctx, "background-work-iteration")

			slog.InfoContext(workCtx, "Performing background work...")
			for i := 0; i < 5; i++ {
				_, iSpan := a.tracer.Start(workCtx, fmt.Sprintf("work-item-%d", i))
				a.backgroundRuns.Add(workCtx, 1)
				time.Sleep(100 * time.Millisecond)
				iSpan.End()
			}
			slog.InfoContext(workCtx, "Background work complete.")
			span.End()
		case <-ctx.Done():
			slog.Info("Background worker stopping.")
			return
		}
	}
}

// loggingMiddleware logs the request and response.
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ctx := r.Context()

		// Log the incoming request
		slog.InfoContext(ctx, "request received",
			"method", r.Method,
			"path", r.URL.Path,
			"remote_addr", r.RemoteAddr,
			"user_agent", r.UserAgent(),
		)

		// Use a custom response writer to capture status code
		rw := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(rw, r)

		// Log the response
		slog.InfoContext(ctx, "response sent",
			"status_code", rw.statusCode,
			"duration", time.Since(start).String(),
		)
	})
}

// onDemandWorkHandler is an HTTP handler that performs a unit of work when called.
func (a *App) onDemandWorkHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// The otelhttp handler already created a span for us. We can add events to it.
	span := trace.SpanFromContext(ctx)
	span.AddEvent("Starting on-demand work")

	a.onDemandRuns.Add(ctx, 1)
	time.Sleep(150 * time.Millisecond) // Simulate some work.

	span.AddEvent("On-demand work complete")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "On-demand work complete!")
}

// health result structures
type checkResult struct {
	OK        bool   `json:"ok"`
	LatencyMS int64  `json:"latency_ms,omitempty"`
	Error     string `json:"error,omitempty"`
}

// probeTCP performs a TCP dial to host:port with timeout
func probeTCP(ctx context.Context, addr string, timeout time.Duration) checkResult {
	start := time.Now()
	dialer := &net.Dialer{}
	cctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	conn, err := dialer.DialContext(cctx, "tcp", addr)
	lat := time.Since(start).Milliseconds()
	if err != nil {
		return checkResult{OK: false, LatencyMS: lat, Error: err.Error()}
	}
	_ = conn.Close()
	return checkResult{OK: true, LatencyMS: lat}
}

// probeHTTP performs an HTTP GET and considers 2xx success
func probeHTTP(ctx context.Context, url string, timeout time.Duration) checkResult {
	start := time.Now()
	req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
	client := &http.Client{Timeout: timeout}
	resp, err := client.Do(req)
	lat := time.Since(start).Milliseconds()
	if err != nil {
		return checkResult{OK: false, LatencyMS: lat, Error: err.Error()}
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return checkResult{OK: true, LatencyMS: lat}
	}
	return checkResult{OK: false, LatencyMS: lat, Error: fmt.Sprintf("status=%d", resp.StatusCode)}
}

func main() {
	slog.Info("Starting arc-raymond-services (utility runner)...")

	// Set up a context that is canceled on an interrupt signal.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	shutdown, err := newOtelProvider(ctx)
	if err != nil {
		slog.Error("failed to set up OpenTelemetry", "error", err)
		os.Exit(1)
	}
	// Defer the shutdown function to be called when main exits.
	defer func() {
		// Allow 10 seconds for a graceful shutdown.
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := shutdown(shutdownCtx); err != nil {
			slog.Error("failed to shutdown OpenTelemetry provider", "error", err)
		}
	}()

	// Use a conventional naming scheme for tracer and meter.
	tracer := otel.Tracer("github.com/arc-framework/platform-spike/services/raymond")
	meter := otel.Meter("github.com/arc-framework/platform-spike/services/raymond")

	// --- Initialize Metrics ---
	// Create metrics once and reuse them to be more efficient.
	backgroundRuns, err := meter.Int64Counter("background.runs.count", metric.WithDescription("The number of times the background worker ran."))
	if err != nil {
		slog.Error("failed to create background runs counter", "error", err)
		os.Exit(1)
	}
	onDemandRuns, err := meter.Int64Counter("ondemand.runs.count", metric.WithDescription("The number of times the on-demand endpoint was called."))
	if err != nil {
		slog.Error("failed to create on-demand runs counter", "error", err)
		os.Exit(1)
	}

	// Create our application struct for the HTTP server.
	app := &App{
		tracer:         tracer,
		meter:          meter,
		backgroundRuns: backgroundRuns,
		onDemandRuns:   onDemandRuns,
	}

	// Start the background worker in a goroutine.
	go app.runBackgroundWorker(ctx)

	// --- HTTP Server (gin) ---
	servicePort := os.Getenv("SERVICE_PORT")
	if servicePort == "" {
		servicePort = os.Getenv("SWISS_ARMY_PORT")
		if servicePort == "" {
			servicePort = "7100"
		}
	}

	// Create gin router and routes
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())

	// Logging middleware reuses existing logging by bridging gin to slog
	r.Use(func(c *gin.Context) {
		start := time.Now()
		c.Next()
		slog.Info("request",
			"method", c.Request.Method,
			"path", c.Request.URL.Path,
			"status", c.Writer.Status(),
			"duration", time.Since(start).String(),
		)
	})

	// Shallow health endpoint (fast) for Docker healthcheck
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "time": time.Now().UTC().Format(time.RFC3339)})
	})

	// Deep health endpoint - gated by env or query param
	r.GET("/health/deep", func(c *gin.Context) {
		mode := c.Query("mode")
		enabled := os.Getenv("ENABLE_DEEP_HEALTH") == "true"
		if mode != "deep" && !enabled {
			c.JSON(http.StatusNotImplemented, gin.H{"error": "deep health checks are disabled. Use ?mode=deep or set ENABLE_DEEP_HEALTH=true"})
			return
		}

		// Build checks list and targets from env with sensible defaults
		postgresHost := os.Getenv("POSTGRES_HOST")
		if postgresHost == "" {
			postgresHost = "arc_postgres"
		}
		postgresPort := os.Getenv("POSTGRES_PORT")
		if postgresPort == "" {
			postgresPort = "5432"
		}
		redisHost := os.Getenv("REDIS_HOST")
		if redisHost == "" {
			redisHost = "arc_redis"
		}
		redisPort := os.Getenv("REDIS_PORT")
		if redisPort == "" {
			redisPort = "6379"
		}
		infisicalURL := os.Getenv("INFISICAL_URL")
		if infisicalURL == "" {
			infisicalURL = "http://arc_infisical:8080/api/status"
		}
		unleashURL := os.Getenv("UNLEASH_URL")
		if unleashURL == "" {
			unleashURL = "http://arc_unleash:4242/health"
		}

		// per-check timeout
		checkTimeoutMs := int64(3000)
		if v := os.Getenv("CHECK_TIMEOUT_MS"); v != "" {
			if parsed, err := time.ParseDuration(v + "ms"); err == nil {
				checkTimeoutMs = parsed.Milliseconds()
			}
		}
		timeout := time.Duration(checkTimeoutMs) * time.Millisecond

		// concurrent probes
		var wg sync.WaitGroup
		results := map[string]checkResult{}
		mu := sync.Mutex{}
		ctxTimeout, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
		defer cancel()

		checks := map[string]func(){
			"postgres": func() {
				res := probeTCP(ctxTimeout, net.JoinHostPort(postgresHost, postgresPort), timeout)
				mu.Lock()
				results["postgres"] = res
				mu.Unlock()
				wg.Done()
			},
			"redis": func() {
				res := probeTCP(ctxTimeout, net.JoinHostPort(redisHost, redisPort), timeout)
				mu.Lock()
				results["redis"] = res
				mu.Unlock()
				wg.Done()
			},
			"infisical": func() {
				res := probeHTTP(ctxTimeout, infisicalURL, timeout)
				mu.Lock()
				results["infisical"] = res
				mu.Unlock()
				wg.Done()
			},
			"unleash": func() {
				res := probeHTTP(ctxTimeout, unleashURL, timeout)
				mu.Lock()
				results["unleash"] = res
				mu.Unlock()
				wg.Done()
			},
		}

		wg.Add(len(checks))
		for _, fn := range checks {
			go fn()
		}
		wg.Wait()

		// aggregate
		allOK := true
		failed := 0
		for _, r := range results {
			if !r.OK {
				allOK = false
				failed++
			}
		}

		summary := fmt.Sprintf("%d/%d checks failed", failed, len(results))
		status := "ok"
		code := http.StatusOK
		if !allOK {
			status = "degraded"
			code = http.StatusServiceUnavailable
		}

		c.JSON(code, gin.H{"status": status, "summary": summary, "checks": results, "timestamp": time.Now().UTC().Format(time.RFC3339)})
	})

	// On-demand work endpoint (preserve existing handler)
	r.GET("/ondemand-work", func(c *gin.Context) {
		// Wrap the existing onDemandWorkHandler so OTEL instrumentation continues to work
		// Use the otelhttp handler to ensure traces are created for the function
		handler := otelhttp.NewHandler(http.HandlerFunc(app.onDemandWorkHandler), "HTTP GET /ondemand-work")
		handler.ServeHTTP(c.Writer, c.Request)
	})

	// Build and start server
	srv := &http.Server{
		Addr:    ":" + servicePort,
		Handler: r,
	}

	go func() {
		slog.Info("API server listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("API server failed", "error", err)
		}
	}()

	// Wait for an interrupt signal.
	<-ctx.Done()

	// Graceful shutdown of HTTP server
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("server forced to shutdown", "error", err)
	}

	// ...existing code... (deferred otel shutdown will run)
}

// responseWriter is a wrapper around http.ResponseWriter to capture the status code.
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}
