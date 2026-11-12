# MySummon: Architecture

## Folder layout

```
addon/MySummon/
  MySummon.toc          manifest (must match folder name)
  Core.lua              init, event hub, slash commands
  Config.lua            defaults, Settings panel
  Net.lua               addon message send and receive, prefix registration, throttling
  Protocol.lua          encode and decode messages (pure Lua, testable)
  State.lua             request state machine (pure Lua, testable)
  Roster.lua            nearby Warlock directory, heartbeats, expiry
  Requests.lua          passenger and driver request handling
  Ratings.lua           rating exchange and averages
  Summon.lua            secure summon button and pre-cast checks
  History.lua           job history and cap
  UI/Dashboard.lua      passenger panel
  UI/Driver.lua         Warlock queue panel
  UI/Minimap.lua        minimap button
  Locale/enUS.lua       English strings
  Locale/esES.lua       Spanish strings (Phase 4)
  libs/                 LibStub, CallbackHandler, LibDBIcon, others as needed
  tests/                standalone Lua tests for Protocol.lua and State.lua
```

## Load order (in the .toc)

1. `libs/...`
2. `Locale/enUS.lua`
3. `Protocol.lua`
4. `State.lua`
5. `Config.lua`
6. `Net.lua`
7. `Roster.lua`
8. `Requests.lua`
9. `Ratings.lua`
10. `History.lua`
11. `Summon.lua`
12. `UI/Dashboard.lua`, `UI/Driver.lua`, `UI/Minimap.lua`
13. `Core.lua` (last, so it can wire everything together)

## Module responsibilities

| Module | Responsibility | Depends on |
|---|---|---|
| Protocol | Build and parse messages, version checks | nothing |
| State | Valid transitions for a request, timeouts | nothing |
| Net | Send and receive addon messages, throttle, prefix | Protocol |
| Roster | Track nearby MySummon users, expire stale entries | Net, Protocol |
| Requests | Create, accept, decline, cancel, complete requests | Net, State, Roster |
| Summon | Secure button, pre-cast checks (combat, zone, instance, dead) | Requests |
| Ratings | Exchange ratings for completed jobs | Net, Requests |
| History | Store and cap job records | SavedVariables |
| UI | Display only. No protocol logic inside UI files. | Requests, Roster, Ratings |
| Core | Event registration, slash commands, startup | all |

Rule: UI files never send messages directly. They call Requests or Roster.

## Data

### SavedVariables

**`MySummonDB` (account-wide)**
- `settings`: UI scale, sound on or off, minimap button position, language
- `blocklist`: list of `Name-Realm`
- `favorites`: list of `Name-Realm`
- `ratingCache`: `Name-Realm` to `{ total, count }`
- `tipGuide`: text entries by zone (player-editable)

**`MySummonCharDB` (per character)**
- `driver`: online flag, service rules (zones, minimum level, auto-decline options)
- `history`: array of job records, capped at 500 entries
- `requestSeq`: counter used to build unique request IDs

### Job record

```lua
{
  id = "A1B2C3-17",          -- requestId
  role = "driver" | "passenger",
  other = "Name-Realm",
  zone = "Stormwind City",
  state = "completed" | "declined" | "cancelled" | "expired" | "failed",
  startedAt = 1731448800,   -- time() seconds
  endedAt = 1731449100,
  rating = 5,                -- optional
}
```

## Timing defaults (tune in Phase 2)

| Setting | Default |
|---|---|
| Presence heartbeat | every 30 seconds |
| Presence expiry | 90 seconds without heartbeat |
| Request expiry | 180 seconds without acceptance |
| Accepted request expiry | 600 seconds without completion |
| Request cooldown per target | 60 seconds after decline or cancel |
| Outgoing message rate | max 5 per second, queued |

## Error handling principles

- Unknown message version: ignore, no error.
- Malformed message: log to debug buffer, ignore.
- Invalid state transition: reject, keep the current state, notify the user only if the action came from them.
- Never let a network message throw an uncaught error. Wrap handlers in `pcall` and record failures.
