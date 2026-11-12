# MySummon

A free World of Warcraft addon that connects players who need a summon with nearby Warlocks who can provide one.

- **Passengers** see available Warlocks nearby, send a summon request, track it, and rate the service.
- **Warlocks** go online, receive a queue of requests, accept one, navigate to the requester, cast the summon, and complete the job.

No real money, no payments, no external servers. Everything runs inside the game client.

## Project layout

```
MySummon/
  README.md              this file
  CLAUDE.md              working rules for Claude Code (read first)
  docs/
    CONCEPT.md           product concept and feature list
    ARCHITECTURE.md      modules, data, load order
    PROTOCOL.md          addon message format and request state machine
    COMPLIANCE.md        what the addon may and may not do (Blizzard rules)
  phases/
    PROGRESS.md          status tracker across all phases
    PHASE-00-spike.md    verify APIs on the live client
    PHASE-01-core-presence.md
    PHASE-02-requests.md
    PHASE-03-trust-safety.md
    PHASE-04-polish-release.md
    PHASE-05-later.md
  addon/MySummon/        the addon itself (folder name must match the .toc)
```

## How to use this with Claude Code

1. Open this folder in Claude Code.
2. Start with `phases/PHASE-00-spike.md`. Do not start Phase 1 until Phase 0's acceptance criteria are met.
3. Work one phase at a time. After each phase, update `phases/PROGRESS.md`.
4. Before you begin, confirm the open decisions in `docs/CONCEPT.md` (client version, final name, Interface number).
