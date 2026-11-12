# Summon Network: Architecture

## 1. Goals mapped to design

| Requirement | Design answer |
|---|---|
| Customers install nothing | Customers only ever send/receive normal whispers. All coordination is Warlock-to-Warlock addon messages. |
| Any Warlock can take the whisper | Every Warlock parses `inv <city>` whispers and forwards `NEW` to the coordinator. |
| One customer, one summoner | Coordinator de-duplicates by customer name and assigns exactly one owner. |
| Same Warlock summons and collects | `booking.owner` is the summoner *and* the only Warlock whose completed trade can mark the booking paid. |
| Multi-city from v1 | Destinations are data (`dests`), every queue/assignment/ad is keyed by destination. 3, 9 and 12 Warlock layouts differ only in how many members share a `dest`. |
| Recover from disconnects | Every client keeps a full replica; deterministic coordinator election; `/reload` snapshot; SYNC on (re)join. |

## 2. Modules

```
                +--------------------- pure Lua (unit tested, no WoW API) ---------------------+
 whisper  --->  | Parse     "inv ogr" -> destination key                                      |
                | Protocol  encode/decode, escaping, keyed checksum                            |
                | Queue     booking state machine (events -> states)                           |
                | Engine    members, election, replication, assignment, timeouts, queries     |
                | Ads/Stats ad text, analytics                                                |
                +-----------------------------------------------------------------------------+
 WoW glue:  Compat (API wrappers)  Groups (roster, invite rights, arrival)  Net (channels+throttle)
            Whispers (customer I/O, invites)  Trade (read-only payment verification)
            Summon (secure button)  Config (SavedVariables)  Core (events, tick)  Slash
 UI:        Kit (widgets)  Dashboard (5 tabs + compact)  Minimap
```

Rule: **UI never mutates bookings.** It calls `engine:Do(id, event, arg)`. Only the coordinator mutates; everyone else
requests, then receives the new record.

Load order is the `.toc` order: Locale, Util, Parse, Protocol, Queue, Engine, Ads, Stats, Config, Compat, Groups, Net,
Whispers, Trade, UI/Kit, Summon, UI/Dashboard, UI/Minimap, Slash, Core.

## 3. Data

`SummonNetworkDB` (account-wide): `key`, `managers`, `members` (allow-list), `dests` (cached network config), `msgs`
(customer templates), toggles, `ledger` (final transaction records, capped at 2000), ad settings, minimap angle.

`SummonNetworkCharDB` (per character): this Warlock's `dest` and `status`, UI position/tab/compact flag, `session`
(snapshot of active bookings for `/reload` recovery).

**Booking record** (replicated): `id, v, cust, dest, owner, ack, state, ps, pay, price, got, recv, created, begun, done, msgs`.
`v` is a per-booking version; a client only accepts a record with a higher `v`. `msgs` is a bit set of customer
whispers already sent, so no whisper is ever repeated, even after a coordinator change. `price` is fixed at booking
time. Timeouts use locally observed times (`sat`, `lseen`), never remote clocks.

## 4. Synchronisation

* **Transport:** `RAID` / `PARTY` addon messages (or `GUILD` in guild mode). The 9- and 12-Warlock layouts therefore need
  all Warlocks in one raid (or a shared guild). Messages are throttled (6/s, burst 10) in `Net.lua`.
* **Membership:** every Warlock sends `HI` every 10 s (dest, status, soul shards, load). Silent for 35 s = offline.
* **Coordinator election (no voting):** every node computes the same answer from the live member list:
  `rank = group leader first, then manager-list position, then name`. Lowest rank wins. Ties cannot occur (names are unique).
  The coordinator changes automatically when it goes silent or a better-ranked member joins.
* **Requests:** non-coordinators send `NEW` (new customer) and `EVT` (state change). The coordinator validates
  authorisation and the state machine, bumps `v`, and broadcasts `BK`.
* **Assignment:** coordinator picks the next available member of the destination in alphabetical rotation (pointer kept
  per destination, rebuilt from history after fail-over). Candidates must be live, `available`, and (optionally) hold at
  least one Soul Shard. The owner confirms with `ack`; if no ack within 15 s the next candidate is tried.
* **Duplicate protection:** transport (per-sender seq window of 128), customer (one active booking per name), booking IDs
  (`base36(time)+random`, collision-checked), whispers (`msgs` bits + local sent set).
* **Recovery:** new/rejoining nodes send `SYNC`; coordinator replies with config and bookings. After a coordinator death the
  next-ranked node already holds every booking, re-broadcasts them, rebuilds the rotation pointer and reassigns bookings
  whose owner is dead. A split brain (two coordinators) merges: lower-ranked node's unknown bookings are adopted by the
  winner, duplicate-customer bookings resolve to the older one.

## 5. Raid coordination and cross-city routing

* One raid holds all teams. Teams are *logical* (members sharing `dest`), not raid subgroups, so no protected raid
  rearrangement is needed.
* `inv uc` received by an Orgrimmar Warlock: `Whispers.OnWhisper` -> `Engine:Register` -> coordinator creates the booking
  for `uc` and picks an Undercity Warlock. The receiving Warlock sends the first two whispers ("requested", "your summoner
  is X"); the owner sends the rest.
* Invites: the receiving Warlock (or owner) gets an alert and a one-click **Invite** button (optional auto-invite).
  A party caps at 5, so the dashboard shows **To raid** for the leader. Raid cap is 40; the addon warns when full.
* Summoning is serial per city: only the head of a destination queue is `ASSIGNED`; the rest are `WAITING`. Different
  cities summon in parallel. Teammates of the summoner are alerted to click the portal.
* Group leadership: **only the party/raid leader can edit prices, aliases and destinations**. The leader or any listed
  manager can also reassign, redirect, cancel and mark paid on behalf of a Warlock.

## 6. Security model

Shared **network key** (`/sn key`): each message carries a keyed checksum bound to the sender name, so a customer or
stranger in the raid cannot forge `EVT`/`BK`. Optional allow-list of Warlock names. Only owner/manager/leader may drive a
booking. See `PROTOCOL.md` for limits (the checksum is not cryptographic).
