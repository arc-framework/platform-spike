package middleware

import (
	"log/slog"
	"time"

	"github.com/arc-framework/platform-spike/services/raymond/internal/telemetry"
	"github.com/gin-gonic/gin"
)

// RequestLogger logs HTTP requests with structured logging.
func RequestLogger(logger *slog.Logger, metrics *telemetry.Metrics) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method

		c.Next()

		duration := time.Since(start)
		status := c.Writer.Status()

		logger.Info("request completed",
			"method", method,
			"path", path,
			"status", status,
			"duration_ms", duration.Milliseconds(),
			"client_ip", c.ClientIP(),
		)

		if metrics != nil {
			metrics.RecordHTTPRequest(c.Request.Context(), method, path, status, duration.Seconds())
		}
	}
}
