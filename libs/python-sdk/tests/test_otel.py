"""
Unit tests for OpenTelemetry instrumentation helpers.

Task: T028
Tests: OTELInstrumentation tracing and metrics functionality
"""

import pytest
from unittest.mock import MagicMock, patch

from arc_common.observability import OTELInstrumentation, init_otel, get_otel


@pytest.fixture
def otel():
    """Create OTEL instrumentation for testing"""
    return OTELInstrumentation(
        service_name="test-service",
        service_version="0.1.0",
        otel_endpoint="http://localhost:4317",
        environment="test",
    )


class TestOTELInstrumentation:
    """Tests for OTELInstrumentation"""

    def test_initialization(self, otel):
        """Test OTEL initialization"""
        assert otel.service_name == "test-service"
        assert otel.service_version == "0.1.0"
        assert otel.otel_endpoint == "http://localhost:4317"
        assert otel.environment == "test"
        assert otel.tracer_provider is None
        assert otel.meter_provider is None

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_setup(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test OTEL setup"""
        otel.setup()

        # Verify tracer and meter were initialized
        assert otel.tracer is not None
        assert otel.meter is not None
        assert otel.tracer_provider is not None
        assert otel.meter_provider is not None

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_trace_span_success(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test tracing span with successful operation"""
        otel.setup()

        # Mock tracer
        mock_span = MagicMock()
        mock_span.is_recording.return_value = True
        otel.tracer = MagicMock()
        otel.tracer.start_as_current_span.return_value.__enter__ = lambda self: mock_span
        otel.tracer.start_as_current_span.return_value.__exit__ = lambda self, *args: None

        # Use trace_span
        with otel.trace_span("test_operation", {"key": "value"}) as span:
            assert span == mock_span
            span.set_attribute.assert_called_once_with("key", "value")

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_trace_span_error(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test tracing span with exception"""
        otel.setup()

        # Mock tracer
        mock_span = MagicMock()
        otel.tracer = MagicMock()
        otel.tracer.start_as_current_span.return_value.__enter__ = lambda self: mock_span

        def exit_handler(*args):
            return False

        otel.tracer.start_as_current_span.return_value.__exit__ = exit_handler

        # Use trace_span with exception
        with pytest.raises(ValueError):
            with otel.trace_span("failing_operation") as span:
                raise ValueError("Test error")

        # Verify span recorded exception
        mock_span.record_exception.assert_called_once()

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_get_counter(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test getting or creating counter metric"""
        otel.setup()

        # Mock meter
        mock_counter = MagicMock()
        otel.meter.create_counter = MagicMock(return_value=mock_counter)

        # Get counter
        counter = otel.get_counter("test.counter", "Test counter")

        assert counter == mock_counter
        otel.meter.create_counter.assert_called_once_with(
            "test.counter", description="Test counter"
        )

        # Get same counter again (should be cached)
        counter2 = otel.get_counter("test.counter")
        assert counter2 == mock_counter
        assert otel.meter.create_counter.call_count == 1  # Not called again

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_get_histogram(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test getting or creating histogram metric"""
        otel.setup()

        # Mock meter
        mock_histogram = MagicMock()
        otel.meter.create_histogram = MagicMock(return_value=mock_histogram)

        # Get histogram
        histogram = otel.get_histogram("test.histogram", "Test histogram", unit="ms")

        assert histogram == mock_histogram
        otel.meter.create_histogram.assert_called_once_with(
            "test.histogram", description="Test histogram", unit="ms"
        )

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_increment_counter(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test incrementing counter"""
        otel.setup()

        # Mock meter and counter
        mock_counter = MagicMock()
        otel.meter.create_counter = MagicMock(return_value=mock_counter)

        # Increment counter
        otel.increment_counter("test.counter", value=5, attributes={"key": "value"})

        mock_counter.add.assert_called_once_with(5, {"key": "value"})

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_record_histogram(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test recording histogram value"""
        otel.setup()

        # Mock meter and histogram
        mock_histogram = MagicMock()
        otel.meter.create_histogram = MagicMock(return_value=mock_histogram)

        # Record histogram
        otel.record_histogram("test.histogram", 125.5, attributes={"op": "test"})

        mock_histogram.record.assert_called_once_with(125.5, {"op": "test"})

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_record_latency(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test recording latency metric"""
        otel.setup()

        # Mock meter and histogram
        mock_histogram = MagicMock()
        otel.meter.create_histogram = MagicMock(return_value=mock_histogram)

        # Record latency
        otel.record_latency("stt_processing", 250.0, attributes={"model": "whisper"})

        # Verify histogram was recorded with correct attributes
        mock_histogram.record.assert_called_once()
        call_args = mock_histogram.record.call_args[0]
        call_kwargs = mock_histogram.record.call_args[1]
        assert call_args[0] == 250.0
        assert call_kwargs[0]["operation"] == "stt_processing"
        assert call_kwargs[0]["model"] == "whisper"

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_record_error(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp, otel
    ):
        """Test recording error event"""
        otel.setup()

        # Mock meter and counter
        mock_counter = MagicMock()
        otel.meter.create_counter = MagicMock(return_value=mock_counter)

        # Record error
        otel.record_error("timeout", "STT exceeded limit", attributes={"retry": 3})

        # Verify counter was incremented
        mock_counter.add.assert_called_once()
        call_args = mock_counter.add.call_args[0]
        call_kwargs = mock_counter.add.call_args[1]
        assert call_kwargs[0]["error_type"] == "timeout"


class TestGlobalOTEL:
    """Tests for global OTEL initialization"""

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_init_otel(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp
    ):
        """Test global OTEL initialization"""
        otel = init_otel("test-service", service_version="1.0.0")

        assert otel.service_name == "test-service"
        assert otel.service_version == "1.0.0"

    @patch("arc_common.observability.otel.OTLPSpanExporter")
    @patch("arc_common.observability.otel.OTLPMetricExporter")
    @patch("arc_common.observability.otel.trace.set_tracer_provider")
    @patch("arc_common.observability.otel.metrics.set_meter_provider")
    def test_get_otel(
        self, mock_set_meter, mock_set_tracer, mock_metric_exp, mock_span_exp
    ):
        """Test getting global OTEL instance"""
        otel = init_otel("test-service-2")
        otel_retrieved = get_otel()

        assert otel_retrieved == otel
        assert otel_retrieved.service_name == "test-service-2"

    def test_get_otel_not_initialized(self):
        """Test getting OTEL when not initialized raises error"""
        # Reset global instance
        import arc_common.observability.otel as otel_module

        otel_module._global_otel = None

        with pytest.raises(RuntimeError, match="OTEL not initialized"):
            get_otel()
