# Arc Framework - Observability Spike

This project is a technical spike to demonstrate a complete observability stack for a sample Go application (`swiss-army-go`) using OpenTelemetry. It serves as a blueprint for integrating robust logging, metrics, and tracing into services within the Arc Framework.

The Go application generates all three telemetry signals (logs, metrics, and traces), which are collected and visualized using a suite of best-in-class open-source tools orchestrated with Docker Compose.

## How to Run

1.  Make sure you have Docker and Docker Compose installed.
2.  From the root of the project, run the following command:
    ```sh
    docker-compose up -d --build
    ```
    This will build the necessary custom images and start all services in the background.

## Components

The `docker-compose.yml` file orchestrates the following services:

-   **`swiss-army-go`**: The sample Go application that generates telemetry data (logs, metrics, traces).
-   **`otel-collector`**: The OpenTelemetry Collector receives telemetry from the Go app, processes it (e.g., adds trace context to logs), and exports it to the appropriate backends.
-   **`loki`**: The log aggregation backend, which stores logs received from the collector.
-   **`prometheus`**: The time-series database that scrapes and stores metrics from the collector.
-   **`jaeger`**: The distributed tracing backend that stores and visualizes traces.
-   **`grafana`**: The primary visualization dashboard for viewing logs from Loki and metrics from Prometheus.

## Accessing Dashboards

Once the services are running, you can access the following web UIs from your browser:

### 1. Grafana (Logs & Metrics)

This is your main dashboard for visualizing logs and metrics. The Loki data source is auto-provisioned.

-   **URL**: **http://localhost:3000**
-   **Login**:
    -   Username: `admin`
    -   Password: `admin` (you will be prompted to change this on first login)
-   **How to see logs**:
    1.  Click the **Explore** (compass) icon on the left sidebar.
    2.  Ensure the **Loki** data source is selected at the top.
    3.  In the "Log browser" query field, enter: `{service_name="swiss-army-go"}`
    4.  Set the time range to "Last 5 minutes" and run the query.

### 2. Jaeger (Traces)

This is where you can visualize the distributed traces from the Go application.

-   **URL**: **http://localhost:16686**
-   **How to see traces**:
    1.  On the "Search" page, select **`swiss-army-go`** from the "Service" dropdown.
    2.  Click the "Find Traces" button.
    3.  You should see traces named `CollectorExporter-Example`. Clicking on one will show you a detailed flame graph of the application's execution.

### 3. Prometheus (Metrics Backend)

The Prometheus UI is useful for diagnostics and verifying that metrics are being collected.

-   **URL**: **http://localhost:9090**
-   **How to verify metrics collection**:
    1.  Navigate to the **Status** -> **Targets** menu.
    2.  You should see a target for the `otel-collector` job with a green `UP` state. This confirms that Prometheus is successfully scraping the metrics that your Go application is sending to the collector.