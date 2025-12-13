# A.R.C. LiveKit Setup Guide

## Prerequisites

### 1. Add DNS Entry

Add the following to your `/etc/hosts` file:

```bash
127.0.0.1 livekit.arc.local
```

On macOS/Linux:

```bash
echo "127.0.0.1 livekit.arc.local" | sudo tee -a /etc/hosts
```

### 2. Generate API Credentials

Generate a secure API secret:

```bash
openssl rand -base64 32
```

Update your `.env` file with:

```env
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=<your-generated-secret>
LIVEKIT_NODE_IP=127.0.0.1
```

### 3. Configure Network (Local Development)

For local development, set `LIVEKIT_NODE_IP` to your machine's external IP if you need to test from other devices on your network:

```bash
# macOS
ipconfig getifaddr en0

# Linux
hostname -I | awk '{print $1}'
```

## Deployment

### Start the Stack

```bash
# From platform-spike root
make up-core

# Or with Docker Compose directly
docker compose -f deployments/docker/docker-compose.core.yml up -d
```

### Verify Service Health

```bash
# Check LiveKit health
curl http://localhost:7880/metrics

# Check Traefik routing
curl -H "Host: livekit.arc.local" http://localhost/metrics

# Test WebSocket signaling (should upgrade connection)
curl -i -H "Host: livekit.arc.local" \
     -H "Upgrade: websocket" \
     -H "Connection: Upgrade" \
     http://localhost/
```

### View Logs

```bash
docker logs -f arc_livekit
```

## Testing WebRTC Connection

### Generate a Room Token (Python)

```python
from livekit import api
import os

# Read from environment
api_key = os.getenv("LIVEKIT_API_KEY", "devkey")
api_secret = os.getenv("LIVEKIT_API_SECRET")

token = api.AccessToken(api_key, api_secret) \
    .with_identity("user-123") \
    .with_name("Test User") \
    .with_grants(api.VideoGrants(
        room_join=True,
        room="test-room",
    ))

jwt_token = token.to_jwt()
print(f"Token: {jwt_token}")
```

### Connect from Browser

Use the [LiveKit Playground](https://meet.livekit.io/) or create a simple HTML page:

```html
<!DOCTYPE html>
<html>
  <head>
    <script src="https://unpkg.com/livekit-client/dist/livekit-client.umd.min.js"></script>
  </head>
  <body>
    <div id="status">Connecting...</div>
    <script>
      const room = new LivekitClient.Room();

      room.on(LivekitClient.RoomEvent.Connected, () => {
        document.getElementById('status').textContent = 'Connected!';
      });

      const token = 'YOUR_JWT_TOKEN';
      room
        .connect('ws://livekit.arc.local', token)
        .then(() => console.log('Connected to room'))
        .catch((err) => console.error('Connection failed:', err));
    </script>
  </body>
</html>
```

## Port Reference

| Port        | Protocol | Purpose                         |
| ----------- | -------- | ------------------------------- |
| 7880        | TCP      | HTTP API & WebSocket signaling  |
| 7881        | TCP      | WebRTC TCP fallback             |
| 50000-50100 | UDP      | WebRTC media streams (RTP/RTCP) |

## Troubleshooting

### "Connection refused" on localhost

- Ensure `arc_livekit` container is running: `docker ps | grep arc_livekit`
- Check health status: `docker inspect arc_livekit | grep Health -A 10`

### "No ICE candidates" / WebRTC connection fails

1. Verify `LIVEKIT_NODE_IP` is set correctly in `.env`
2. Check UDP ports are not blocked by firewall
3. For local testing, try setting `use_external_ip: true` in `livekit.yaml`

### "Invalid token" errors

- Verify `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` match between server and token generation
- Check token hasn't expired (default is 6 hours)

### Behind a NAT / Restrictive Firewall

You'll need a TURN server for relay. Add to `livekit.yaml`:

```yaml
rtc:
  ice_servers:
    - urls:
        - stun:stun.l.google.com:19302
        - turn:turn.example.com:3478
      username: your_turn_user
      credential: your_turn_password
```

## Metrics & Monitoring

LiveKit exposes Prometheus metrics at `http://localhost:7880/metrics`.

Key metrics to watch:

- `livekit_room_total` - Total rooms created
- `livekit_participant_total` - Active participants
- `livekit_packet_loss_ratio` - Network quality
- `livekit_rtt_seconds` - Round-trip time

## Next Steps

1. **Deploy arc-scarlett-voice** - The Python agent worker
2. **Set up Piper TTS** - Voice synthesis engine
3. **Configure observability** - Grafana dashboards for LiveKit metrics

See [ADR-001: Daredevil Stack](../../docs/architecture/adr/001-daredevil-realtime-stack.md) for architecture details.
