# Durable Messaging

Persistent event streaming for event sourcing and the "Conveyor Belt" pattern.

---

## Overview

Durable messaging provides persistent storage of events with replay capabilities. Events are stored on disk and can be replayed at any time.

---

## Implementation

### [Apache Pulsar](./pulsar/)
**Status:** ✅ Active  
**Type:** Distributed event streaming platform

- Persistent event storage
- Event replay and time-travel
- Guaranteed delivery (at-least-once, exactly-once)
- Multi-tenancy and geo-replication

---

## Alternatives

- **Apache Kafka** - Popular, similar features
- **EventStore** - Purpose-built for event sourcing
- **AWS Kinesis** - Cloud-native (AWS only)

---

## See Also

- [Messaging Overview](../)
- [Ephemeral Messaging](../ephemeral/)
- [Core Services](../../README.md)

