package health

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/arc-framework/platform-spike/services/raymond/internal/config"
	"golang.org/x/sync/errgroup"
)

// ProbeResult contains the result of a health probe.
type ProbeResult struct {
	Name      string
	OK        bool
	LatencyMS int64
	Error     string
}

// Checker orchestrates health checks for all dependencies.
type Checker struct {
	dependencies []config.DependencyConfig
	logger       *slog.Logger
	timeout      time.Duration
}

// NewChecker creates a new health checker.
func NewChecker(deps []config.DependencyConfig, logger *slog.Logger, timeout time.Duration) *Checker {
	return &Checker{
		dependencies: deps,
		logger:       logger,
		timeout:      timeout,
	}
}

// RunAll executes all health probes concurrently and returns results.
func (c *Checker) RunAll(ctx context.Context) map[string]ProbeResult {
	results := make(map[string]ProbeResult)
	var mu sync.Mutex

	g, gctx := errgroup.WithContext(ctx)
	g.SetLimit(10) // Limit concurrent probes

	for _, dep := range c.dependencies {
		dep := dep // Capture loop variable
		g.Go(func() error {
			result := c.runProbe(gctx, dep)
			mu.Lock()
			results[dep.Name] = result
			mu.Unlock()
			return nil
		})
	}

	_ = g.Wait() // Ignore errors, we collect results individually
	return results
}

// WaitForDependencies waits for all critical dependencies to become healthy.
// Returns when all critical deps are ready OR when maxWait duration is reached.
// This is non-blocking and will return with current status after timeout.
func (c *Checker) WaitForDependencies(ctx context.Context) error {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	maxWait := 30 * time.Second // Maximum initial wait time
	deadline := time.Now().Add(maxWait)

	for {
		select {
		case <-ctx.Done():
			// Context canceled - return current status instead of error
			results := c.RunAll(context.Background())
			c.logDependencyStatus(results)
			c.logger.Warn("dependency wait interrupted, continuing with current status")
			return nil // Don't fail, just continue

		case <-ticker.C:
			if time.Now().After(deadline) {
				// Timeout reached - log status and continue
				results := c.RunAll(context.Background())
				c.logDependencyStatus(results)
				c.logger.Warn("dependency wait timeout reached, continuing anyway",
					"max_wait", maxWait.String())
				return nil // Don't fail, just continue
			}

			results := c.RunAll(ctx)
			allHealthy := true
			unhealthyCount := 0

			for _, dep := range c.dependencies {
				if !dep.Critical {
					continue
				}
				result := results[dep.Name]
				if !result.OK {
					c.logger.Debug("waiting for critical dependency",
						"service", dep.Name,
						"error", result.Error)
					allHealthy = false
					unhealthyCount++
				}
			}

			if allHealthy {
				c.logger.Info("all critical dependencies healthy")
				return nil
			}

			c.logger.Debug("waiting for dependencies",
				"unhealthy_critical", unhealthyCount)
		}
	}
}

// logDependencyStatus logs the current status of all dependencies.
func (c *Checker) logDependencyStatus(results map[string]ProbeResult) {
	for name, result := range results {
		if result.OK {
			c.logger.Info("dependency status", "service", name, "status", "healthy")
		} else {
			c.logger.Warn("dependency status", "service", name, "status", "unhealthy", "error", result.Error)
		}
	}
}

// runProbe executes a single health probe based on dependency type.
func (c *Checker) runProbe(ctx context.Context, dep config.DependencyConfig) ProbeResult {
	timeout := dep.Timeout
	if timeout == 0 {
		timeout = c.timeout
	}

	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	start := time.Now()
	var err error

	switch dep.Type {
	case "tcp":
		err = c.probeTCP(ctx, dep.Address)
	case "http":
		err = c.probeHTTP(ctx, dep.URL)
	case "grpc":
		err = c.probeGRPC(ctx, dep.Address)
	default:
		err = fmt.Errorf("unknown probe type: %s", dep.Type)
	}

	latency := time.Since(start).Milliseconds()

	if err != nil {
		return ProbeResult{
			Name:      dep.Name,
			OK:        false,
			LatencyMS: latency,
			Error:     err.Error(),
		}
	}

	return ProbeResult{
		Name:      dep.Name,
		OK:        true,
		LatencyMS: latency,
		Error:     "",
	}
}

// probeTCP performs a TCP dial check.
func (c *Checker) probeTCP(ctx context.Context, address string) error {
	var d net.Dialer
	conn, err := d.DialContext(ctx, "tcp", address)
	if err != nil {
		return fmt.Errorf("tcp dial failed: %w", err)
	}
	conn.Close()
	return nil
}

// probeHTTP performs an HTTP GET request check.
func (c *Checker) probeHTTP(ctx context.Context, url string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("http request failed: %w", err)
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	return nil
}

// probeGRPC performs a gRPC health check (simplified).
func (c *Checker) probeGRPC(ctx context.Context, address string) error {
	// For now, use TCP check. In production, implement grpc.health.v1.Health service
	return c.probeTCP(ctx, address)
}
