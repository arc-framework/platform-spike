-- ==============================================================================
-- A.R.C. Platform - Agents Schema Migration
-- ==============================================================================
-- Task: T012-T015
-- Purpose: Create agents schema for voice agent conversation tracking
-- Features: pgvector for semantic search, conversation history, session tracking
-- ==============================================================================

-- T012: Create agents schema
CREATE SCHEMA IF NOT EXISTS agents;

COMMENT ON SCHEMA agents IS 'A.R.C. voice agent conversation and session data';

-- ==============================================================================
-- T013: Conversations Table with pgvector
-- ==============================================================================

CREATE TABLE IF NOT EXISTS agents.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Participant information
    user_id VARCHAR(255) NOT NULL,
    agent_id VARCHAR(255) NOT NULL DEFAULT 'arc-scarlett-voice',
    room_name VARCHAR(255),
    session_id VARCHAR(255),
    
    -- Conversation data
    turn_index INTEGER NOT NULL DEFAULT 0,
    user_input TEXT NOT NULL,
    agent_response TEXT NOT NULL,
    
    -- Semantic search (pgvector extension)
    -- Using 1536 dimensions for OpenAI ada-002 embeddings
    -- Change dimension if using different embedding model
    embedding VECTOR(1536),
    
    -- Metadata
    context_used JSONB,  -- Previous conversation turns used for context
    llm_model VARCHAR(100),
    llm_tokens_used INTEGER,
    stt_model VARCHAR(100),
    tts_model VARCHAR(100),
    
    -- Performance metrics
    stt_latency_ms INTEGER,
    llm_latency_ms INTEGER,
    tts_latency_ms INTEGER,
    total_latency_ms INTEGER,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT conversations_turn_index_check CHECK (turn_index >= 0),
    CONSTRAINT conversations_latency_check CHECK (
        stt_latency_ms >= 0 AND 
        llm_latency_ms >= 0 AND 
        tts_latency_ms >= 0 AND
        total_latency_ms >= 0
    )
);

COMMENT ON TABLE agents.conversations IS 'Voice agent conversation history with semantic search';
COMMENT ON COLUMN agents.conversations.embedding IS 'Vector embedding for semantic similarity search (1536 dimensions)';
COMMENT ON COLUMN agents.conversations.context_used IS 'Previous turns retrieved for context generation';
COMMENT ON COLUMN agents.conversations.total_latency_ms IS 'End-to-end latency from user speech to agent response';

-- ==============================================================================
-- T014: Create Indexes
-- ==============================================================================

-- Primary lookup indexes
CREATE INDEX IF NOT EXISTS idx_conversations_user_id 
    ON agents.conversations(user_id);

CREATE INDEX IF NOT EXISTS idx_conversations_session_id 
    ON agents.conversations(session_id);

CREATE INDEX IF NOT EXISTS idx_conversations_room_name 
    ON agents.conversations(room_name);

CREATE INDEX IF NOT EXISTS idx_conversations_created_at 
    ON agents.conversations(created_at DESC);

-- Composite index for user conversation history
CREATE INDEX IF NOT EXISTS idx_conversations_user_created 
    ON agents.conversations(user_id, created_at DESC);

-- Composite index for session conversation flow
CREATE INDEX IF NOT EXISTS idx_conversations_session_turn 
    ON agents.conversations(session_id, turn_index);

-- HNSW index for vector similarity search (requires pgvector extension)
-- This enables fast semantic search over conversation history
-- ivfflat is an alternative if HNSW is not available
CREATE INDEX IF NOT EXISTS idx_conversations_embedding_hnsw
    ON agents.conversations 
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

COMMENT ON INDEX idx_conversations_embedding_hnsw IS 'HNSW index for fast semantic similarity search using cosine distance';

-- ==============================================================================
-- T015: Sessions Table for LiveKit Room Tracking
-- ==============================================================================

