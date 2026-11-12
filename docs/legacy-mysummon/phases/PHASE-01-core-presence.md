# Phase 1: Core skeleton and presence

**Goal:** Build the addon foundation. Addon users can see each other nearby in a dashboard list. No requests yet.

**Depends on:** Phase 0 passed.

## Tasks

### Foundation
- [ ] **1.1** Create `MySummon.toc` with the verified Interface number, title, notes, version, SavedVariables, and load order from `docs/ARCHITECTURE.md`.
- [ ] **1.2** Add `libs/LibStub` and `libs/CallbackHandler` (or the approach chosen in Phase 0). Document the versions in `libs/README.md`.
- [ ] **1.3** Create `Core.lua`: event hub, startup message, `/mysummon` slash command that prints help and toggles the dashboard.
- [ ] **1.4** Create `Locale/enUS.lua` with all user-facing strings. No hard-coded English text in UI or logic files after this task.
- [ ] **1.5** Create `Config.lua` with defaults for `MySummonDB` and `MySummonCharDB`, and a migration function that handles missing keys.

### Protocol (pure Lua, testable)
- [ ] **1.6** Create `Protocol.lua`: `encode(type, fields)` and `decode(string)`. Enforce the 255-character limit and the `|` escape rule.
- [ ] **1.7** Create `tests/test_protocol.lua` covering valid messages, malformed messages, unknown versions, long notes, and pipe characters. Run with standalone Lua 5.1.

### Networking
- [ ] **1.8** Create `Net.lua`: register the prefix, send via a queue, throttle to the limit found in Phase 0 (task 0.6), and dispatch received messages to handlers.
- [ ] **1.9** Wrap every incoming handler in `pcall`. Log errors to a debug buffer, viewable with `/mysummon debug`.

### Presence (Roster)
- [ ] **1.10** Create `Roster.lua`: send `HELLO` every 30 seconds with name, class, level, zone, position, role, status, and rating placeholder.
- [ ] **1.11** Store remote entries in a table keyed by `Name-Realm`. Remove entries not heard from in 90 seconds.
- [ ] **1.12** Ignore `HELLO` messages from senders on the local blocklist (blocklist UI comes in Phase 3, but the check goes in now).
- [ ] **1.13** Expose `Roster.GetNearby(filter)` returning a sorted list. Sort by same zone first, then by estimated distance, then by name.

### Passenger dashboard (read-only)
- [ ] **1.14** Create `UI/Dashboard.lua`: a movable frame with a scrollable list of nearby Warlocks showing name, level, zone, status, and estimated distance.
- [ ] **1.15** Show "No Warlocks nearby" when the list is empty.
- [ ] **1.16** Refresh the list every 5 seconds while visible, and on each roster change.
- [ ] **1.17** Remember frame position in `MySummonDB`.

### Driver online toggle
- [ ] **1.18** Add an online or offline toggle for Warlocks in the dashboard. Offline Warlocks still send `HELLO` with status `offline`, or stop sending entirely (decide and record in `PROTOCOL.md`).

## Acceptance criteria

- Two accounts running the addon see each other in the dashboard within 35 seconds of login.
- A Warlock going offline disappears from the other client within 95 seconds.
- Protocol tests pass with `lua tests/test_protocol.lua` (exit code 0).
- No Lua errors across a 15-minute session with three clients.
- Message volume at idle is below the throttle limit (checked with the debug buffer).

## Out of scope

- Requests of any kind
- Ratings and history
- Minimap button
