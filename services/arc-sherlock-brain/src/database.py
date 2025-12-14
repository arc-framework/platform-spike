"""
arc-sherlock-brain Database Module
PostgreSQL with pgvector for semantic memory and conversation persistence.
"""

import asyncio
import os
from typing import List, Tuple, Optional
from contextlib import asynccontextmanager

from sqlalchemy import Column, Integer, String, Text, DateTime, select, func
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy.dialects.postgresql import ARRAY
from pgvector.sqlalchemy import Vector
from sentence_transformers import SentenceTransformer
import structlog

logger = structlog.get_logger()

Base = declarative_base()

# ==============================================================================
# Database Models
# ==============================================================================

class Conversation(Base):
    """
    Conversation history with vector embeddings for semantic search.
    """
    __tablename__ = "conversations"
    __table_args__ = {"schema": "agents"}

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(255), nullable=False, index=True)
    text = Column(Text, nullable=False)
    embedding = Column(Vector(384), nullable=False)  # all-MiniLM-L6-v2 dimension
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self):
        return f"<Conversation(id={self.id}, user_id='{self.user_id}', text='{self.text[:50]}...')>"


# ==============================================================================
# Database Connection Management
# ==============================================================================

class Database:
    """
    Async database connection manager with session lifecycle.
    """

    def __init__(self, database_url: Optional[str] = None):
        """
        Initialize database connection.

        Args:
            database_url: PostgreSQL connection string (async format).
                         Defaults to POSTGRES_URL environment variable.
        """
        self.database_url = database_url or os.getenv(
            "POSTGRES_URL",
            "postgresql+asyncpg://arc:arcsecret@arc-oracle-sql:5432/arc"
        )
        self.engine = create_async_engine(
            self.database_url,
            echo=False,  # Set to True for SQL query logging
            pool_size=10,
            max_overflow=20,
            pool_pre_ping=True,  # Verify connections before use
        )
        self.async_session = async_sessionmaker(
            self.engine,
            class_=AsyncSession,
            expire_on_commit=False,
        )
        # Initialize embedding model (lightweight, CPU-friendly)
        self.embedding_model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
        logger.info("database.initialized", url=self.database_url)

    async def init_tables(self):
        """
        Create tables if they don't exist.
        Requires pgvector extension to be installed in PostgreSQL.
        """
        async with self.engine.begin() as conn:
            # Ensure schema exists
            await conn.execute(text("CREATE SCHEMA IF NOT EXISTS agents"))
            # Create tables
            await conn.run_sync(Base.metadata.create_all)
        logger.info("database.tables_initialized")

    @asynccontextmanager
    async def session(self):
        """
        Async context manager for database sessions.

        Usage:
            async with db.session() as session:
                result = await session.execute(select(Conversation))
        """
        async with self.async_session() as session:
            try:
                yield session
                await session.commit()
            except Exception as e:
                await session.rollback()
                logger.error("database.session_error", error=str(e))
                raise

    async def close(self):
        """Close database connection pool."""
        await self.engine.dispose()
        logger.info("database.closed")


# ==============================================================================
# Database Operations
# ==============================================================================

async def save_conversation(
    db: Database,
    user_id: str,
    text: str
) -> int:
    """
    Save conversation turn with vector embedding for semantic retrieval.

    Args:
        db: Database instance
        user_id: User identifier
        text: Conversation text (user input or agent response)

    Returns:
        Inserted conversation ID

    Example:
        conversation_id = await save_conversation(db, "user123", "Hello, how are you?")
    """
    # Generate embedding
    embedding = db.embedding_model.encode(text).tolist()

    async with db.session() as session:
        conversation = Conversation(
            user_id=user_id,
            text=text,
            embedding=embedding
        )
        session.add(conversation)
        await session.flush()  # Get ID before commit
        conversation_id = conversation.id
        logger.info(
            "database.conversation_saved",
            conversation_id=conversation_id,
            user_id=user_id,
            text_length=len(text)
        )
        return conversation_id


async def get_context(
    db: Database,
    user_id: str,
    query_text: str,
    top_k: int = 5
) -> List[Tuple[int, str, float]]:
    """
    Retrieve relevant conversation history using pgvector similarity search.

    Args:
        db: Database instance
        user_id: User identifier (filters results to this user)
        query_text: Query text for semantic search
        top_k: Number of top results to return

    Returns:
        List of (conversation_id, text, similarity_distance) tuples
        Ordered by similarity (lower distance = more similar)

    Example:
        context = await get_context(db, "user123", "What's the weather?", top_k=3)
        for conv_id, text, distance in context:
            print(f"[{distance:.4f}] {text}")
    """
    # Generate query embedding
    query_embedding = db.embedding_model.encode(query_text).tolist()

    async with db.session() as session:
        # pgvector L2 distance search (lower = more similar)
        stmt = (
            select(
                Conversation.id,
                Conversation.text,
                Conversation.embedding.l2_distance(query_embedding).label("distance")
            )
            .where(Conversation.user_id == user_id)
            .order_by("distance")
            .limit(top_k)
        )
        result = await session.execute(stmt)
        rows = result.all()

        context = [(row.id, row.text, row.distance) for row in rows]
        logger.info(
            "database.context_retrieved",
            user_id=user_id,
            query_length=len(query_text),
            results_count=len(context)
        )
        return context


async def get_recent_conversations(
    db: Database,
    user_id: str,
    limit: int = 10
) -> List[Tuple[int, str]]:
    """
    Get most recent conversations for a user (chronological fallback).

    Args:
        db: Database instance
        user_id: User identifier
        limit: Number of recent conversations to retrieve

    Returns:
        List of (conversation_id, text) tuples ordered by recency
    """
    async with db.session() as session:
        stmt = (
            select(Conversation.id, Conversation.text)
            .where(Conversation.user_id == user_id)
            .order_by(Conversation.created_at.desc())
            .limit(limit)
        )
        result = await session.execute(stmt)
        rows = result.all()
        return [(row.id, row.text) for row in rows]


# ==============================================================================
# Health Check
# ==============================================================================

async def check_database_health(db: Database) -> bool:
    """
    Verify database connectivity.

    Returns:
        True if database is reachable, False otherwise
    """
    try:
        async with db.session() as session:
            await session.execute(select(1))
        return True
    except Exception as e:
        logger.error("database.health_check_failed", error=str(e))
        return False


# ==============================================================================
# Testing / Development Utilities
# ==============================================================================

if __name__ == "__main__":
    async def test_database():
        """Quick test of database operations."""
        db = Database()
        await db.init_tables()

        # Test save
        conv_id = await save_conversation(db, "test_user", "Hello, this is a test message!")
        print(f"✓ Saved conversation: {conv_id}")

        # Test retrieval
        context = await get_context(db, "test_user", "test message", top_k=5)
        print(f"✓ Retrieved {len(context)} context items")
        for conv_id, text, distance in context:
            print(f"  [{distance:.4f}] {text}")

        # Cleanup
        await db.close()
        print("✓ Database test complete")

    asyncio.run(test_database())
