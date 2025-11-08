# Stage 1: Build the health_check utility.
# Use a Go image to compile our small health check program.
FROM golang:1.22-alpine AS health_checker
WORKDIR /src
COPY ./health_check/main.go .
# Build a statically-linked, minimal binary.
# We use GO111MODULE=off because this is a simple program without a go.mod file.
RUN CGO_ENABLED=0 GO111MODULE=off go build -ldflags="-w -s" -o /health_check .

# Stage 2: Prepare the final collector image.
# Start from the official, secure, distroless contrib image.
FROM otel/opentelemetry-collector-contrib:latest

# Copy the compiled health_check binary from the first stage.
COPY --from=health_checker /health_check /health_check