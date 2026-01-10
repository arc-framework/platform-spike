"""
arc-sherlock-brain LangGraph State Machine
Linear reasoning flow: retrieve_context → generate_response
"""

import os
from typing import TypedDict, List, Annotated, Optional
from operator import add

from langgraph.graph import StateGraph, END
from langchain_core.messages import HumanMessage, AIMessage, BaseMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
import structlog

from .database import Database, get_context, save_conversation

logger = structlog.get_logger()

# ==============================================================================
# State Definition
# ==============================================================================

class AgentState(TypedDict):
    """
    State passed through the LangGraph workflow.

    Fields:
        messages: Conversation history (accumulated via operator.add)
        user_id: User identifier for context retrieval
        context: Retrieved conversation history from pgvector
        final_response: Generated response text
    """
    messages: Annotated[List[BaseMessage], add]
    user_id: str
    context: Optional[List[str]]
    final_response: Optional[str]


# ==============================================================================
# Node Functions
# ==============================================================================

async def retrieve_context_node(state: AgentState, db: Database) -> AgentState:
    """
    Node 1: Retrieve relevant conversation history using pgvector.

    Args:
        state: Current agent state
        db: Database instance

    Returns:
        Updated state with context field populated
    """
    user_id = state["user_id"]
    latest_message = state["messages"][-1].content if state["messages"] else ""

    logger.info(
        "graph.retrieve_context_start",
        user_id=user_id,
        query_length=len(latest_message)
    )

    # Get semantic context (top 5 similar conversations)
    context_results = await get_context(db, user_id, latest_message, top_k=5)
    context_texts = [text for _, text, _ in context_results]

    logger.info(
        "graph.retrieve_context_complete",
        user_id=user_id,
        context_count=len(context_texts)
    )

    return {
        **state,
        "context": context_texts
    }


async def generate_response_node(state: AgentState, llm_client) -> AgentState:
    """
    Node 2: Generate response using LLM with retrieved context.

    Args:
        state: Current agent state
        llm_client: LLM client (Ollama, OpenAI-compatible API, etc.)

    Returns:
        Updated state with final_response field populated
    """
    user_id = state["user_id"]
    messages = state["messages"]
    context = state.get("context", [])

    logger.info(
        "graph.generate_response_start",
        user_id=user_id,
        message_count=len(messages),
        context_count=len(context)
    )

    # Build prompt with context
    system_prompt = """You are Sherlock, an AI reasoning assistant.
You have access to conversation history to provide contextual responses.

Previous Conversation Context:
{context}

Respond thoughtfully and concisely based on the user's message and available context.
"""

    context_str = "\n".join([f"- {ctx}" for ctx in context]) if context else "No prior context available."

    prompt = ChatPromptTemplate.from_messages([
        ("system", system_prompt),
        MessagesPlaceholder(variable_name="messages"),
    ])

    # Format prompt
    formatted_prompt = prompt.format_messages(
        context=context_str,
        messages=messages
    )

    # Call LLM (assuming llm_client has an async ainvoke method)
    try:
        response = await llm_client.ainvoke(formatted_prompt)
        response_text = response.content if hasattr(response, "content") else str(response)
    except Exception as e:
        logger.error("graph.llm_error", error=str(e))
        response_text = "I apologize, but I'm having trouble processing your request right now."

    logger.info(
        "graph.generate_response_complete",
        user_id=user_id,
        response_length=len(response_text)
    )

    return {
        **state,
        "final_response": response_text,
        "messages": state["messages"] + [AIMessage(content=response_text)]
    }


# ==============================================================================
# Graph Construction
# ==============================================================================

def create_reasoning_graph(db: Database, llm_client) -> StateGraph:
    """
    Create the LangGraph state machine for reasoning.

    Workflow:
        START → retrieve_context → generate_response → END

    Args:
        db: Database instance for context retrieval
        llm_client: LLM client for response generation

    Returns:
        Compiled StateGraph ready for invocation
    """
    workflow = StateGraph(AgentState)

    # Define nodes with dependency injection for db and llm_client
    async def retrieve_with_db(state: AgentState) -> AgentState:
        return await retrieve_context_node(state, db)

    async def generate_with_llm(state: AgentState) -> AgentState:
        return await generate_response_node(state, llm_client)

    # Add nodes
    workflow.add_node("retrieve_context", retrieve_with_db)
    workflow.add_node("generate_response", generate_with_llm)

    # Define edges (linear flow)
    workflow.set_entry_point("retrieve_context")
    workflow.add_edge("retrieve_context", "generate_response")
    workflow.add_edge("generate_response", END)

    # Compile graph
    graph = workflow.compile()
    logger.info("graph.initialized", nodes=["retrieve_context", "generate_response"])

    return graph


# ==============================================================================
# Graph Invocation
# ==============================================================================

async def invoke_reasoning_graph(
    graph: StateGraph,
    db: Database,
    user_id: str,
    message: str
) -> str:
    """
    Execute the reasoning graph for a single user message.

    Args:
        graph: Compiled StateGraph
        db: Database instance
        user_id: User identifier
        message: User's input message

    Returns:
        AI-generated response text

    Example:
        response = await invoke_reasoning_graph(graph, db, "user123", "What's the weather?")
    """
    logger.info(
        "graph.invoke_start",
        user_id=user_id,
        message_length=len(message)
    )

    # Initialize state
    initial_state: AgentState = {
        "messages": [HumanMessage(content=message)],
        "user_id": user_id,
        "context": None,
        "final_response": None
    }

    # Run graph
    try:
        final_state = await graph.ainvoke(initial_state)
        response = final_state["final_response"]

        # Persist conversation
        await save_conversation(db, user_id, message)  # Save user message
        await save_conversation(db, user_id, response)  # Save AI response

        logger.info(
            "graph.invoke_complete",
            user_id=user_id,
            response_length=len(response)
        )

        return response

    except Exception as e:
        logger.error("graph.invoke_error", user_id=user_id, error=str(e))
        raise


# ==============================================================================
# LLM Client Factory
# ==============================================================================

def create_llm_client(model_name: Optional[str] = None, base_url: Optional[str] = None):
    """
    Create LLM client for local inference (Ollama, vLLM, etc.).

    Args:
        model_name: Model identifier (e.g., "mistral:7b")
        base_url: LLM API base URL (e.g., "http://localhost:11434")

    Returns:
        LLM client compatible with LangChain ChatModel interface
    """
    model_name = model_name or os.getenv("LLM_MODEL", "mistral:7b")
    base_url = base_url or os.getenv("LLM_BASE_URL", "http://localhost:11434")

    # Using Ollama as default local LLM provider
    from langchain_community.chat_models import ChatOllama

    llm = ChatOllama(
        model=model_name,
        base_url=base_url,
        temperature=0.7,
        num_ctx=4096,  # Context window
    )

    logger.info(
        "graph.llm_initialized",
        model=model_name,
        base_url=base_url
    )

    return llm


# ==============================================================================
# Testing / Development
# ==============================================================================

if __name__ == "__main__":
    import asyncio
    from .database import Database

    async def test_graph():
        """Quick test of LangGraph workflow."""
        db = Database()
        await db.init_tables()

        llm_client = create_llm_client()
        graph = create_reasoning_graph(db, llm_client)

        # Test invocation
        response = await invoke_reasoning_graph(
            graph, db, "test_user", "Hello, tell me about yourself!"
        )
        print(f"✓ Graph response: {response}")

        await db.close()
        print("✓ Graph test complete")

    asyncio.run(test_graph())
