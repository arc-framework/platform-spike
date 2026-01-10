"""
OpenTelemetry instrumentation helpers for A.R.C. agent services.

Task: T027
Purpose: Simplify distributed tracing, metrics, and structured logging
Integration: OTEL Collector at arc-widow-otel (Jaeger, Prometheus, Loki backends)
"""

import logging
from contextlib import contextmanager
from typing import Any, Dict, Optional

from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.trace import Status, StatusCode

logger = logging.getLogger(__name__)


class OTELInstrumentation:
    """
    OpenTelemetry instrumentation for A.R.C. services.
    
    Features:
    - Automatic trace propagation for distributed tracing
    - Custom metric recording (latency, throughput, errors)
    - Structured logging with trace context
    - Service resource attributes for filtering
    
    Example:
        # Initialize instrumentation
        otel = OTELInstrumentation(
            service_name="arc-scarlett-voice",
            otel_endpoint="http://localhost:4317"
        )
        otel.setup()
        
        # Create traced function
        with otel.trace_span("process_audio") as span:
            span.set_attribute("room_name", "room-123")
            # ... processing logic ...
            otel.record_latency("audio_processing", duration_ms)
        
        # Record metrics
        otel.increment_counter("voice.sessions.started")
        otel.record_histogram("voice.audio.latency", latency_ms)
    """

    def __init__(
        self,
        service_name: str,
        service_version: str = "0.1.0",
        otel_endpoint: str = "http://localhost:4317",
        environment: str = "development",
    ):
        """
        Initialize OTEL instrumentation.
        
        Args:
            service_name: Name of the service (e.g., "arc-scarlett-voice")
            service_version: Service version
            otel_endpoint: OTEL Collector gRPC endpoint
            environment: Environment (development, staging, production)
        """
        self.service_name = service_name
        self.service_version = service_version
        self.otel_endpoint = otel_endpoint
        self.environment = environment

        # Create resource attributes
        self.resource = Resource.create(
            {
                "service.name": service_name,
                "service.version": service_version,
                "deployment.environment": environment,
            }
        )

        self.tracer_provider: Optional[TracerProvider] = None
        self.tracer: Optional[trace.Tracer] = None
        self.meter_provider: Optional[MeterProvider] = None
        self.meter: Optional[metrics.Meter] = None

        # Metric instruments (created lazily)
        self._counters: Dict[str, metrics.Counter] = {}
        self._histograms: Dict[str, metrics.Histogram] = {}
        self._gauges: Dict[str, metrics.ObservableGauge] = {}

    def setup(self):
        """
        Setup OpenTelemetry tracing and metrics.
        
        Configures:
        - Trace provider with OTLP exporter
        - Meter provider with OTLP exporter
        - Periodic metric export (60s interval)
        """
        try:
            # Setup tracing
            self._setup_tracing()

            # Setup metrics
            self._setup_metrics()

            logger.info(
                f"{self.service_name}: OpenTelemetry instrumentation configured "
                f"(endpoint: {self.otel_endpoint})"
            )

        except Exception as e:
            logger.error(
                f"{self.service_name}: Failed to setup OpenTelemetry: {e}"
            )
            raise

    def _setup_tracing(self):
        """Configure tracing with OTLP exporter"""
        # Create OTLP trace exporter
        otlp_exporter = OTLPSpanExporter(
            endpoint=self.otel_endpoint, insecure=True
        )

        # Create tracer provider
        self.tracer_provider = TracerProvider(resource=self.resource)

        # Add batch span processor
        self.tracer_provider.add_span_processor(
            BatchSpanProcessor(otlp_exporter)
        )

        # Set global tracer provider
        trace.set_tracer_provider(self.tracer_provider)

        # Get tracer
        self.tracer = trace.get_tracer(
            self.service_name, self.service_version
        )

        logger.info(f"{self.service_name}: Tracing configured")

    def _setup_metrics(self):
        """Configure metrics with OTLP exporter"""
        # Create OTLP metric exporter
        otlp_exporter = OTLPMetricExporter(
            endpoint=self.otel_endpoint, insecure=True
        )

        # Create metric reader with 60s export interval
        reader = PeriodicExportingMetricReader(
            otlp_exporter, export_interval_millis=60000
        )

        # Create meter provider
        self.meter_provider = MeterProvider(
            resource=self.resource, metric_readers=[reader]
        )

        # Set global meter provider
        metrics.set_meter_provider(self.meter_provider)

        # Get meter
        self.meter = metrics.get_meter(self.service_name, self.service_version)

        logger.info(f"{self.service_name}: Metrics configured")

    @contextmanager
    def trace_span(
        self, name: str, attributes: Optional[Dict[str, Any]] = None
    ):
        """
        Create a traced span with automatic status handling.
        
        Args:
            name: Span name (e.g., "process_audio", "db_query")
            attributes: Optional span attributes
        
        Yields:
            Span object
        
        Example:
            with otel.trace_span("stt_transcription", {"model": "whisper"}) as span:
                result = transcribe(audio)
                span.set_attribute("transcription_length", len(result))
        """
        if not self.tracer:
            raise RuntimeError("Tracer not initialized. Call setup() first.")

        with self.tracer.start_as_current_span(name) as span:
            # Set initial attributes
            if attributes:
                for key, value in attributes.items():
                    span.set_attribute(key, value)

            try:
                yield span
                # Mark span as successful
                span.set_status(Status(StatusCode.OK))

            except Exception as e:
                # Mark span as error
                span.set_status(Status(StatusCode.ERROR, str(e)))
                span.record_exception(e)
                raise

    def get_counter(self, name: str, description: str = "") -> metrics.Counter:
        """
        Get or create a counter metric.
        
        Args:
            name: Counter name (e.g., "voice.sessions.started")
            description: Counter description
        
        Returns:
            Counter instrument
        """
        if name not in self._counters:
            if not self.meter:
                raise RuntimeError("Meter not initialized. Call setup() first.")

            self._counters[name] = self.meter.create_counter(
                name, description=description
            )

        return self._counters[name]

    def get_histogram(
        self, name: str, description: str = "", unit: str = "ms"
    ) -> metrics.Histogram:
        """
        Get or create a histogram metric.
        
        Args:
            name: Histogram name (e.g., "voice.audio.latency")
            description: Histogram description
            unit: Unit of measurement (default: ms)
        
        Returns:
            Histogram instrument
        """
        if name not in self._histograms:
            if not self.meter:
                raise RuntimeError("Meter not initialized. Call setup() first.")

            self._histograms[name] = self.meter.create_histogram(
                name, description=description, unit=unit
            )

        return self._histograms[name]

    def increment_counter(
        self, name: str, value: int = 1, attributes: Optional[Dict[str, Any]] = None
    ):
        """
        Increment a counter metric.
        
        Args:
            name: Counter name
            value: Increment value (default: 1)
            attributes: Optional metric attributes for filtering
        
        Example:
            otel.increment_counter("voice.errors", attributes={"error_type": "timeout"})
        """
        counter = self.get_counter(name)
        counter.add(value, attributes or {})

    def record_histogram(
        self, name: str, value: float, attributes: Optional[Dict[str, Any]] = None
    ):
        """
        Record a histogram metric value.
        
        Args:
            name: Histogram name
            value: Value to record
            attributes: Optional metric attributes
        
        Example:
            otel.record_histogram("voice.latency", 125.5, {"operation": "stt"})
        """
        histogram = self.get_histogram(name)
        histogram.record(value, attributes or {})

    def record_latency(
        self, operation: str, duration_ms: float, attributes: Optional[Dict[str, Any]] = None
    ):
        """
        Record operation latency.
        
        Args:
            operation: Operation name (e.g., "stt", "tts", "brain_request")
            duration_ms: Duration in milliseconds
            attributes: Optional additional attributes
        
        Example:
            otel.record_latency("brain_reasoning", 1250.0, {"model": "gpt-4"})
        """
        attrs = {"operation": operation}
        if attributes:
            attrs.update(attributes)

        self.record_histogram(f"{self.service_name}.latency", duration_ms, attrs)

    def record_error(
        self, error_type: str, message: str, attributes: Optional[Dict[str, Any]] = None
    ):
        """
        Record an error event.
        
        Args:
            error_type: Error type (e.g., "timeout", "validation_error")
            message: Error message
            attributes: Optional additional attributes
        
        Example:
            otel.record_error("stt_timeout", "Transcription exceeded 3s limit")
        """
        attrs = {"error_type": error_type, "message": message}
        if attributes:
            attrs.update(attributes)

        self.increment_counter(f"{self.service_name}.errors", attributes=attrs)

        # Also log error with trace context
        current_span = trace.get_current_span()
        if current_span.is_recording():
            current_span.add_event(
                "error", {"error.type": error_type, "error.message": message}
            )

    def get_trace_context(self) -> Dict[str, str]:
        """
        Get current trace context for propagation.
        
        Returns:
            Dict with trace_id and span_id
        
        Example:
            context = otel.get_trace_context()
            # Pass context to downstream service
            await nats_client.publish("agent.brain.request", data, trace_id=context["trace_id"])
        """
        current_span = trace.get_current_span()
        span_context = current_span.get_span_context()

        return {
            "trace_id": format(span_context.trace_id, "032x"),
            "span_id": format(span_context.span_id, "016x"),
            "trace_flags": format(span_context.trace_flags, "02x"),
        }

    def shutdown(self):
        """
        Shutdown OpenTelemetry providers gracefully.
        
        Ensures all pending spans and metrics are exported.
        """
        if self.tracer_provider:
            self.tracer_provider.shutdown()
            logger.info(f"{self.service_name}: Tracer provider shutdown")

        if self.meter_provider:
            self.meter_provider.shutdown()
            logger.info(f"{self.service_name}: Meter provider shutdown")


