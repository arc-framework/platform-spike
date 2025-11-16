
import os
import logging
import time
from fastapi import Request

from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.metrics import MeterProvider

# The conflicting exporter and instrumentor libraries have been removed.
# This file now only sets up the basic OTel SDK.
# The next step is to implement a custom exporter that sends telemetry data to Pulsar.

def setup_tracing(app):
    """
    Sets up the OpenTelemetry SDK for tracing and metrics.
    This service will produce telemetry data, but will not directly export it.
    Instead, it should be configured to send telemetry data to a Pulsar topic,
    from which a dedicated telemetry service will consume and export it.
    """
    service_name = os.getenv("OTEL_SERVICE_NAME", "voice-agent")

    # --- SDK SETUP (No Exporter) ---
    # A TracerProvider is still needed to create and manage spans.
    tracer_provider = TracerProvider()
    trace.set_tracer_provider(tracer_provider)

    # A MeterProvider is still needed to create and manage metrics.
    meter_provider = MeterProvider()
    metrics.set_meter_provider(meter_provider)

    # --- TODO: IMPLEMENT PULSAR EXPORTER ---
    # Here, you would initialize a Pulsar client and create a custom SpanExporter
    # and MetricExporter that serialize the telemetry data and send it to a
    # Pulsar topic (e.g., "telemetry-spans", "telemetry-metrics").
    #
    # Example (conceptual):
    # pulsar_client = pulsar.Client(...)
    # span_producer = pulsar_client.create_producer("telemetry-spans")
    # custom_span_exporter = PulsarSpanExporter(span_producer)
    # tracer_provider.add_span_processor(BatchSpanProcessor(custom_span_exporter))

    # --- LOGGING SETUP ---
    # Standard logging is unaffected and can be used as is.
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        start_time = time.time()
        response = await call_next(request)
        duration = time.time() - start_time
        logger.info(
            f"Request: {request.method} {request.url.path} - Response: {response.status_code} - Duration: {duration:.4f}s"
        )
        return response

    # FastAPIInstrumentor has been removed as it was tied to the old exporter setup.
    # You can still manually create spans within your endpoints using `tracer.start_as_current_span(...)`.
