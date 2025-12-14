"""
arc-sherlock-brain Observability Module
OpenTelemetry instrumentation for traces, metrics, and logs
"""

import os
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, SERVICE_VERSION
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
import structlog

logger = structlog.get_logger()

# ==============================================================================
# OpenTelemetry Configuration
# ==============================================================================

def init_telemetry():
    """
    Initialize OpenTelemetry SDK with OTLP exporters.

    Environment Variables:
        OTEL_EXPORTER_OTLP_ENDPOINT: OTLP collector endpoint (default: http://arc-widow-otel:4317)
        OTEL_SERVICE_NAME: Service name (default: arc-sherlock-brain)
        OTEL_TRACES_ENABLED: Enable trace export (default: true)
        OTEL_METRICS_ENABLED: Enable metric export (default: true)
    """
    service_name = os.getenv("OTEL_SERVICE_NAME", "arc-sherlock-brain")
    service_version = os.getenv("OTEL_SERVICE_VERSION", "0.1.0")
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://arc-widow-otel:4317")

    # Create resource
    resource = Resource(attributes={
        SERVICE_NAME: service_name,
        SERVICE_VERSION: service_version,
        "arc.service.tier": "services",
        "arc.service.category": "reasoning",
    })

    # Initialize Tracer Provider
    traces_enabled = os.getenv("OTEL_TRACES_ENABLED", "true").lower() == "true"
    if traces_enabled:
        trace_provider = TracerProvider(resource=resource)
        trace_exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
        trace_provider.add_span_processor(BatchSpanProcessor(trace_exporter))
        trace.set_tracer_provider(trace_provider)
        logger.info("otel.traces_initialized", endpoint=otlp_endpoint)

    # Initialize Meter Provider
    metrics_enabled = os.getenv("OTEL_METRICS_ENABLED", "true").lower() == "true"
    if metrics_enabled:
        metric_exporter = OTLPMetricExporter(endpoint=otlp_endpoint, insecure=True)
        metric_reader = PeriodicExportingMetricReader(metric_exporter, export_interval_millis=60000)
        meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
        metrics.set_meter_provider(meter_provider)
        logger.info("otel.metrics_initialized", endpoint=otlp_endpoint)

    logger.info(
        "otel.initialized",
        service=service_name,
        version=service_version,
        traces=traces_enabled,
        metrics=metrics_enabled
    )


def instrument_fastapi(app):
    """
    Instrument FastAPI application with automatic tracing.

    Args:
        app: FastAPI application instance
    """
    FastAPIInstrumentor.instrument_app(app)
    logger.info("otel.fastapi_instrumented")


def instrument_sqlalchemy(engine):
    """
    Instrument SQLAlchemy engine with automatic query tracing.

    Args:
        engine: SQLAlchemy engine instance
    """
    SQLAlchemyInstrumentor().instrument(engine=engine)
    logger.info("otel.sqlalchemy_instrumented")


# ==============================================================================
# Custom Span Helpers
# ==============================================================================

def get_tracer():
    """Get tracer for manual instrumentation."""
    return trace.get_tracer(__name__)


def get_meter():
    """Get meter for custom metrics."""
    return metrics.get_meter(__name__)


# ==============================================================================
# Custom Metrics
# ==============================================================================

class BrainMetrics:
    """
    Custom metrics for arc-sherlock-brain.
    """

    def __init__(self):
        meter = get_meter()

        # Counters
        self.request_counter = meter.create_counter(
            name="brain.requests.total",
            description="Total number of brain requests",
            unit="1"
        )

        self.error_counter = meter.create_counter(
            name="brain.errors.total",
            description="Total number of errors",
            unit="1"
        )

        # Histograms
        self.latency_histogram = meter.create_histogram(
            name="brain.latency",
            description="Brain request latency distribution",
            unit="ms"
        )

        self.context_size_histogram = meter.create_histogram(
            name="brain.context.size",
            description="Number of context items retrieved",
            unit="1"
        )

        logger.info("otel.custom_metrics_initialized")

    def record_request(self, user_id: str):
        """Record a brain request."""
        self.request_counter.add(1, {"user_id": user_id})

    def record_error(self, error_type: str):
        """Record an error."""
        self.error_counter.add(1, {"error_type": error_type})

    def record_latency(self, latency_ms: int, user_id: str):
        """Record request latency."""
        self.latency_histogram.record(latency_ms, {"user_id": user_id})

    def record_context_size(self, size: int, user_id: str):
        """Record context retrieval size."""
        self.context_size_histogram.record(size, {"user_id": user_id})


# ==============================================================================
# Structured Logging Integration
# ==============================================================================

def configure_logging():
    """
    Configure structlog with trace context propagation.
    """
    import structlog

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    logger.info("logging.configured", format="json")
