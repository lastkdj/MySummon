# Phase 3: Trust and safety

**Goal:** Make the service trustworthy. Ratings, blocklist, favorites, job history, and abuse controls. Ready for a closed beta.

**Depends on:** Phase 2 passed.

## Tasks

### Ratings
- [ ] **3.1** Create `Ratings.lua`. After a job is COMPLETED, the passenger can rate the Warlock 1 to 5 stars.
- [ ] **3.2** Send `RATE` with the `reqId`. The Warlock side only accepts a `RATE` for a job it completed, and only once per `reqId`.
- [ ] **3.3** Store the rating in `MySummonDB.ratingCache` as `{ total, count }`. Include the job count in the average shown.
- [ ] **3.4** Broadcast the Warlock's own rating and job count in `HELLO` (fields already reserved in Phase 1).
- [ ] **3.5** Display "4.8 (132 jobs)" on each Warlock row. Show "New" for fewer than 3 jobs instead of an average.
- [ ] **3.6** Reject ratings from the same character more than once per `reqId`, and reject ratings for jobs the passenger did not take part in.

### Blocklist and favorites
- [ ] **3.7** Add "Block" and "Favorite" actions to each Warlock row and to driver request cards.
- [ ] **3.8** Blocked players are dropped on incoming `HELLO`, `REQ`, and any other message. Blocked players are also removed from the visible list.
- [ ] **3.9** Favorites sort to the top of the Warlock list.
- [ ] **3.10** A blocklist management panel in Settings: list, add by name, remove.
- [ ] **3.11** When a blocked player sends a request, auto-decline silently. Do not notify the sender.

### Abuse and spam controls
- [ ] **3.12** Cooldown per target after decline or cancel (from Phase 2) is visible to the passenger as a countdown.
- [ ] **3.13** Global rate limit on outgoing whispers per character (suggest max 10 per 5 minutes). Show a message when the limit is reached.
- [ ] **3.14** Show a "Report" action that opens the in-game report flow where available, and otherwise shows instructions. Do not attempt to submit reports from the addon.

### Job history
- [ ] **3.15** History panel: list of past jobs with role, other party, zone, state, rating, and date. Filter by role.
- [ ] **3.16** Warlock earnings are not tracked. The service is free, so only job counts appear.
- [ ] **3.17** Allow clearing history, with a confirmation prompt.

### Consistency and recovery
- [ ] **3.18** On login, reload any active job from SavedVariables. Expire it if its timeout has passed.
- [ ] **3.19** On zone change or logout during an active job, send `CAN` with reason `left_zone` or `logout` where possible. Record the job as FAILED locally if the other side is unreachable.
- [ ] **3.20** Create a debug command `/mysummon state` that prints all active jobs and their states, for troubleshooting.

### Beta readiness
- [ ] **3.21** Create a beta test checklist in `phases/PHASE-03-beta-checklist.md` with the scenarios from the acceptance criteria below.
- [ ] **3.22** Create a bug report template for testers that asks for the output of `/mysummon debug` and `/mysummon state`.

## Acceptance criteria

- A completed job can be rated once, and the rating shows on the Warlock row with the correct job count.
- A blocked player's messages and requests are ignored on both sides.
- Spam cooldown and whisper rate limit work and are visible to the user.
- A reload during an active job restores or expires it correctly.
- Beta checklist is complete and at least 20 scripted jobs pass across 3 testers.

## Out of scope

- Public release (Phase 4)
- Localization beyond English
