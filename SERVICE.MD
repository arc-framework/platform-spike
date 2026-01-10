# 📦 A.R.C. Service Registry & Codename Matrix

> **Architect's Note:**
> This isn't just a list of Docker containers; this is the cast of the movie we're building. Every service has a specific job, a personality, and a specific way of ruining your weekend if configured wrong.
>
> We use **codenames** because "Redis" is boring, but "Sonic" tells you _exactly_ what happens if he crashes (you die).

## 🛠️ The Master Service Table

| Service        | A.R.C. Image       | Type    | Upstream Source                | Codename          | Role & "Why Him?"                                                                             |
| :------------- | :----------------- | :------ | :----------------------------- | :---------------- | :-------------------------------------------------------------------------------------------- |
| **Traefik**    | `arc-gateway`      | INFRA   | `traefik:v3.0`                 | **Heimdall**      | **The Gatekeeper.** Opens the Bifrost (ports) only for authorized traffic.                    |
| **Unleash**    | `arc-flags`        | INFRA   | `unleashorg/unleash-server`    | **Mystique**      | **The Shapeshifter.** Changes app behavior flags instantly without redeploying.               |
| **Kratos**     | `arc-identity`     | INFRA   | `oryd/kratos:latest`           | **J.A.R.V.I.S.**  | **The Butler.** "Welcome home, sir." Handles identity and authentication.                     |
| **Infisical**  | `arc-vault`        | INFRA   | `infisical/infisical:latest`   | **Nick Fury**     | **The Spymaster.** Holds the nuclear codes (secrets). Paranoid for a reason.                  |
| **LiveKit**    | `arc-voice-server` | INFRA   | `livekit/livekit-server`       | **Daredevil**     | **The Radar.** Sees the world through sound waves (WebRTC).                                   |
| **NATS**       | `arc-pulse`        | INFRA   | `nats:alpine`                  | **The Flash**     | **The Nervous System.** Information travels so fast it feels like telepathy.                  |
| **Pulsar**     | `arc-stream`       | INFRA   | `apachepulsar/pulsar`          | **Dr. Strange**   | **Time Stone.** Replays history (events) and sees 14 million outcomes.                        |
| **Postgres**   | `arc-db-sql`       | INFRA   | `postgres:16-alpine`           | **Oracle**        | **Long-Term Memory.** The photographic record of truth.                                       |
| **Redis**      | `arc-db-cache`     | INFRA   | `redis:alpine`                 | **Sonic**         | **Working Memory.** "Gotta go fast." Holds context; if he stops, he dies.                     |
| **Qdrant**     | `arc-db-vector`    | INFRA   | `qdrant/qdrant`                | **Cerebro**       | **The Finder.** Connects to every thought to find semantic matches.                           |
| **MinIO**      | `arc-storage`      | INFRA   | `minio/minio`                  | **Tardis**        | **Infinite Storage.** It's bigger on the inside (S3 compatible).                              |
| **OTEL**       | `arc-otel`         | INFRA   | `otel/opentelemetry-collector` | **Black Widow**   | **The Spy.** Intercepts all signals and traces without being seen.                            |
| **Prometheus** | `arc-metrics`      | INFRA   | `prom/prometheus`              | **Dr. House**     | **Diagnostics.** Doesn't trust you; trusts the vitals. "It's never DNS."                      |
| **Loki**       | `arc-logs`         | INFRA   | `grafana/loki`                 | **Watson**        | **The Chronicler.** Writes down every messy detail for later deduction.                       |
| **Jaeger**     | `arc-traces`       | INFRA   | `grafana/tempo`                | **Columbo**       | **The Detective.** "Just one more thing." Follows the request path.                           |
| **Grafana**    | `arc-viz`          | INFRA   | `grafana/grafana`              | **Friday**        | **The UI.** The visual interface overlay for the metrics.                                     |
| **Promtail**   | `arc-log-shipper`  | INFRA   | `grafana/promtail`             | **Hermes**        | **The Messenger.** Delivers the logs to Watson.                                               |
| **Chaos**      | `arc-chaos`        | INFRA   | `chaos-mesh/chaos-mesh`        | **T-800**         | **The Terminator.** "It absolutely will not stop until you are dead." Tests infra resilience. |
| **Brain**      | `arc-brain`        | CORE    | `./core/engine`                | **Sherlock**      | **The Reasoner.** "Data! I cannot make bricks without clay." (LangGraph).                     |
| **Voice Agt**  | `arc-voice-agent`  | CORE    | `./core/voice`                 | **Scarlett**      | **The Voice.** Turns raw data into human connection (Her).                                    |
| **Janitor**    | `arc-janitor`      | CORE    | `./core/ops`                   | **The Wolf**      | **The Fixer.** "I solve problems." Cleans up the mess efficiently.                            |
| **Billing**    | `arc-billing`      | CORE    | `./plugins/billing`            | **Alfred**        | **The Manager.** Tracks the budget and manages the estate.                                    |
| **Guard**      | `arc-guard`        | CORE    | `./core/guardrails`            | **RoboCop**       | **Safety.** "Prime Directives." Stops the agent from shooting civilians.                      |
| **Critic**     | `arc-ramsay-critic`       | WORKER  | `./workers/critic`             | **Gordon Ramsay** | **QA.** "This output is RAW!" Yells until the answer is perfect.                              |
| **Gym**        | `arc-drago-gym`          | WORKER  | `./workers/gym`                | **Ivan Drago**    | **Adversarial Trainer.** "I must break you." Attacks the Agent's logic.                       |
| **Semantic**   | `arc-uhura-semantic`     | WORKER  | `./workers/semantic`           | **Uhura**         | **Translator.** Converts human speech to system commands (SQL/API).                           |
| **Mechanic**   | `arc-statham-mechanic`     | WORKER  | `./workers/healer`             | **Statham**       | **Self-Healing.** Slides under the car to fix the leak while running.                         |
| **Migrate**    | `arc-pathfinder-migrate`      | SIDECAR | `script`                       | **Pathfinder**    | **Pioneer.** Maps the database schema before anyone else enters.                              |
| **Ingress**    | `arc-sentry-ingress`       | SIDECAR | `livekit/ingress:latest`              | **Sentry**        | **The Watchtower.** Handles incoming RTMP/SIP streams.                                        |
| **Egress**     | `arc-scribe-egress`       | SIDECAR | `livekit/egress:latest`               | **Scribe**        | **The Recorder.** Archives the session to tape.                                               |
| **Mailer**     | `arc-hedwig-mailer`       | SIDECAR | `mailhog/mailhog:latest`                      | **Hedwig**        | **Mail Delivery.** Delivers the message no matter what.                                       |

