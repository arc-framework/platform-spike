# NATS - Ephemeral Messaging
Lightweight message broker for real-time agent-to-agent communication.
---
## Overview
**NATS** provides:
- Pub/sub messaging
- Request/reply patterns
- Queue groups for work distribution
- Low-latency communication
- Simple, ephemeral messaging (no persistence)
---
## Ports
- **4222** - Client connections
- **8222** - HTTP monitoring/management
---
## Configuration
See `.env.example` for configuration options.
### Key Features
- **Lightweight** - Minimal resource footprint
- **Fast** - Sub-millisecond latency
- **Simple** - Easy to use and deploy
- **Ephemeral** - Messages are not persisted
---
## Use Cases
### Ideal For
- ✅ Real-time agent coordination
- ✅ Job queues and work distribution
- ✅ Request/reply patterns
- ✅ Service-to-service communication
- ✅ Presence/heartbeat messages
### Not Ideal For
- ❌ Event sourcing (use Pulsar)
- ❌ Message persistence (use Pulsar)
- ❌ Replay historical events (use Pulsar)
- ❌ Cross-region replication
---
## Usage
### Start Service
```bash
make up-stack
# or
docker compose -f docker-compose.yml -f docker-compose.stack.yml up nats
```
### Check Health
```bash
make health-nats
# or
curl http://localhost:8222/healthz
```
### View Monitoring Dashboard
```bash
open http://localhost:8222
```
---
## See Also
- [Core Services](../../../README.md)
- [Pulsar - Durable Messaging](../../durable/pulsar/)
- [NATS Documentation](https://docs.nats.io/)
