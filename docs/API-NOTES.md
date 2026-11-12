# Client API restrictions, fallbacks and the UNVERIFIED list

**Honesty first:** this repository was built without access to a WoW: Forever client. "WoW: Forever" has not been
identified as Classic Era, a Classic progression server or a private server. Everything below marked **UNVERIFIED** is a
design assumption that `/sn diag` and `docs/TESTING.md` section A must confirm in game. All client calls go through
`Compat.lua` / guarded `pcall`s so a wrong assumption degrades to a manual step instead of a Lua error.

| # | Area | What the addon does | Status | Safe fallback if it fails |
|---|---|---|---|---|
| 1 | Interface number | `.toc` lists `11507, 20504, 30403, 40402` | UNVERIFIED | `/sn diag` prints the right number; edit the `.toc` |
| 2 | Addon messages (`RegisterAddonMessagePrefix`, `SendAddonMessage` on `RAID`/`PARTY`/`GUILD`, `CHAT_MSG_ADDON`) | Whole sync layer | UNVERIFIED (standard on all Classic clients) | Guild mode (`/sn channel guild`); solo mode still works |
| 3 | Message throttle | Token bucket 6/s, burst 10 | Conservative guess | Lower `RATE` in `Net.lua` |
| 4 | Incoming whispers (`CHAT_MSG_WHISPER`) | Customer detection | UNVERIFIED (standard) | none needed |
| 5 | Outgoing whispers from an event handler | Customer replies, 1 per 1.2 s | UNVERIFIED that no hardware event is required | If blocked, whispers fail and are logged; replies must be typed manually (set "Whisper customers" off) |
| 6 | Group invite `InviteUnit` / `C_PartyInfo.InviteUnit` | One-click button (auto-invite is OFF by default) | UNVERIFIED whether it needs a hardware click | Falls back to prefilling `/invite Name` in the chat box; you press Enter |
| 7 | Party -> raid (`ConvertToRaid`) | "To raid" button / `/sn raid` (leader) | UNVERIFIED | Convert with the default UI |
| 8 | Raid roster (`GetRaidRosterInfo`: name, rank, subgroup, zone, online) | Join/leave detection, leader, invite rights, arrival by zone | UNVERIFIED zone field behaviour | Use the **Arrived** button |
| 9 | Ritual of Summoning spell id 698, Soul Shard item id 6265 | Secure button text, shard counts | UNVERIFIED | `/sn diag` shows what the client reports; change `Compat.lua` constants |
| 10 | Summon target | Secure macro `/target raidN` + `/cast Ritual of Summoning` (unit token works for distant raid members, a name would not) | UNVERIFIED | Target the customer yourself and click the ritual |
| 11 | Ritual rules: 3 participants, target must be in your group, **subgroup restriction unknown**, shard cost | Alerts teammates to click the portal | **UNVERIFIED: test first** (TESTING A9) | If cross-subgroup summons fail, keep each team's customers in that team's subgroup manually (leader moves them) |
| 12 | Secure button and combat | Attributes only set out of combat; re-armed on `PLAYER_REGEN_ENABLED` | Standard secure-template behaviour | Button shows "In combat" |
| 13 | Trade events (`TRADE_SHOW`, `TRADE_ACCEPT_UPDATE`, `TRADE_MONEY_CHANGED`, `TRADE_CLOSED`), `GetTargetTradeMoney`, `UnitName("NPC")` for the partner, `ERR_TRADE_COMPLETE` | Paid only when: both sides accepted AND "Trade complete" message AND money actually received | UNVERIFIED | **Mark Paid** button / `/sn paid <name>` |
| 14 | Arrival detection | Raid zone == city zone, or within trade distance (`CheckInteractDistance`), or a trade with the customer | UNVERIFIED | **Arrived** button |
| 15 | Combat restrictions on addon messages / info | None expected on the intended workflow (everyone stands in cities) | UNVERIFIED for newer retail-style clients | Not applicable offline |
| 16 | SavedVariables | `SummonNetworkDB`, `SummonNetworkCharDB`; `/reload` restores active bookings | Standard | n/a |
| 17 | Trade channel number for the ad | `GetChannelList` match on "Trade" | UNVERIFIED | Ad text is printed to copy/paste |

## What the addon deliberately does NOT automate

* Casting (player clicks the secure button), targeting from insecure code, trading, moving gold, posting in Trade chat.
* Group invites are one click by default. `autoInvite` is an opt-in that is only safe if `/sn diag` + TESTING A5 show the
  client allows it without a click; otherwise the client blocks it and the addon falls back to the chat-box prefill.

## Group size limits

Party = 5 (3 Warlocks + 2 customers). Raid = 40. With 12 Warlocks that leaves 28 customer slots. Finished customers should be
removed (row menu: *Remove from group*) to free slots; the addon warns when the group is full.
