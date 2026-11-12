# CLAUDE.md: working rules for Summon Network

Read this before writing any code in this project.

## What we are building

**Summon Network** is a free WoW addon (target client: "WoW: Forever", unverified) used by a network of Warlocks who sell
summons for **in-game gold/silver**. Customers need no addon: they whisper `inv <city>` and are routed to the right Warlock
team. Warlocks coordinate through addon messages. There is no backend. Multi-city support is in version 1.

(The earlier passenger/driver concept, "MySummon", is archived in `docs/legacy-mysummon/`.)

## Hard rules (never break these)

1. **No real money.** Prices are in-game currency only. No payment code, no links to payment sites, no RMT.
2. **No automated casting.** The summon is cast only when a player clicks a secure action button. Never call protected
   spell or targeting functions from insecure code.
3. **No automated trades.** The addon only *reads* the trade window the player opens. Never initiate, edit or accept a trade.
   Never mark an order paid because gold was placed in the window: the trade must have completed.
4. **No external network.** No HTTP, no servers. All state is local plus addon messages between Warlocks.
5. **No taint.** Do not modify secure frames in combat. Keep secure and insecure logic separate.
6. **The addon is free and unmonetized.** No ads, donations or paid features in the addon. (The Warlocks' in-game gold prices are theirs.)
7. **No spam.** Trade-chat advertisements are prepared by the addon and posted by the player (they press Enter). Customer
   whispers are only replies to inbound whispers or booking milestones, de-duplicated and rate-limited.
8. **No Blizzard or Uber marks.** Product name is Summon Network.

If a task would break one of these rules, stop and ask the user before continuing.

## Technical conventions

- Lua 5.1 (WoW dialect). No `goto`, `//`, `continue`, bit operators.
- Every WoW API is reached through `Compat.lua` (`SN.API`) or guarded; a missing function must degrade to a manual fallback.
  Never invent API behaviour: record it in `docs/API-NOTES.md` under "Unverified" until checked with `/sn diag` on the live client.
- Pure logic (Util, Parse, Protocol, Queue, Engine, Ads, Stats) must not touch WoW globals so it stays testable with `lua tests/run.lua`.
- UI files never mutate bookings: they call `SN.engine:Do(...)`. Only the coordinator mutates state.
- Addon message prefix `SNET1`, messages < 250 bytes, throttled in `Net.lua`.
- SavedVariables: `SummonNetworkDB` (account) and `SummonNetworkCharDB` (per character) only.
- The `.toc` lists every file in load order. Run `luacheck .` (config in `.luacheckrc`) and `lua tests/run.lua` before finishing.

## Definition of done

- `lua tests/run.lua` passes (from `addon/SummonNetwork`), `luacheck .` clean
- Anything not verifiable offline is listed in `docs/PROGRESS.md` under "Unverified"
- `docs/` updated when behaviour or protocol changes
