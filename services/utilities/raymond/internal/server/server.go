package server

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/arc-framework/platform-spike/services/raymond/internal/config"
	"github.com/arc-framework/platform-spike/services/raymond/internal/health"
	"github.com/arc-framework/platform-spike/services/raymond/internal/middleware"
	"github.com/arc-framework/platform-spike/services/raymond/internal/telemetry"
	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

// Server manages the HTTP server lifecycle.
type Server struct {
	cfg           *config.ServerConfig
	logger        *slog.Logger
	metrics       *telemetry.Metrics
	healthHandler *health.Handler
	httpServer    *http.Server
}

// NewServer creates a new HTTP server.
func NewServer(
	cfg *config.ServerConfig,
	logger *slog.Logger,
	metrics *telemetry.Metrics,
	healthHandler *health.Handler,
) *Server {
	return &Server{
		cfg:           cfg,
		logger:        logger,
		metrics:       metrics,
		healthHandler: healthHandler,
	}
}

// Start initializes and starts the HTTP server.
// This method blocks until the server is shut down.
func (s *Server) Start() error {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()

	// Middleware chain (order matters!)
	router.Use(middleware.Recovery(s.logger))
	router.Use(otelgin.Middleware("arc-raymond-bootstrap"))
	router.Use(middleware.RequestLogger(s.logger, s.metrics))

	// Register routes
	s.registerRoutes(router)

	// Create HTTP server
	s.httpServer = &http.Server{
		Addr:         fmt.Sprintf(":%d", s.cfg.Port),
		Handler:      router,
		ReadTimeout:  s.cfg.ReadTimeout,
		WriteTimeout: s.cfg.WriteTimeout,
	}

	s.logger.Info("starting HTTP server", "port", s.cfg.Port)

	// Start server (blocks until shutdown)
	if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		s.logger.Error("HTTP server failed to start", "error", err)
		return fmt.Errorf("http server: %w", err)
	}

	return nil
}

// Shutdown gracefully shuts down the HTTP server.
func (s *Server) Shutdown(ctx context.Context) error {
	s.logger.Info("shutting down HTTP server")
	return s.httpServer.Shutdown(ctx)
}

// registerRoutes sets up all HTTP routes.
func (s *Server) registerRoutes(router *gin.Engine) {
	// Health endpoints
	router.GET("/health", s.healthHandler.HealthHandler)
	router.GET("/health/deep", s.healthHandler.DeepHealthHandler)
	router.GET("/ready", s.healthHandler.ReadyHandler)

	// Root endpoint
	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": "arc-raymond-bootstrap",
			"status":  "running",
		})
	})
}
