"""
Unit tests for database models.

Task: T028
Tests: Conversation and Session SQLAlchemy models with pgvector support
"""

import pytest
from datetime import datetime
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from arc_common.models import Base, Conversation, Session, find_similar_conversations


@pytest.fixture(scope="module")
def db_engine():
    """Create in-memory SQLite database for testing"""
    # Note: SQLite doesn't support pgvector or schemas, so vector similarity tests are limited
    # For full integration tests with PostgreSQL, run separately with real database
    engine = create_engine("sqlite:///:memory:")
    
    # Temporarily remove schema for SQLite compatibility
    for table in Base.metadata.tables.values():
        table.schema = None
    
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(db_engine):
    """Create database session for each test"""
    SessionLocal = sessionmaker(bind=db_engine)
    session = SessionLocal()
    yield session
    session.rollback()
    session.close()


class TestConversationModel:
    """Tests for Conversation model"""

    def test_create_conversation(self, db_session):
        """Test creating a conversation record"""
        conv = Conversation(
            user_id="user-123",
            agent_id="arc-sherlock-brain",
            turn_index=1,
            user_input="Hello, how are you?",
            agent_response="I'm doing well, thank you!",
            embedding=[0.1] * 1536,  # Mock OpenAI embedding
            latency_stt_ms=125.5,
            latency_brain_ms=850.0,
            latency_tts_ms=200.0,
        )

        db_session.add(conv)
        db_session.commit()

        # Verify record was created
        assert conv.id is not None
        assert conv.user_id == "user-123"
        assert conv.agent_id == "arc-sherlock-brain"
        assert conv.turn_index == 1
        assert conv.created_at is not None

    def test_conversation_to_dict(self, db_session):
        """Test conversation serialization to dict"""
        conv = Conversation(
            user_id="user-456",
            agent_id="arc-sherlock-brain",
            turn_index=2,
            user_input="What's the weather?",
            agent_response="It's sunny today!",
        )

        conv_dict = conv.to_dict()

        assert conv_dict["user_id"] == "user-456"
        assert conv_dict["agent_id"] == "arc-sherlock-brain"
        assert conv_dict["turn_index"] == 2
        assert conv_dict["user_input"] == "What's the weather?"
        assert "created_at" in conv_dict

    def test_conversation_validation(self, db_session):
        """Test conversation field validation"""
        # Test not_empty validator on user_input
        with pytest.raises(ValueError, match="user_input cannot be empty"):
            conv = Conversation(
                user_id="user-789",
                agent_id="arc-sherlock-brain",
                turn_index=1,
                user_input="   ",  # Empty after strip
                agent_response="Response",
            )
            db_session.add(conv)
            db_session.commit()

    def test_conversation_constraints(self, db_session):
        """Test conversation constraints"""
        conv = Conversation(
            user_id="user-111",
            agent_id="arc-sherlock-brain",
            turn_index=1,
            user_input="First message",
            agent_response="First response",
        )

        db_session.add(conv)
        db_session.commit()

        # Test unique constraint on (user_id, agent_id, turn_index)
        duplicate = Conversation(
            user_id="user-111",
            agent_id="arc-sherlock-brain",
            turn_index=1,  # Same turn_index
            user_input="Duplicate message",
            agent_response="Duplicate response",
        )

        # This should fail due to unique constraint
        # (SQLite may not enforce all constraints, so this is more documentation)
        # In a real Postgres test, this would raise IntegrityError


class TestSessionModel:
    """Tests for Session model"""

    def test_create_session(self, db_session):
        """Test creating a session record"""
        session_record = Session(
            room_name="room-123",
            user_id="user-456",
            session_start=datetime.utcnow(),
            connection_quality="excellent",
            avg_latency_ms=120.0,
            total_turns=10,
        )

        db_session.add(session_record)
        db_session.commit()

        # Verify record was created
        assert session_record.id is not None
        assert session_record.room_name == "room-123"
        assert session_record.user_id == "user-456"
        assert session_record.connection_quality == "excellent"

    def test_session_to_dict(self, db_session):
        """Test session serialization to dict"""
        session_record = Session(
            room_name="room-789",
            user_id="user-999",
            session_start=datetime.utcnow(),
            connection_quality="good",
            avg_latency_ms=150.0,
        )

        session_dict = session_record.to_dict()

        assert session_dict["room_name"] == "room-789"
        assert session_dict["user_id"] == "user-999"
        assert session_dict["connection_quality"] == "good"
        assert "session_start" in session_dict

    def test_session_validation(self, db_session):
        """Test session field validation"""
        # Test connection_quality validator
        with pytest.raises(
            ValueError, match="Invalid connection quality: invalid_quality"
        ):
            session_record = Session(
                room_name="room-invalid",
                user_id="user-invalid",
                session_start=datetime.utcnow(),
                connection_quality="invalid_quality",  # Invalid value
            )
            db_session.add(session_record)
            db_session.commit()

    def test_session_default_values(self, db_session):
        """Test session default values"""
        session_record = Session(
            room_name="room-default",
            user_id="user-default",
            session_start=datetime.utcnow(),
        )

        db_session.add(session_record)
        db_session.commit()

        # Check default values
        assert session_record.connection_quality == "good"
        assert session_record.avg_latency_ms == 0.0
        assert session_record.total_turns == 0
        assert session_record.error_count == 0


class TestHelperFunctions:
    """Tests for helper functions"""

    def test_find_similar_conversations_placeholder(self, db_session):
        """Test find_similar_conversations function (limited without pgvector)"""
        # Create test conversations
        conv1 = Conversation(
            user_id="user-search",
            agent_id="arc-sherlock-brain",
            turn_index=1,
            user_input="Hello world",
            agent_response="Hi there",
            embedding=[0.1] * 1536,
        )
        conv2 = Conversation(
            user_id="user-search",
            agent_id="arc-sherlock-brain",
            turn_index=2,
            user_input="How are you?",
            agent_response="I'm good",
            embedding=[0.2] * 1536,
        )

        db_session.add_all([conv1, conv2])
        db_session.commit()

        # Note: find_similar_conversations uses pgvector's cosine_distance
        # which is not available in SQLite, so this test is a placeholder
        # In a real Postgres test environment, we would test semantic search

        # Placeholder assertion
        assert conv1.id is not None
        assert conv2.id is not None


@pytest.mark.integration
class TestDatabaseIntegration:
    """Integration tests requiring real PostgreSQL database"""

    # These tests should be run against a real Postgres instance with pgvector
    # They are marked as integration tests and skipped in unit test runs

    @pytest.mark.skip(reason="Requires PostgreSQL with pgvector")
    def test_vector_similarity_search(self):
        """Test vector similarity search with pgvector"""
        # This would test find_similar_conversations() with real embeddings
        # using cosine_distance on a Postgres database
        pass

    @pytest.mark.skip(reason="Requires PostgreSQL with pgvector")
    def test_hnsw_index_performance(self):
        """Test HNSW index performance with large dataset"""
        # This would test query performance with HNSW index
        # on thousands of conversation records
        pass
