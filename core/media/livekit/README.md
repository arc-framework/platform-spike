# LiveKit Media Server (arc-daredevil-voice)

**Service Codename**: `arc-daredevil-voice`  
**Role**: The Listener - WebRTC SFU for low-latency voice agent communication  
**Technology**: LiveKit Server (Go)  
**Status**: ✅ Deployed

---

## Overview

LiveKit is a high-performance Selective Forwarding Unit (SFU) that handles WebRTC media routing for the A.R.C. voice agent platform. It provides:

- **Sub-200ms latency** for real-time voice communication
- **WebRTC transport** (UDP-based, firewall-friendly with TCP fallback)
- **Multi-participant rooms** for voice agent interactions
- **Distributed state** via Redis for horizontal scaling

---

## Configuration

### Ports

| Port Range      | Protocol | Purpose                           | Notes                        |
| --------------- | -------- | --------------------------------- | ---------------------------- |
| **7880**        | TCP      | HTTP API & WebSocket signaling    | Main entry point             |
| **7881**        | TCP      | WebRTC TCP fallback               | For restricted firewalls     |
| **50000-50100** | UDP      | WebRTC media streams (RTP/RTCP)   | **Development: 100 ports**   |
| **50000-60000** | UDP      | WebRTC media streams (Production) | **Production: 10,000 ports** |

**Important**:

- Development exposes only 100 UDP ports (50000-50100) to limit resource usage
- Production should expose full range (50000-60000) for scalability
- UDP ports MUST be open in firewall for WebRTC to work
- TCP port 7881 provides fallback if UDP is blocked

### Environment Variables

See `.env` file in project root:

```bash
LIVEKIT_API_KEY=devkey                    # API key for authentication
LIVEKIT_API_SECRET=<32+ char secret>      # MUST be ≥32 characters
LIVEKIT_NODE_IP=127.0.0.1                 # External IP for local dev
```

**Generate a secure secret**:

```bash
openssl rand -base64 32
```

### Configuration File

Location: `core/media/livekit/livekit.yaml`

Key settings:

- **Port**: 7880 (HTTP/WebSocket)
- **RTC Port Range**: 50000-50100 (dev) or 50000-60000 (prod)
- **Redis**: `arc-sonic:6379` (required for distributed state)
- **Auto-create rooms**: Enabled
- **STUN server**: `stun.l.google.com:19302`

---

## DNS Setup

LiveKit requires a hostname for proper WebRTC routing:

```bash
# Add to /etc/hosts
127.0.0.1 livekit.arc.local
```

Or use the validation script:

```bash
./scripts/livekit/validate-dns.sh
```

---

## Usage

### Start Service

```bash
# Start all core services including LiveKit
make up-core

# Or start minimal stack
make up-minimal
```

### Check Health

```bash
# Via make
make health-core

# Direct check (should show LiveKit metrics)
curl http://localhost:7880/metrics

# Via Traefik (with Host header)
curl -H "Host: livekit.arc.local" http://localhost/metrics
```

### Generate Access Token

LiveKit uses JWT tokens for room access:

```bash
# Generate token for a room
./scripts/livekit/generate-token.sh <room_name> <participant_name>

# Example
./scripts/livekit/generate-token.sh test-room alice

# Token is printed and copied to clipboard (macOS)
```

### Test WebRTC Connection

Open the test client in your browser:

```bash
# Serve test client
open core/media/livekit/test-client.html
# Or with Python
python3 -m http.server 8000 --directory core/media/livekit
# Then open: http://localhost:8000/test-client.html
```

---

## Architecture Integration

### Role in Voice Pipeline

```
User Browser
    │ WebSocket (wss://livekit.arc.local)
    ▼
arc-heimdall-gateway (Traefik)
    │ Routes: Host(livekit.arc.local)
    ▼
arc-daredevil-voice (LiveKit SFU)
    │ UDP/RTP media streams
    ├──► arc-sonic-cache (Redis state)
    └──► arc-scarlett-voice (Agent Worker)
```

### Dependencies

- **arc-sonic-cache (Redis)**: REQUIRED for room state synchronization
- **arc-widow-otel (OpenTelemetry)**: Metrics and traces collection
- **arc-heimdall-gateway (Traefik)**: HTTP/WebSocket routing

---

## WebRTC NAT Traversal

### STUN (Session Traversal Utilities for NAT)

Default STUN server: `stun.l.google.com:19302`

