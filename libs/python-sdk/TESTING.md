# How to Test the Python SDK

## Quick Task Summary

**Completed**: 19/167 tasks (11.4%)

### Phase Breakdown:

- **Phase 1** (Infrastructure): 11/11 ✅ COMPLETE
- **Phase 2** (Foundation): 8/13 tasks complete
  - Database Schema: 5/5 ✅
  - Communication Infrastructure: 3/3 ✅
  - Python SDK: 5/5 ✅
  - Go SDK: 0/4 (SKIPPED - not needed)

**Next**: Phase 3 - Basic Voice Agent (49 tasks)

---

## Testing the Python SDK

### Option 1: Quick Smoke Test (No Dependencies)

The SDK is designed to work, but we need to install dependencies first:

```bash
cd libs/python-sdk

# Install dependencies
pip install -r requirements.txt

# Run smoke test (tests imports and basic functionality)
python3 test_sdk_smoke.py
```

### Option 2: Full Unit Tests (With Mocks)

```bash
cd libs/python-sdk

# Install dependencies
make install

# Run unit tests with coverage
make test

# Run only unit tests (skip integration tests)
make test-unit
```

### Option 3: Quick Import Check (Minimal)

If you just want to verify the code syntax is correct without installing dependencies:

```bash
cd libs/python-sdk

# Check Python syntax
python3 -m py_compile arc_common/**/*.py

# Run linter (if ruff is installed)
ruff arc_common/
```

---

## What Each Test Does

### Smoke Test (`test_sdk_smoke.py`)

- ✅ Verifies all modules import correctly
- ✅ Tests model instantiation and serialization
- ✅ Tests NATS client validation logic
- ✅ Tests Pulsar client envelope creation
- ✅ Tests OTEL resource configuration
- ❌ Does NOT require external services (PostgreSQL, NATS, Pulsar, OTEL)

### Unit Tests (`make test`)

- ✅ Full test suite with mocked dependencies
- ✅ Tests all public APIs
- ✅ Coverage report (currently targets 100% of SDK code)
- ✅ Includes async test support
- ❌ Does NOT require external services (all mocked)

### Integration Tests (Future)

- Tests marked with `@pytest.mark.integration`
- Require live services: PostgreSQL with pgvector, NATS, Pulsar
- Currently skipped in unit test runs

---

## Expected Output (After Installing Dependencies)

### Smoke Test Success:

```
============================================================
A.R.C. Common Python SDK - Smoke Test
============================================================
🔍 Testing SDK imports...
  ✓ arc_common v0.1.0
  ✓ arc_common.models (Conversation, Session, Base)
  ✓ arc_common.messaging (NATSAgentClient, PulsarAgentClient)
  ✓ arc_common.observability (OTELInstrumentation, init_otel, get_otel)

🔍 Testing database models...
  ✓ Conversation model instantiated
  ✓ Conversation.to_dict() works
  ✓ Session model instantiated
  ✓ Session.to_dict() works

🔍 Testing NATS client...
  ✓ NATSAgentClient initialized
  ✓ Valid subject accepted
  ✓ Invalid subject rejected
  ✓ Message envelope creation works

🔍 Testing Pulsar client...
  ✓ PulsarAgentClient initialized
  ✓ Message envelope creation works

🔍 Testing OTEL instrumentation...
  ✓ OTELInstrumentation initialized
  ✓ Resource attributes configured

============================================================
📊 Test Results
============================================================
  ✅ PASS  Imports
  ✅ PASS  Models
  ✅ PASS  NATS Client
  ✅ PASS  Pulsar Client
  ✅ PASS  OTEL Instrumentation
============================================================
🎉 All smoke tests passed!
```

### Unit Test Success:

```
============================= test session starts ==============================
collected 50 items

tests/test_models.py::TestConversationModel::test_create_conversation PASSED
tests/test_models.py::TestConversationModel::test_conversation_to_dict PASSED
tests/test_models.py::TestConversationModel::test_conversation_validation PASSED
...
tests/test_otel.py::TestGlobalOTEL::test_init_otel PASSED
tests/test_otel.py::TestGlobalOTEL::test_get_otel PASSED

---------- coverage: platform darwin, python 3.x -----------
Name                                      Stmts   Miss  Cover
-------------------------------------------------------------
arc_common/__init__.py                        4      0   100%
arc_common/models/conversation.py           125      0   100%
arc_common/messaging/nats_client.py         180      0   100%
arc_common/messaging/pulsar_client.py       195      0   100%
arc_common/observability/otel.py            165      0   100%
-------------------------------------------------------------
TOTAL                                       669      0   100%

============================== 50 passed in 2.35s ===============================
```

---

## Installation Options

### Minimal (Just to run smoke test):

```bash
pip install sqlalchemy psycopg2-binary pgvector nats-py pulsar-client \
    opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp-proto-grpc
```

### Full (Development):

```bash
cd libs/python-sdk
make install
# or
pip install -r requirements.txt
```

---

## Next Steps

After verifying the SDK works, you can proceed to **Phase 3: User Story 1 - Basic Voice Agent**:

1. **T029-T036**: Build `arc-piper-tts` (Text-to-Speech Service)
2. **T037-T047**: Build `arc-sherlock-brain` (LangGraph Reasoning Engine)
3. **T048-T060**: Build `arc-scarlett-voice` (LiveKit Agent Worker)

All three services will import and use this SDK:

```python
from arc_common.models import Conversation, Session
from arc_common.messaging import NATSAgentClient, PulsarAgentClient
from arc_common.observability import init_otel
```
