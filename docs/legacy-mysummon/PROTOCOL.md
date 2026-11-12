# MySummon: Protocol

All communication uses addon messages with the prefix `MYSUM1`. Messages are plain text, pipe-delimited, and must be under 255 characters.

## Message format

```
MYSUM1|<TYPE>|<field1>|<field2>|...
```

Escape rules: fields must not contain `|`. The `note` field is replaced `|` with `/` and truncated to 60 characters before sending.

## Message types

| Type | Sender | Fields | Purpose |
|---|---|---|---|
| `HELLO` | any | `name`, `class`, `level`, `zone`, `x`, `y`, `role`, `status`, `rating`, `jobs` | Presence heartbeat |
| `REQ` | passenger | `reqId`, `target`, `zone`, `note` | Ask a Warlock for a summon |
| `ACC` | driver | `reqId` | Warlock accepts |
| `DEC` | driver | `reqId`, `reason` | Warlock declines |
| `ARR` | driver | `reqId` | Warlock is in position (ready to summon) |
| `DONE` | driver | `reqId` | Summon completed |
| `CAN` | either | `reqId`, `reason` | Cancelled by either side |
| `RATE` | passenger | `reqId`, `stars` | Rating for a completed job (1 to 5) |
| `PING` | any | `nonce` | Check that a peer is still active |

### Example messages

```
MYSUM1|HELLO|Arthas-Silvermoon|WARLOCK|70|Stormwind City|0.4321|0.6789|driver|online|4.8|132
MYSUM1|REQ|A1B2C3-17|Vex-Silvermoon|Stormwind City|Bank, 2 min
MYSUM1|ACC|A1B2C3-17
MYSUM1|DONE|A1B2C3-17
MYSUM1|RATE|A1B2C3-17|5
```

## Request state machine

```
              REQ
  [none] ──────────► REQUESTED
                        │
          ┌─────────────┼───────────────┬─────────────┐
          │ ACC         │ DEC           │ CAN         │ expiry
          ▼             ▼               ▼             ▼
      ACCEPTED      DECLINED       CANCELLED      EXPIRED
          │
          │ ARR
          ▼
      READY (driver in position)
          │
          │ DONE
          ▼
      COMPLETED ──► RATE (optional, passenger) ──► RATED
```

Terminal states: `DECLINED`, `CANCELLED`, `EXPIRED`, `COMPLETED`, `RATED`.

### Transition rules

| From | Event | To | Who may send |
|---|---|---|---|
| none | REQ | REQUESTED | passenger |
| REQUESTED | ACC | ACCEPTED | driver |
| REQUESTED | DEC | DECLINED | driver |
| REQUESTED | CAN | CANCELLED | passenger |
| REQUESTED | timeout | EXPIRED | local |
| ACCEPTED | ARR | READY | driver |
| ACCEPTED | CAN | CANCELLED | either |
| ACCEPTED | timeout | EXPIRED | local |
| READY | DONE | COMPLETED | driver |
| READY | CAN | CANCELLED | either |
| COMPLETED | RATE | RATED | passenger |

Any other transition is rejected and logged.

## Identifiers

- `reqId` format: `<senderGUIDShort>-<counter>`, for example `A1B2C3-17`.
- The counter is stored in `MySummonCharDB.requestSeq` so IDs stay unique across sessions.

## Versioning

- The prefix includes the major version: `MYSUM1`.
- A breaking change uses `MYSUM2`. Clients on different major versions ignore each other.
- Minor additions use new fields at the end of a message. Older clients ignore extra fields.

## Abuse controls

- Drop any message whose sender is on the local blocklist.
- Drop duplicate `REQ` messages with the same `reqId`.
- Limit incoming `REQ` messages to 3 per sender per minute.
- Only the named driver can send `ACC`, `DEC`, `ARR`, or `DONE` for a request.
- Only the named passenger can send `RATE`.
