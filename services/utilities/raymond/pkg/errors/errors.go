package errors

import (
	"errors"
	"fmt"
)

var (
	// ErrDependencyTimeout is returned when a dependency health check times out.
	ErrDependencyTimeout = errors.New("dependency health check timeout")

	// ErrDependencyUnhealthy is returned when a critical dependency is unhealthy.
	ErrDependencyUnhealthy = errors.New("critical dependency unhealthy")

	// ErrBootstrapFailed is returned when the bootstrap process fails.
	ErrBootstrapFailed = errors.New("bootstrap process failed")

	// ErrConfigInvalid is returned when configuration validation fails.
	ErrConfigInvalid = errors.New("invalid configuration")

	// ErrCircuitOpen is returned when a circuit breaker is open.
	ErrCircuitOpen = errors.New("circuit breaker open")
)

// DependencyError wraps an error with dependency context.
type DependencyError struct {
	Service string
	Err     error
}

func (e *DependencyError) Error() string {
	return fmt.Sprintf("dependency %s: %v", e.Service, e.Err)
}

func (e *DependencyError) Unwrap() error {
	return e.Err
}

// NewDependencyError creates a new dependency error.
func NewDependencyError(service string, err error) error {
	return &DependencyError{Service: service, Err: err}
}

// BootstrapError wraps an error with bootstrap phase context.
type BootstrapError struct {
	Phase string
	Err   error
}

func (e *BootstrapError) Error() string {
	return fmt.Sprintf("bootstrap phase %s: %v", e.Phase, e.Err)
}

func (e *BootstrapError) Unwrap() error {
	return e.Err
}

// NewBootstrapError creates a new bootstrap error.
func NewBootstrapError(phase string, err error) error {
	return &BootstrapError{Phase: phase, Err: err}
}
