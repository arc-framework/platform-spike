package health

import (
	"log/slog"
	"net/http"
	"sync/atomic"

	"github.com/gin-gonic/gin"
)

// Handler provides HTTP handlers for health endpoints.
type Handler struct {
	checker *Checker
	logger  *slog.Logger
	ready   atomic.Bool
}

// NewHandler creates a new health handler.
func NewHandler(checker *Checker, logger *slog.Logger) *Handler {
	return &Handler{
		checker: checker,
		logger:  logger,
		ready:   atomic.Bool{},
	}
}

// SetReady marks the service as ready.
func (h *Handler) SetReady(ready bool) {
	h.ready.Store(ready)
}

// IsReady returns the readiness status.
func (h *Handler) IsReady() bool {
	return h.ready.Load()
}

// HealthHandler handles shallow health checks (fast, app alive).
func (h *Handler) HealthHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "healthy",
		"mode":   "shallow",
	})
}

// DeepHealthHandler handles deep health checks (all dependencies).
func (h *Handler) DeepHealthHandler(c *gin.Context) {
	results := h.checker.RunAll(c.Request.Context())

	allHealthy := true
	for _, result := range results {
		if !result.OK {
			allHealthy = false
		}
	}

	status := http.StatusOK
	if !allHealthy {
		status = http.StatusServiceUnavailable
	}

	c.JSON(status, gin.H{
		"status":       map[bool]string{true: "healthy", false: "unhealthy"}[allHealthy],
		"mode":         "deep",
		"dependencies": results,
	})
}

// ReadyHandler handles readiness probe (bootstrap complete).
func (h *Handler) ReadyHandler(c *gin.Context) {
	if !h.IsReady() {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"ready":   false,
			"message": "bootstrap not complete",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"ready":   true,
		"message": "service ready",
	})
}
