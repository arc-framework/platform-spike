"""
A.R.C. Platform - Python Common SDK

Shared libraries for Python agent services (arc-scarlett-voice, arc-sherlock-brain, arc-piper-tts).

Modules:
- models: SQLAlchemy database models
- messaging: NATS and Pulsar client wrappers
- observability: OpenTelemetry instrumentation helpers
"""

__version__ = "0.1.0"

# Export main modules
from . import messaging, models, observability

__all__ = ["models", "messaging", "observability", "__version__"]