# Global instance for convenience (initialized by service)
_global_otel: Optional[OTELInstrumentation] = None


def init_otel(
    service_name: str,
    service_version: str = "0.1.0",
    otel_endpoint: str = "http://localhost:4317",
    environment: str = "development",
) -> OTELInstrumentation:
    """
    Initialize global OTEL instrumentation.
    
    Args:
        service_name: Service name
        service_version: Service version
        otel_endpoint: OTEL Collector endpoint
        environment: Environment
    
    Returns:
        OTELInstrumentation instance
    
    Example:
        # In service main.py
        otel = init_otel("arc-scarlett-voice")
        
        # Use anywhere in the service
        from arc_common.observability import get_otel
        otel = get_otel()
        with otel.trace_span("my_operation"):
            # ... logic ...
    """
    global _global_otel
    _global_otel = OTELInstrumentation(
        service_name, service_version, otel_endpoint, environment
    )
    _global_otel.setup()
    return _global_otel


def get_otel() -> OTELInstrumentation:
    """
    Get global OTEL instrumentation instance.
    
    Returns:
        OTELInstrumentation instance
    
    Raises:
        RuntimeError: If OTEL not initialized
    """
    if _global_otel is None:
        raise RuntimeError(
            "OTEL not initialized. Call init_otel() first."
        )
    return _global_otel
