# A.R.C. Media Layer

## arc-daredevil-voice (LiveKit Server)

The Central Nervous System for real-time voice communication.

### What It Does

- **WebRTC SFU:** Selective Forwarding Unit for low-latency media routing
- **Room Management:** Creates and manages voice conversation rooms
- **State Sync:** Uses Redis (`arc-sonic-cache`) for distributed state
- **Signaling:** WebSocket endpoint for ICE/SDP negotiation

### Why LiveKit?

Because building WebRTC from scratch is a circle of hell Dante didn't even document.

### Port Requirements

- **7880:** HTTP API & WebSocket signaling
- **50000-60000 (UDP):** RTP/RTCP media streams (YES, ALL OF THEM)

### Configuration

See `livekit/livekit.yaml` for the server config.

### Integration

- **Gateway:** Traefik routes `livekit.arc.local` to this service
- **Cache:** Redis stores room/participant state
- **Agents:** Python workers connect via LiveKit Agents SDK
- **Observability:** Exposes Prometheus metrics on `:7880/metrics`

## Directory Structure

```
media/
├── livekit/               # LiveKit Server configuration
│   ├── livekit.yaml      # Server config
│   └── Dockerfile        # Custom build (if needed)
└── README.md             # This file
```

## References

- [LiveKit Server Docs](https://docs.livekit.io/home/self-hosting/deployment/)
- [ADR-001: Daredevil Stack](../../docs/architecture/adr/001-daredevil-realtime-stack.md)
