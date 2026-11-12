# Phase 2: Requests (passenger and driver flow)

**Goal:** A passenger can request a summon from a Warlock. The Warlock can accept, decline, and complete the job with a secure summon button. All states are tracked and time out cleanly.

**Depends on:** Phase 1 passed.

## Tasks

### State machine (pure Lua, testable)
- [ ] **2.1** Create `State.lua` implementing the transitions in `docs/PROTOCOL.md`. Each transition returns `ok, newState` or `false, reason`.
- [ ] **2.2** Add timeout helpers: request expiry (180 s), accepted expiry (600 s).
- [ ] **2.3** Create `tests/test_state.lua` covering every valid transition, every rejected transition (including wrong sender), and both timeouts.

### Protocol extensions
- [ ] **2.4** Add message types `REQ`, `ACC`, `DEC`, `ARR`, `DONE`, `CAN`, `PING` to `Protocol.lua` with tests.
- [ ] **2.5** Enforce the sender rules: only the named driver sends `ACC`, `DEC`, `ARR`, `DONE`; only the passenger sends `REQ`; either side sends `CAN`.
- [ ] **2.6** Implement the abuse controls: drop duplicate `reqId`, limit `REQ` to 3 per sender per minute.

### Requests module
- [ ] **2.7** Create `Requests.lua`: `Create`, `Accept`, `Decline`, `Cancel`, `MarkReady`, `Complete`. Each one validates state, sends the message, and updates local state.
- [ ] **2.8** Generate `reqId` from the character GUID short form and `MySummonCharDB.requestSeq`.
- [ ] **2.9** Add a 60-second cooldown per target after decline or cancel.
- [ ] **2.10** Fire callbacks on every state change so UI can update without polling.

### Passenger flow
- [ ] **2.11** Add a "Request summon" button on each Warlock row in the dashboard. Include an optional note field (max 60 characters).
- [ ] **2.12** Show an active request panel with the current state, time remaining, and a Cancel button.
- [ ] **2.13** Send a whisper to the Warlock when a request is created, using the request template in `Locale/enUS.lua`.
- [ ] **2.14** Play a sound and show an alert when the Warlock accepts, declines, or marks ready.

### Driver flow
- [ ] **2.15** Create `UI/Driver.lua`: a queue panel with incoming requests showing requester, zone, estimated distance, note, and Accept and Decline buttons.
- [ ] **2.16** Auto-decline incoming requests when the service rules say so: in combat, dead, in an instance, outside allowed zones, or below minimum level.
- [ ] **2.17** Accept sends `ACC` and a whisper using the accept template.
- [ ] **2.18** "On my way" action: sets a map waypoint to the requester's last broadcast position (if the map API allows it; otherwise show coordinates in text).

### Summon button
- [ ] **2.19** Create `Summon.lua`: a secure action button that casts the summon spell on click. Set its attributes out of combat only.
- [ ] **2.20** Before enabling the button, check: not in combat, alive, not in instance, job state is ACCEPTED or READY, and the spell is known. Show the reason when disabled.
- [ ] **2.21** When the Warlock presses the button, mark the job READY and send `ARR`. The Warlock still clicks the in-game summon process themselves; the addon does not automate it.

### Completion and expiry
- [ ] **2.22** "Mark complete" button sends `DONE` and moves the job to COMPLETED. The passenger sees a completion alert.
- [ ] **2.23** Timeouts send nothing over the network. Each client expires its own copy and records EXPIRED.
- [ ] **2.24** Log every job (role, other party, zone, state, timestamps) to `MySummonCharDB.history`, capped at 500.

### Settings
- [ ] **2.25** Driver service rules in the Settings panel: zones served, minimum level, auto-decline options.
- [ ] **2.26** Whisper template editor with defaults and a reset button.

## Acceptance criteria

- Full happy path works with two accounts: request, accept, ready, complete. No stuck states.
- Declining, cancelling, and timing out each leave both clients in a terminal state.
- Summon button cannot be pressed in combat, while dead, or in an instance, and shows why.
- No summon is cast by code. Verify by reviewing the summon path and by testing that the button does nothing when clicked from code.
- `tests/test_state.lua` and `tests/test_protocol.lua` pass.
- 20 consecutive requests across a 30-minute session produce no Lua errors and no duplicate job records.

## Out of scope

- Ratings (Phase 3)
- Blocklist UI (Phase 3)
- Waypoints beyond the basic pin (Phase 4)
