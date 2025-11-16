module github.com/dgtalbug/arc-platform-spike/telemetry-service

go 1.22

require (
	github.com/apache/pulsar-client-go v0.12.1
	go.opentelemetry.io/otel v1.27.0
	go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc v0.0.0-20240518092009-09b833cf5a35
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.27.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.27.0
	go.opentelemetry.io/otel/sdk v1.27.0
	go.opentelemetry.io/otel/sdk/log v0.0.0-20240518092009-09b833cf5a35
	go.opentelemetry.io/otel/sdk/metric v1.27.0
	google.golang.org/grpc v1.64.0
	google.golang.org/protobuf v1.34.1
)
