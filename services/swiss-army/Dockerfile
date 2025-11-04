# ---- Build Stage ----
# Use an official Go image as a parent image.
# This contains all the Go tools needed to compile your application.
FROM golang:1.25-alpine AS builder

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
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-w -s" -o /app/swiss-army .

# ---- Final Stage ----
# Use a minimal, lightweight base image for the final container.
FROM alpine:latest

RUN apk add --no-cache tzdata

# Copy the built binary from the 'builder' stage.
COPY --from=builder /app/swiss-army /swiss-army

# Command to run the executable when the container starts.
CMD ["/swiss-army"]