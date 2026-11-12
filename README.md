# Summon Network

A multi-city Warlock summoning network for World of Warcraft (target: **WoW: Forever**, client 1.60.1, Interface 16001). Customers pay in-game gold/silver;
they need **no addon**. Warlocks install the addon and get a shared queue, automatic round-robin assignment, trade-based
payment tracking, customer whispers, a Trade-chat ad builder and business statistics.

```
Customer whispers "inv uc"  ->  any Warlock receives it  ->  network registers ONE booking
   ->  coordinator assigns ONE Warlock in the Undercity team (round robin)
   ->  customer is invited, summoned (Ritual of Summoning, player-clicked), trades gold
   ->  the same Warlock's completed trade marks it paid  ->  every Warlock sees the result
```

## Repository layout

```
addon/SummonNetwork/     the addon (copy this folder into Interface/AddOns)
  SummonNetwork.toc      manifest and load order
  Util / Parse / Protocol / Queue / Engine / Ads / Stats .lua   pure logic, unit-tested
  Config / Compat / Groups / Net / Whispers / Trade / Summon / Core / Slash .lua   WoW integration
  UI/Kit / Dashboard / Minimap .lua                                      interface
  Locale/enUS.lua        strings
  tests/                 headless tests + WoW API mock (not shipped)
docs/
  ARCHITECTURE.md        modules, data, sync, raid coordination, cross-city routing
  STATE-MACHINES.md      customer, Warlock and coordinator state machines
  PROTOCOL.md            addon message reference and security model
  API-NOTES.md           client restrictions, fallbacks, UNVERIFIED list
  INSTALL.md             installation and configuration
  TESTING.md             live test checklists for 3, 9 and 12 Warlocks
  COMPLIANCE.md          what the addon may and may not do
  PROGRESS.md            status, decisions, open questions
  legacy-mysummon/       earlier passenger/driver concept (archived)
tools/package.sh         builds SummonNetwork-<version>.zip for distribution
```

## Quick start

1. Copy `addon/SummonNetwork` to `World of Warcraft/<client>/Interface/AddOns/` on **every** Warlock.
2. In game: `/sn diag`, then `/sn key <shared phrase>`, `/sn city <ogr|uc|tb>`, `/sn`.
3. Read `docs/INSTALL.md` and `docs/TESTING.md`. Several mechanics are **unverified** on WoW: Forever: see `docs/API-NOTES.md`.

## Developing

```bash
cd addon/SummonNetwork
lua tests/run.lua     # 426 checks: protocol, state machine, 3/9/12-Warlock network simulation, headless UI smoke test
luacheck .
```
