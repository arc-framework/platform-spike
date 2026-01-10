"""
SQLAlchemy database models for A.R.C. agent services.

Models:
- Conversation: Voice agent conversation history with pgvector embeddings
- Session: LiveKit session tracking and analytics
"""

from datetime import datetime
from typing import Optional
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    CheckConstraint,
    Column,
    DateTime,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import validates
from pgvector.sqlalchemy import Vector

Base = declarative_base()


class Conversation(Base):
    """
    Voice agent conversation history with semantic search support.
    
    Table: agents.conversations
    Purpose: Store user-agent conversation turns with embeddings for context retrieval
    """

    __tablename__ = "conversations"
    __table_args__ = {"schema": "agents"}

    # Primary key
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)

    # Participant information
    user_id = Column(String(255), nullable=False, index=True)
    agent_id = Column(String(255), nullable=False, default="arc-scarlett-voice")
    room_name = Column(String(255), index=True)
    session_id = Column(String(255), index=True)

    # Conversation data
    turn_index = Column(Integer, nullable=False, default=0)
    user_input = Column(Text, nullable=False)
    agent_response = Column(Text, nullable=False)

    # Semantic search - pgvector embedding (1536 dimensions for OpenAI ada-002)
    # Adjust dimension based on your embedding model
    embedding = Column(Vector(1536))

    # Metadata
    context_used = Column(JSON)  # Previous turns used for context
    llm_model = Column(String(100))
    llm_tokens_used = Column(Integer)
    stt_model = Column(String(100))
    tts_model = Column(String(100))

    # Performance metrics (milliseconds)
    stt_latency_ms = Column(Integer)
    llm_latency_ms = Column(Integer)
    tts_latency_ms = Column(Integer)
    total_latency_ms = Column(Integer)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Constraints
    __table_args__ = (
        CheckConstraint("turn_index >= 0", name="conversations_turn_index_check"),
        CheckConstraint(
            "stt_latency_ms >= 0 AND llm_latency_ms >= 0 "
            "AND tts_latency_ms >= 0 AND total_latency_ms >= 0",
            name="conversations_latency_check",
        ),
        {"schema": "agents"},
    )

    @validates("user_id", "agent_id")
    def validate_not_empty(self, key, value):
        if not value or not value.strip():
            raise ValueError(f"{key} cannot be empty")
        return value

    def __repr__(self):
        return (
            f"<Conversation(id={self.id}, user_id={self.user_id}, "
            f"turn_index={self.turn_index}, created_at={self.created_at})>"
        )

    def to_dict(self):
        """Convert model to dictionary for JSON serialization"""
        return {
            "id": str(self.id),
            "user_id": self.user_id,
            "agent_id": self.agent_id,
            "room_name": self.room_name,
            "session_id": self.session_id,
            "turn_index": self.turn_index,
            "user_input": self.user_input,
            "agent_response": self.agent_response,
            "llm_model": self.llm_model,
            "llm_tokens_used": self.llm_tokens_used,
            "stt_model": self.stt_model,
            "tts_model": self.tts_model,
            "stt_latency_ms": self.stt_latency_ms,
            "llm_latency_ms": self.llm_latency_ms,
            "tts_latency_ms": self.tts_latency_ms,
            "total_latency_ms": self.total_latency_ms,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


class Session(Base):
    """
    LiveKit voice agent session tracking and analytics.
    
    Table: agents.sessions
    Purpose: Track LiveKit room sessions with performance metrics
    """

    __tablename__ = "sessions"
    __table_args__ = {"schema": "agents"}

    # Primary key
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)

    # LiveKit session information
    room_name = Column(String(255), nullable=False, index=True)
    room_sid = Column(String(255))  # LiveKit room SID
    participant_sid = Column(String(255))  # LiveKit participant SID

    # User information
    user_id = Column(String(255), nullable=False, index=True)
    user_identity = Column(String(255))  # LiveKit identity
    agent_id = Column(String(255), nullable=False, default="arc-scarlett-voice")

    # Session metadata
    session_start = Column(DateTime(timezone=True), server_default=func.now())
    session_end = Column(DateTime(timezone=True))
    duration_seconds = Column(Integer)

    # Conversation statistics
    total_turns = Column(Integer, default=0)
    total_user_messages = Column(Integer, default=0)
    total_agent_messages = Column(Integer, default=0)

    # Performance aggregates (milliseconds)
    avg_latency_ms = Column(Integer)
    p95_latency_ms = Column(Integer)
    p99_latency_ms = Column(Integer)

    # Connection quality
    avg_packet_loss_percent = Column(Numeric(5, 2))
    avg_jitter_ms = Column(Integer)
    connection_quality = Column(
        String(20)
    )  # 'excellent', 'good', 'fair', 'poor'

    # Session state
    status = Column(
        String(50), default="active"
    )  # 'active', 'ended', 'error'
    error_message = Column(Text)

    # Recording information (for future arc-scribe-egress)
    recording_id = Column(PGUUID(as_uuid=True))
    recording_url = Column(Text)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Constraints
    __table_args__ = (
        CheckConstraint(
            "duration_seconds IS NULL OR duration_seconds >= 0",
            name="sessions_duration_check",
        ),
        CheckConstraint(
            "status IN ('active', 'ended', 'error')",
            name="sessions_status_check",
        ),
        {"schema": "agents"},
    )

    @validates("status")
    def validate_status(self, key, value):
        allowed_statuses = {"active", "ended", "error"}
        if value not in allowed_statuses:
            raise ValueError(
                f"Invalid status: {value}. Must be one of {allowed_statuses}"
            )
        return value

    @validates("connection_quality")
    def validate_connection_quality(self, key, value):
        if value is not None:
            allowed_qualities = {"excellent", "good", "fair", "poor"}
            if value not in allowed_qualities:
                raise ValueError(
                    f"Invalid connection_quality: {value}. "
                    f"Must be one of {allowed_qualities}"
                )
        return value

    def __repr__(self):
        return (
            f"<Session(id={self.id}, user_id={self.user_id}, "
            f"room_name={self.room_name}, status={self.status})>"
        )

    def to_dict(self):
        """Convert model to dictionary for JSON serialization"""
        return {
            "id": str(self.id),
            "room_name": self.room_name,
            "room_sid": self.room_sid,
            "participant_sid": self.participant_sid,
            "user_id": self.user_id,
            "user_identity": self.user_identity,
            "agent_id": self.agent_id,
            "session_start": (
                self.session_start.isoformat() if self.session_start else None
            ),
            "session_end": self.session_end.isoformat() if self.session_end else None,
            "duration_seconds": self.duration_seconds,
            "total_turns": self.total_turns,
            "total_user_messages": self.total_user_messages,
            "total_agent_messages": self.total_agent_messages,
            "avg_latency_ms": self.avg_latency_ms,
            "p95_latency_ms": self.p95_latency_ms,
            "p99_latency_ms": self.p99_latency_ms,
            "avg_packet_loss_percent": (
                float(self.avg_packet_loss_percent)
                if self.avg_packet_loss_percent
                else None
            ),
            "avg_jitter_ms": self.avg_jitter_ms,
            "connection_quality": self.connection_quality,
            "status": self.status,
            "error_message": self.error_message,
            "recording_id": str(self.recording_id) if self.recording_id else None,
            "recording_url": self.recording_url,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


# Helper function for semantic search
def find_similar_conversations(session, query_embedding, limit=5, user_id=None):
    """
    Find similar conversations using pgvector cosine similarity.
    
    Args:
        session: SQLAlchemy session
        query_embedding: List or numpy array of embedding values (1536 dimensions)
        limit: Number of similar conversations to return
        user_id: Optional user_id to filter by
    
    Returns:
        List of Conversation objects ordered by similarity
    
    Example:
        similar = find_similar_conversations(
            db_session,
            query_embedding=[0.1, 0.2, ...],  # 1536 values
            limit=5,
            user_id="user-123"
        )
    """
    query = session.query(Conversation)

    if user_id:
        query = query.filter(Conversation.user_id == user_id)

    # Order by cosine distance (lower is more similar)
    # pgvector provides <-> operator for cosine distance
    query = query.order_by(Conversation.embedding.cosine_distance(query_embedding))

    return query.limit(limit).all()