STUN helps clients discover their public IP addresses for peer-to-peer connection.

### TURN (Traversal Using Relays around NAT)

**Not configured in development**. For production with restrictive firewalls:

1. Deploy Coturn server
2. Update `livekit.yaml`:

```yaml
rtc:
  turn:
    enabled: true
    domain: turn.arc.example.com
    tls_port: 5349
    udp_port: 3478
```

### ICE (Interactive Connectivity Establishment)

LiveKit automatically handles ICE candidate gathering. Connection flow:

1. Client tries UDP (ports 50000-50100)
2. If UDP fails, fallback to TCP (port 7881)
3. If direct connection fails, use TURN relay (if configured)

---

## Monitoring

### Prometheus Metrics

LiveKit exposes metrics at `http://localhost:7880/metrics`:

```promql
# Room participants
livekit_room_participants

# Packet loss
livekit_packet_loss_percent

# Track publish duration
livekit_track_publish_duration_seconds

# Jitter
livekit_jitter_seconds
```

### Logs

```bash
# View LiveKit logs
docker logs -f arc-daredevil-voice

# Filter for errors
docker logs arc-daredevil-voice 2>&1 | grep ERROR
```

### Distributed Tracing

LiveKit integrates with OpenTelemetry. Traces are sent to `arc-widow-otel` and viewable in Jaeger.

---

## Troubleshooting

### "Secret is too short" Error

```bash
# Error in logs
ERROR: secret is too short, should be at least 32 characters

# Fix: Generate new secret
openssl rand -base64 32

# Update .env
LIVEKIT_API_SECRET=<new_secret_here>

# Restart
make restart
```

### Cannot Connect to WebSocket

```bash
# 1. Check DNS
./scripts/livekit/validate-dns.sh

# 2. Verify service is running
docker ps | grep arc-daredevil

# 3. Check Traefik routing
curl -H "Host: livekit.arc.local" http://localhost/

# 4. Check logs
docker logs arc-daredevil-voice
```

### No Audio / High Latency

```bash
# Check packet loss
curl http://localhost:7880/metrics | grep packet_loss

# Check jitter
curl http://localhost:7880/metrics | grep jitter

# Verify UDP ports are open
sudo lsof -i UDP:50000-50100

# If UDP blocked, check TCP fallback
sudo lsof -i TCP:7881
```

### Redis Connection Failed

```bash
# Verify Redis is running
docker ps | grep arc-sonic

# Test Redis connection
docker exec arc-sonic-cache redis-cli ping
# Should return: PONG

# Check LiveKit can reach Redis
docker exec arc-daredevil-voice ping -c 1 arc-sonic
```

---

## Security Considerations

### Development

- API secrets in plain text (`.env` file)
- All ports exposed on `0.0.0.0`
- No TLS/SSL encryption
- **DO NOT use in production**

### Production

- [ ] Rotate API secrets monthly
- [ ] Use TLS/SSL for WebSocket (wss://)
- [ ] Limit port exposure (only 80/443 public)
- [ ] Deploy TURN server with TLS
- [ ] Enable Traefik authentication for admin APIs
- [ ] Use secrets management (Infisical or Vault)

See: `docs/deployment/production.md` for full production setup.

---

## Performance Tuning

### Connection Limits

Default: 10 participants per room

Increase for larger conferences:

```yaml
# livekit.yaml
room:
  max_participants: 50 # Adjust based on server resources
```

### Bandwidth Limits

Default: 1 MB/s per participant

Adjust in `livekit.yaml`:

```yaml
limit:
  bytes_per_sec: 2000000 # 2 MB/s
```

### CPU Optimization

LiveKit is already optimized (Go). For heavy load:

- Use Redis Cluster for distributed state
- Deploy multiple LiveKit nodes behind load balancer
- Enable Redis persistence for state recovery

---

## Related Documentation

- [ADR-001: Daredevil Real-Time Stack](../../../docs/architecture/adr/001-daredevil-realtime-stack.md)
- [Data Flow Analysis](../../../docs/architecture/REALTIME-MEDIA-DATA-FLOW.md)
- [LiveKit Setup Guide](./SETUP.md)
- [LiveKit Official Docs](https://docs.livekit.io/)

---

**Status**: ✅ Service configured and running  
**Next Steps**: Implement agent worker (`arc-scarlett-voice`) to consume audio streams  
**Owner**: Platform Team
