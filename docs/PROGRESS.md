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

Automated: `lua tests/run.lua` 419 checks pass; `luacheck .` clean.

## Decisions

* 2026-11: Product renamed **Summon Network** (colleague's concept supersedes the passenger/driver "MySummon" concept; old docs in `docs/legacy-mysummon/`).
* Hard rules updated: gold/silver prices are in scope; real money, automation of casting/trading/posting remain forbidden (see `CLAUDE.md`).
* Teams are logical (shared `dest`), not raid subgroups, to avoid protected raid rearrangement.
* Auto-invite defaults OFF (may be restricted); one-click Invite and chat-box prefill fallback.
* Network authentication = shared key checksum + optional allow-list (not cryptographic).
* Single coordinator, deterministic election, full replication on every client.

## Unverified (needs live client check): see API-NOTES.md

Interface number; every WoW API in the table; the Ritual of Summoning rules (3 participants, subgroup restriction, target
must be in group, shard cost); arrival detection; trade event order; whether event-driven whispers/invites are allowed;
visual layout/fonts of the UI at different UI scales.

## Open questions for the owners

1. Which client exactly is "WoW: Forever" (Classic Era, progression, private server)? Needed for the Interface number and API set.
2. Are bots-replying-by-whisper and gold-for-service permitted on that server?
3. Do you want prices/aliases editable by every Warlock, or only managers (current: managers/leader only)?
4. Should finished customers be removed from the raid automatically (currently a manual menu action)?
5. Localisation beyond English (customers may whisper in other languages: add aliases).
