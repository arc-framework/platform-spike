import pulsar
from fastapi import FastAPI, HTTPException, status
from .api.v1 import endpoints
from .core.messaging import PULSAR_URL
from .core.tracing import setup_tracing

app = FastAPI(
    title="A.R.C. Voice Agent",
    version="1.0.0",
)

# Setup OpenTelemetry
setup_tracing(app)

@app.get("/health", status_code=status.HTTP_200_OK)
async def health_check():
    """
    Checks the health of the service, including the connection to Pulsar.
    Returns 200 if healthy, 503 if the Pulsar connection fails.
    """
    pulsar_client = None
    try:
        # Attempt to create a client and fetch topic partitions to verify connection.
        # We use a short timeout to avoid long waits on failure.
        pulsar_client = pulsar.Client(PULSAR_URL, operation_timeout_seconds=5)
        # This is a lightweight operation to confirm the broker is reachable.
        pulsar_client.get_topic_partitions("persistent://public/default/non-existent-topic-for-health-check")
        return {"status": "ok", "pulsar_connection": "ok"}
    except Exception as e:
        # If any Pulsar-related error occurs, the service is unhealthy.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "status": "error",
                "pulsar_connection": "failed",
                "error": str(e),
            },
        )
    finally:
        # Ensure the temporary client is always closed.
        if pulsar_client:
            pulsar_client.close()


# Include the API endpoints from the v1 router
app.include_router(endpoints.router)
