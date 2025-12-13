# ---- Build Stage ----
# Use an official Go image as a parent image.
# This contains all the Go tools needed to compile your application.
FROM golang:1.25-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set the working directory inside the container.
WORKDIR /app

# Copy go.mod and go.sum files to download dependencies.
# This is done in a separate step to leverage Docker's layer caching.
# Dependencies are only re-downloaded if go.mod or go.sum change.
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code into the container.
COPY . .

# Build the Go application.
# CGO_ENABLED=0 creates a statically linked binary.
# -ldflags="-w -s" strips debug information, reducing the binary size.
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-w -s -X main.version=1.0.0" -o /app/raymond ./cmd/raymond

# ---- Final Stage ----
# Use a minimal, lightweight base image for the final container.
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata wget && \
    addgroup -g 1000 raymond && \
    adduser -D -u 1000 -G raymond raymond

# Copy the built binary from the 'builder' stage.
COPY --from=builder /app/raymond /usr/local/bin/raymond

# Copy example config (can be overridden with volume mount)
COPY config.example.yaml /etc/raymond/config.yaml

# Use non-root user
USER raymond

# Expose service port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=30s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1

# Command to run the executable when the container starts.
CMD ["raymond", "-config", "/etc/raymond/config.yaml"]
