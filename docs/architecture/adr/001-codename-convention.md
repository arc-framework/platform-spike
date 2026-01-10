# ADR-001: Codename Convention

**Status:** Accepted
**Date:** 2025-11-01
**Decision Makers:** A.R.C. Platform Team

---

## Context

The A.R.C. platform consists of many services, including both infrastructure components (databases, message queues, gateways) and application services (AI agents, workers). As the platform grows, developers need a way to quickly identify and remember services.

### Problem Statement

How should services be named to balance technical accuracy with memorability and team communication?

### Relevant Constraints

- Names must be unique across the platform
- Names should be memorable for team discussions
- Names should hint at the service's purpose
- Docker images need consistent naming conventions

---

## Decision Drivers

- **Memorability**: Team members should easily recall service names
- **Purpose alignment**: Names should suggest what the service does
- **Fun factor**: Development should be enjoyable
- **Consistency**: All services should follow the same pattern

---

## Considered Options

### Option 1: Technical Names Only

Use purely technical names like `postgres`, `redis`, `langchain-agent`.

**Pros:**
- Immediately clear what technology is used
- No learning curve

**Cons:**
- Boring and forgettable
- Hard to distinguish in conversation ("which Redis?")
- No personality

### Option 2: Codenames Only

Use only codenames like `oracle`, `sonic`, `sherlock`.

**Pros:**
- Memorable and fun
- Easy to discuss ("Sherlock is down")

**Cons:**
- New team members don't know what services do
- Requires lookup for understanding

### Option 3: Hybrid (Codename + Technical)

Use codenames in conversation and documentation, with technical names in code.
Format: `arc-{codename}` for images, codename in docs.

**Pros:**
- Best of both worlds
- Codenames for conversation, technical for clarity
- Consistent image naming

**Cons:**
- Two names to learn
- Slightly more complex

---

## Decision

We will use **Option 3: Hybrid naming** with the following conventions:

1. **Docker image names**: `arc-{codename}` (e.g., `arc-oracle`, `arc-sherlock`)
2. **Service directories**: `arc-{codename}-{function}` (e.g., `arc-sherlock-brain`)
3. **Documentation**: Use codenames with technical clarification
4. **Conversation**: Use codenames ("Sherlock is reasoning slowly")

### Codename Themes

Codenames should be inspired by:
- **Marvel/DC characters** for infrastructure (power and reliability)
- **Movie characters** for agents (personality and role)
- **Consistent theming** within categories

### Rationale

The hybrid approach gives us memorable names for daily communication while maintaining technical clarity. The Marvel/movie theme adds personality and makes the platform more engaging to work with.

---

## Consequences

### Positive

- Team enjoys discussing services by codename
- Services are easily distinguishable in conversation
- Platform has personality and culture

### Negative

- New team members need to learn codenames
- SERVICE.MD becomes the essential reference

### Neutral

- Requires maintaining codename registry

---

## Implementation

See [SERVICE.MD](../../../SERVICE.MD) for the complete codename registry.

---

## Related

- [SERVICE.MD](../../../SERVICE.MD) - Service registry
- [ADR-002](./002-three-tier-structure.md) - Directory organization

---

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2025-11-01 | Platform Team | Initial acceptance |
