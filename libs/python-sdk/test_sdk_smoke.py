#!/usr/bin/env python3
"""
Quick smoke test for A.R.C. Common Python SDK

This script verifies that all SDK modules can be imported and basic
functionality works without external dependencies.

Usage:
    python test_sdk_smoke.py
"""

import sys
from datetime import datetime


def test_imports():
    """Test that all SDK modules can be imported"""
    print("🔍 Testing SDK imports...")
    
    try:
        import arc_common
        print(f"  ✓ arc_common v{arc_common.__version__}")
        
        from arc_common.models import Conversation, Session, Base
        print("  ✓ arc_common.models (Conversation, Session, Base)")
        
        from arc_common.messaging import NATSAgentClient, PulsarAgentClient
        print("  ✓ arc_common.messaging (NATSAgentClient, PulsarAgentClient)")
        
        from arc_common.observability import OTELInstrumentation, init_otel, get_otel
        print("  ✓ arc_common.observability (OTELInstrumentation, init_otel, get_otel)")
        
        return True
    except ImportError as e:
        print(f"  ✗ Import failed: {e}")
        return False


def test_models():
    """Test basic model instantiation (without database)"""
    print("\n🔍 Testing database models...")
    
    try:
        from arc_common.models import Conversation, Session
        
        # Create conversation instance (not persisted)
        conv = Conversation(
            user_id="test-user",
            agent_id="arc-sherlock-brain",
            turn_index=1,
            user_input="Hello, world!",
            agent_response="Hi there!",
            stt_latency_ms=100,
            llm_latency_ms=500,
            tts_latency_ms=150,
        )
        print(f"  ✓ Conversation model instantiated")
        
        # Test to_dict()
        conv_dict = conv.to_dict()
        assert conv_dict["user_id"] == "test-user"
        assert conv_dict["turn_index"] == 1
        print(f"  ✓ Conversation.to_dict() works")
        
        # Create session instance
        session = Session(
            room_name="test-room",
            user_id="test-user",
            session_start=datetime.utcnow(),
            connection_quality="excellent",
            avg_latency_ms=200.0,
            total_turns=5,
        )
        print(f"  ✓ Session model instantiated")
        
        # Test to_dict()
        session_dict = session.to_dict()
        assert session_dict["room_name"] == "test-room"
        assert session_dict["connection_quality"] == "excellent"
        print(f"  ✓ Session.to_dict() works")
        
        return True
    except Exception as e:
        print(f"  ✗ Model test failed: {e}")
        return False


def test_nats_client():
    """Test NATS client initialization (without connection)"""
    print("\n🔍 Testing NATS client...")
    
    try:
        from arc_common.messaging import NATSAgentClient
        
        # Initialize client (don't connect)
        client = NATSAgentClient(
            servers="nats://localhost:4222",
            service_name="test-service"
        )
        print(f"  ✓ NATSAgentClient initialized")
        
        # Test subject validation
        try:
            client._validate_subject("agent.voice.track.published")
            print(f"  ✓ Valid subject accepted")
        except ValueError:
            print(f"  ✗ Valid subject rejected")
            return False
        
        # Test invalid subject
        try:
            client._validate_subject("invalid.subject")
            print(f"  ✗ Invalid subject accepted (should fail)")
            return False
        except ValueError:
            print(f"  ✓ Invalid subject rejected")
        
        # Test message envelope creation
        envelope = client._create_message_envelope(
            data={"test": "data"},
            trace_id="test-trace-123",
            event_type="test_event"
        )
        assert envelope["trace_id"] == "test-trace-123"
        assert envelope["service"] == "test-service"
        assert envelope["test"] == "data"
        print(f"  ✓ Message envelope creation works")
        
        return True
    except Exception as e:
        print(f"  ✗ NATS client test failed: {e}")
        return False


def test_pulsar_client():
    """Test Pulsar client initialization (without connection)"""
    print("\n🔍 Testing Pulsar client...")
    
    try:
        from arc_common.messaging import PulsarAgentClient
        
        # Initialize client (don't connect)
        client = PulsarAgentClient(
            service_url="pulsar://localhost:6650",
            service_name="test-service"
        )
        print(f"  ✓ PulsarAgentClient initialized")
        
        # Test message envelope creation
        envelope = client._create_message_envelope(
            data={"conversation_id": "conv-123"},
            trace_id="test-trace-456",
            event_type="turn_completed"
        )
        assert envelope["trace_id"] == "test-trace-456"
        assert envelope["service"] == "test-service"
        assert envelope["event_type"] == "turn_completed"
        print(f"  ✓ Message envelope creation works")
        
        return True
    except Exception as e:
        print(f"  ✗ Pulsar client test failed: {e}")
        return False


def test_otel():
    """Test OTEL instrumentation initialization (without connection)"""
    print("\n🔍 Testing OTEL instrumentation...")
    
    try:
        from arc_common.observability import OTELInstrumentation
        
        # Initialize instrumentation (don't setup)
        otel = OTELInstrumentation(
            service_name="test-service",
            service_version="1.0.0",
            otel_endpoint="http://localhost:4317",
            environment="test"
        )
        print(f"  ✓ OTELInstrumentation initialized")
        
        # Verify resource attributes
        assert otel.resource.attributes["service.name"] == "test-service"
        assert otel.resource.attributes["service.version"] == "1.0.0"
        assert otel.resource.attributes["deployment.environment"] == "test"
        print(f"  ✓ Resource attributes configured")
        
        return True
    except Exception as e:
        print(f"  ✗ OTEL test failed: {e}")
        return False


def main():
    """Run all smoke tests"""
    print("=" * 60)
    print("A.R.C. Common Python SDK - Smoke Test")
    print("=" * 60)
    
    results = {
        "Imports": test_imports(),
        "Models": test_models(),
        "NATS Client": test_nats_client(),
        "Pulsar Client": test_pulsar_client(),
        "OTEL Instrumentation": test_otel(),
    }
    
    print("\n" + "=" * 60)
    print("📊 Test Results")
    print("=" * 60)
    
    for test_name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {status}  {test_name}")
    
    all_passed = all(results.values())
    
    print("=" * 60)
    if all_passed:
        print("🎉 All smoke tests passed!")
        print("\nℹ️  Note: These are basic tests without external dependencies.")
        print("   To run full unit tests with mocks: make test")
        print("   To run integration tests: make test-integration (requires services)")
        return 0
    else:
        print("❌ Some smoke tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