---

## 🤖 The Extended Roster: New Recruits

We've expanded our testing and operational protocols with new team members:

### Infrastructure Resilience & Operations

- **Service:** `arc-terminator-chaos` (Chaos Mesh)
- **Codename:** **T-800** (The Terminator)
- **Mission:** Infrastructure Resilience.
- **Methodology:**
  - **Stress Testing the Mind (Ivan Drago):** Attacks the Prompt/Logic. Tries to jailbreak the LLM or make it hallucinate.
  - **Stress Testing the Body (The Terminator):** Attacks the Server. Kills Redis containers, introduces 500ms network latency, and corrupts disk I/O.

> **Why Him?**  
> "It can't be bargained with. It can't be reasoned with. It doesn't feel pity, or remorse, or fear. And it absolutely will not stop, ever, until you are dead."

If your system (A.R.C.) stays online, it is truly resilient. If not... _hasta la vista, baby_.

### Workflow Orchestration & Scheduling

- **Service:** `arc-kang-flow` (Temporal)
- **Codename:** **Kang the Conqueror**
- **Mission:** Durable workflow orchestration across time.
- **Methodology:** Controls complex multi-step workflows with durability guarantees. Can replay history and handle failures gracefully.

> **Why Him?**  
> Kang controls time and timelines. Temporal workflows survive crashes and continue from checkpoints. Perfect thematic match.

- **Service:** `arc-doc-time` (Dkron)
- **Codename:** **Doc Brown**
- **Mission:** Distributed cron scheduler for time-based jobs.
- **Methodology:** Handles scheduled tasks across the cluster. "Where we're going, we don't need roads" - asynchronous, distributed execution.

> **Why Him?**  
> Doc Brown schedules events across time. Dkron schedules jobs across servers. Time-travel expert meets distributed scheduler.

### Developer Experience

- **Service:** `arc-architect-portal` (Backstage)
- **Codename:** **The Architect**
- **Mission:** Service catalog and developer portal.
- **Methodology:** Provides unified interface to understand platform structure, service dependencies, and documentation.

> **Why Him?**  
> "I am the Architect. I created the Matrix." The Architect understands the system structure. Backstage helps developers understand the platform architecture.

---

## 📁 Directory Structure & Service Location

Services are organized into a three-tier structure based on their role in the platform:

