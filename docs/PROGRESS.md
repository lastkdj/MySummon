# Progress, decisions and open items

## Status (version 1.0.0)

| Area | Status |
|---|---|
| Multi-city engine: registration, round-robin assignment, queues, coordinator election and fail-over | Done, simulated for 3/9/12 Warlocks |
| Customer whisper parsing, templates, rate limiting, de-duplication | Done |
| Invites (one click, optional auto), raid conversion, remove from group | Done, **live behaviour unverified** |
| Secure summon button + pre-cast checks + helper alerts | Done, **live behaviour unverified** |
| Trade-based payment verification, manual Mark Paid/free/discount/write-off | Done, **live behaviour unverified** |
| Dashboard (Queue, Cities, Stats, Ads, Setup), compact mode, minimap, toasts | Done, **never rendered in a real client** |
| Ledger, analytics, SavedVariables, `/reload` recovery | Done |
| Documentation + test checklists (3/9/12) | Done |

Automated: `lua tests/run.lua` 426 checks pass; `luacheck .` clean.

## Decisions

* 2026-11: Product renamed **Summon Network** (colleague's concept supersedes the passenger/driver "MySummon" concept; old docs in `docs/legacy-mysummon/`).
* Hard rules updated: gold/silver prices are in scope; real money, automation of casting/trading/posting remain forbidden (see `CLAUDE.md`).
* Teams are logical (shared `dest`), not raid subgroups, to avoid protected raid rearrangement.
* Auto-invite defaults OFF (may be restricted); one-click Invite and chat-box prefill fallback.
* Network authentication = shared key checksum + optional allow-list (not cryptographic).
* 2026-11: Owner confirmed target = WoW: Forever (Interface 16001), gold-for-service and whisper replies acceptable, and network config editable only by the party/raid leader. The leader is now also the preferred coordinator.
* Single coordinator, deterministic election, full replication on every client.

## Unverified (needs live client check): see API-NOTES.md

Interface number; every WoW API in the table; the Ritual of Summoning rules (3 participants, subgroup restriction, target
must be in group, shard cost); arrival detection; trade event order; whether event-driven whispers/invites are allowed;
visual layout/fonts of the UI at different UI scales.

## Open questions for the owners

1. ~~Which client is WoW: Forever?~~ Answered: the new official WoW: Forever client (1.60.1, Interface 16001, modern engine with Midnight addon restrictions).
2. ~~Gold-for-service and whisper replies permitted?~~ Owner answer: yes.
3. ~~Who edits prices/aliases?~~ Owner answer: party leader or raid leader only (implemented).
4. Should finished customers be removed from the raid automatically (currently a manual menu action)?
5. Localisation beyond English (customers may whisper in other languages: add aliases).
