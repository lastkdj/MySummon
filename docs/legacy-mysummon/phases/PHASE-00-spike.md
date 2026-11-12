# Phase 0: Spike (verify the APIs on the live client)

**Goal:** Prove that the core mechanics work on the target client before building anything else. Nothing here ships to players.

**Why first:** Discovery, messaging, and the summon button all depend on API behavior we have not verified. If any of these fails, the design changes.

## Scope

Build a throwaway addon `addon/MySummon/` with a minimal `.toc` and a test `Core.lua`. Keep the spike code in a `spike/` branch or folder if you want to keep it.

## Tasks

- [ ] **0.1** Confirm the client version and the correct `## Interface:` number. Record it in `PROGRESS.md`.
- [ ] **0.2** Create a minimal addon that loads with no errors. Print a message on `PLAYER_LOGIN`.
- [ ] **0.3** Register the addon message prefix `MYSUM1` and confirm the return value.
- [ ] **0.4** Send and receive an addon message via `PARTY`. Measure delivery with two characters in one group.
- [ ] **0.5** Send and receive via a joined public or custom chat channel (for discovery across the zone). Test with two accounts in the same city. Record whether the channel works, what the channel name rules are, and whether joining silently is allowed.
- [ ] **0.6** Measure the outgoing message limit. Send 50 messages in a burst and record which are dropped or delayed.
- [ ] **0.7** Read the player's own map position (`C_Map` APIs). Confirm the values update when moving and that they can be broadcast and read by another client.
- [ ] **0.8** Confirm the zone name and map ID can be read for the player and for remote players sent via addon message.
- [ ] **0.9** Create a secure action button that casts the summon spell when clicked (out of combat). Confirm it fires from a hardware click and does not fire from code.
- [ ] **0.10** Confirm the pre-cast checks are readable: in combat, dead, in instance, in group, and whether the spell is known.
- [ ] **0.11** Create a Settings panel using the Settings API with one checkbox. Confirm it persists in `MySummonDB`.
- [ ] **0.12** Test `/reload` persistence of SavedVariables.
- [ ] **0.13** Check same-faction and cross-realm behavior for addon messages and summons. Record the results.
- [ ] **0.14** Check whether any combat-time restrictions apply to addon messages or the information we plan to read. Record the results.

## Acceptance criteria

- `docs/spikes/PHASE-0-RESULTS.md` exists and records a pass or fail with evidence for every task above.
- Each failed item has a proposed change to the design (in `docs/PROTOCOL.md` or `docs/ARCHITECTURE.md`).
- The Interface number, prefix, channel approach, and summon-button approach are confirmed or replaced.
- Phase 1 cannot start until the discovery approach (0.4 to 0.5) passes.

## Out of scope

- Any UI beyond a test button
- Ratings, history, or any game logic
- Localization