CREATE TABLE IF NOT EXISTS agents.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- LiveKit session information
    room_name VARCHAR(255) NOT NULL,
    room_sid VARCHAR(255),  -- LiveKit room SID
    participant_sid VARCHAR(255),  -- LiveKit participant SID
    
    -- User information
    user_id VARCHAR(255) NOT NULL,
    user_identity VARCHAR(255),  -- LiveKit identity
    agent_id VARCHAR(255) NOT NULL DEFAULT 'arc-scarlett-voice',
    
    -- Session metadata
    session_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_end TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER,
    
    -- Conversation statistics
    total_turns INTEGER DEFAULT 0,
    total_user_messages INTEGER DEFAULT 0,
    total_agent_messages INTEGER DEFAULT 0,
    
    -- Performance aggregates
    avg_latency_ms INTEGER,
    p95_latency_ms INTEGER,
    p99_latency_ms INTEGER,
    
    -- Connection quality
    avg_packet_loss_percent NUMERIC(5,2),
    avg_jitter_ms INTEGER,
    connection_quality VARCHAR(20),  -- 'excellent', 'good', 'fair', 'poor'
    
    -- Session state
    status VARCHAR(50) DEFAULT 'active',  -- 'active', 'ended', 'error'
    error_message TEXT,
    
    -- Recording information (for future arc-scribe-egress)
    recording_id UUID,
    recording_url TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT sessions_duration_check CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
    CONSTRAINT sessions_status_check CHECK (status IN ('active', 'ended', 'error'))
);

COMMENT ON TABLE agents.sessions IS 'LiveKit voice agent session tracking and analytics';
COMMENT ON COLUMN agents.sessions.room_sid IS 'LiveKit room session ID';
COMMENT ON COLUMN agents.sessions.duration_seconds IS 'Total session duration (calculated on session end)';

-- Indexes for sessions
CREATE INDEX IF NOT EXISTS idx_sessions_user_id 
    ON agents.sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_sessions_room_name 
    ON agents.sessions(room_name);

CREATE INDEX IF NOT EXISTS idx_sessions_status 
    ON agents.sessions(status);

CREATE INDEX IF NOT EXISTS idx_sessions_session_start 
    ON agents.sessions(session_start DESC);

CREATE INDEX IF NOT EXISTS idx_sessions_user_start 
    ON agents.sessions(user_id, session_start DESC);

-- ==============================================================================
-- Triggers for automatic timestamp updates
-- ==============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION agents.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for conversations table
CREATE TRIGGER update_conversations_updated_at
    BEFORE UPDATE ON agents.conversations
    FOR EACH ROW
    EXECUTE FUNCTION agents.update_updated_at_column();

-- Trigger for sessions table
CREATE TRIGGER update_sessions_updated_at
    BEFORE UPDATE ON agents.sessions
    FOR EACH ROW
    EXECUTE FUNCTION agents.update_updated_at_column();

-- ==============================================================================
-- Grants (adjust based on your user setup)
-- ==============================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA agents TO arc;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON agents.conversations TO arc;
GRANT SELECT, INSERT, UPDATE, DELETE ON agents.sessions TO arc;

-- Grant sequence permissions (for auto-increment if needed)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA agents TO arc;

-- ==============================================================================
-- Sample Queries for Testing
-- ==============================================================================

-- Semantic search query (find similar conversations)
-- SELECT id, user_input, agent_response, created_at
-- FROM agents.conversations
-- ORDER BY embedding <-> '[0.1, 0.2, ..., 0.9]'::vector
-- LIMIT 5;

-- User conversation history
-- SELECT user_input, agent_response, total_latency_ms, created_at
-- FROM agents.conversations
-- WHERE user_id = 'user-123'
-- ORDER BY created_at DESC
-- LIMIT 10;

-- Session statistics
-- SELECT 
--     user_id,
--     COUNT(*) as session_count,
--     AVG(duration_seconds) as avg_duration,
--     AVG(total_turns) as avg_turns,
--     AVG(avg_latency_ms) as overall_avg_latency
-- FROM agents.sessions
-- WHERE session_start > NOW() - INTERVAL '7 days'
-- GROUP BY user_id;

-- ==============================================================================
-- END OF MIGRATION
-- ==============================================================================