```
platform-spike/
├── core/                    # ESSENTIAL infrastructure (platform fails without these)
│   ├── gateway/traefik/     # Heimdall - API gateway
│   ├── persistence/postgres/ # Oracle - primary database
│   ├── caching/redis/       # Sonic - working memory
│   ├── messaging/           # Flash & Strange - communication
│   │   ├── ephemeral/nats/  # Flash - real-time messaging
│   │   └── durable/pulsar/  # Strange - event streaming
│   ├── telemetry/           # Widow - observability pipeline
│   └── secrets/infisical/   # Fury - secrets management
│
├── plugins/                 # OPTIONAL components (swappable, not always needed)
│   ├── observability/       # Monitoring stack
│   │   ├── logging/loki/    # Watson - log aggregation
│   │   ├── metrics/prometheus/ # House - metrics collection
│   │   ├── tracing/jaeger/  # Columbo - distributed tracing
│   │   └── visualization/grafana/ # Friday - dashboards
│   └── security/kratos/     # Jarvis - identity management
│
├── services/                # APPLICATION logic (your AI agents and workers)
│   ├── arc-sherlock-brain/  # Sherlock - reasoning engine
│   ├── arc-scarlett-voice/  # Scarlett - voice agent
│   ├── arc-piper-tts/       # Piper - text-to-speech
│   └── utilities/raymond/   # Raymond - bootstrap utilities
│
└── .docker/                 # Shared Docker base images
    └── base/
        ├── python-ai/       # Base for Python AI services
        └── go-infra/        # Base for Go services
```

### Tier Decision Tree

```
Is this service required for the platform to start?
├── YES → Does it have deep integration with multiple services?
│         ├── YES → core/
│         └── NO  → Consider if it's truly "core"
└── NO  → Is it infrastructure (monitoring, auth, storage)?
          ├── YES → plugins/
          └── NO  → services/
```

### Quick Reference: Where Does My Service Go?

| If your service is... | Put it in... | Example |
|-----------------------|--------------|---------|
| Required to boot the platform | `core/` | Postgres, Redis, NATS |
| Optional infrastructure | `plugins/` | Grafana, Jaeger, Kratos |
| AI agent or reasoning engine | `services/` | arc-sherlock-brain |
| Business logic worker | `services/` | arc-ramsay-critic |
| Shared library (not a service) | `libs/` | Common utilities |

---

## 🆕 How to Add a New Service

### 1. Choose Your Tier

Use the decision tree above to determine if your service is `core/`, `plugins/`, or `services/`.

### 2. Pick a Codename

Follow the A.R.C. Constitution naming pattern:
- **Marvel/Hollywood inspired** - Memorable and descriptive
- **Matches the service's personality** - What does it "feel" like?
- **Unique across the platform** - Check this registry first!

### 3. Create Directory Structure

```bash
# For application services
mkdir -p services/arc-{codename}-{function}

# Example: New "analyst" service with codename "stark"
mkdir -p services/arc-stark-analyst
```

### 4. Add Required Files

**Python Service:**
```bash
cd services/arc-{codename}-{function}
touch Dockerfile requirements.txt README.md
mkdir -p src
touch src/__init__.py src/main.py
```

**Go Service:**
```bash
cd services/arc-{codename}-{function}
touch Dockerfile README.md
go mod init github.com/arc-framework/arc-{codename}-{function}
mkdir -p cmd
```

### 5. Use Base Images

```dockerfile
# Python AI services
FROM ghcr.io/arc/base-python-ai:3.11-alpine3.19

# Go infrastructure services
FROM ghcr.io/arc/base-go-infra:1.21-alpine3.19
```

### 6. Update This Registry

Add your service to the Master Service Table above with:
- Service name
- A.R.C. image name (`arc-{codename}-{function}`)
- Type (INFRA/CORE/WORKER/SIDECAR)
- Upstream source
- Codename
- Role description

### 7. Add to Docker Compose

Add service definition to the appropriate compose file:
- `deployments/docker/docker-compose.core.yml` - Core services
- `deployments/docker/docker-compose.services.yml` - Application services

---

## 🔗 Related Documentation

- **[core/README.md](./core/README.md)** - Core infrastructure details
- **[plugins/README.md](./plugins/README.md)** - Plugin components
- **[services/README.md](./services/README.md)** - Application services
- **[Docker Standards](./specs/002-stabilize-framework/docker-standards.md)** - Dockerfile requirements
- **[Directory Design](./specs/002-stabilize-framework/directory-design.md)** - Architecture decisions
