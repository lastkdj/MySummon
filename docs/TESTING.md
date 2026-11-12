# Testing

## 0. Automated (offline, run first)

```bash
cd addon/SummonNetwork && lua tests/run.lua && luacheck .
```
426 checks cover: whisper parsing (`inv ogr`, `INV OGR`, `inv org`, `inv orgrimmar`, aliases), protocol/escaping/spoofing,
every state transition, **3-, 9- and 12-Warlock network simulations** (round robin, duplicate whispers, routing across
cities, coordinator fail-over, rejoin/SYNC, authorisation, wrong-key rejection, disconnect and no-show, partial payment,
config replication, `/reload` restore) and a headless UI/glue smoke run against a WoW API mock (whisper -> invite ->
summon -> arrival -> trade -> paid, all five tabs, slash commands). Passing these does **not** prove the live-client
assumptions in `API-NOTES.md`: do section A.

## A. Live client checks (2-3 accounts, do these before anything else)

Record PASS/FAIL and evidence in `docs/PROGRESS.md`. A failed item has a fallback in `API-NOTES.md`.

| ID | Check | Pass criteria |
|---|---|---|
| A1 | `/sn diag` on each client | No red MISSING lines; note the Interface number it prints |
| A2 | Two Warlocks in a party, same `/sn key`, `/sn city`, `/sn available` | Both appear in each other's `/sn members` within 35 s |
| A3 | Same in a raid, in different subgroups and different zones | Still see each other (RAID channel works across subgroups/zones) |
| A4 | A non-addon character whispers `inv ogr` | Booking appears; the customer receives both whispers; no Lua error |
| A5 | Click **Invite** on the booking | Customer is invited. Then enable Setup -> *Auto-invite* and repeat: if the client blocks it, leave auto-invite OFF |
| A6 | Party full (5) | "To raid" button appears for the leader and converts the group |
| A7 | Customer in the raid in another zone, summoned to the city | Row moves Summoned -> Payment pending on arrival, or note that you must press **Arrived** |
| A8 | Click **SUMMON** (out of combat, customer in group, 1 shard) | Ritual starts targeting the customer; in combat the button is disabled and says so |
| A9 | Ritual with 2 teammates and a customer **in a different raid subgroup** | Teammates get the portal alert; summon works. If subgroups block it, document the rule here |
| A10 | Customer trades: (a) offers gold, cancels; (b) offers short gold, completes; (c) full gold, completes | (a) stays pending, (b) pending with "short" alert, (c) Paid, Stats revenue increases |
| A11 | `/reload` mid-job | Booking and ledger survive; no duplicate whispers |
| A12 | `/sn ad` | Chat box contains `/<trade number> WTS SUMMONS ...`; nothing is sent until you press Enter; disabled cities are absent |
| A13 | 10 customers whisper at once | Whispers arrive spaced ~1.2 s apart; no "too many messages" disconnect |

## B. 3 Warlocks, one city (party)

1. Three Warlocks in a party, all at Orgrimmar, `/sn city ogr`, `/sn available`; Cities tab shows READY 3/3.
2. Customers C1..C4 whisper `inv ogr` (vary case/aliases: `INV OGR`, `inv org`, `inv orgrimmar`).
   Expect owners rotate A, B, C, A; each customer gets "requested" then "your summoner is X"; **one** booking each.
3. Whisper two different Warlocks with the same customer name: still one booking.
4. Invite C1, C2 (party max 5). C3 must trigger the full-group / To raid prompt.
5. C1 Assigned, C2 Waiting. Summon C1: teammates see the portal alert; C2 becomes Assigned once C1 is Summoned.
6. C1 arrives: "Please trade 30 silver to <owner>" whisper once; trade completes -> Paid, "Payment received" whisper once.
7. Stats tab shows 1 completed, revenue 30s attributed to the owner. Queue and Stats identical on all three clients.

## C. 9 Warlocks, three cities (raid)

1. Raid with three teams (Orgrimmar, Undercity, Thunder Bluff); each Warlock sets its city. Cities tab: three READY teams.
2. From an **Orgrimmar** Warlock's point of view, customers whisper `inv uc`, `inv ogr`, `inv tb` to any Warlocks.
   Each booking is owned by the right city's Warlock; every client shows the same queue.
3. Invite all three customers; summon in all three cities **at the same time**; pay; verify three transactions and
   per-Warlock/per-city revenue.
4. Set one Orgrimmar Warlock `/sn busy`: new `inv ogr` skips them. Set the whole Thunder Bluff team `offline`: `inv tb`
   gets the "unavailable" whisper and `/sn ad` drops Thunder Bluff.
5. Only the raid leader can change a price or alias (Setup tab / `/sn price`): another Warlock gets a refusal.
6. Leader or a listed manager reassigns a customer (row menu -> Reassign) to another Warlock: only the new owner can collect payment.

## D. 12 Warlocks, four cities (raid)

Repeat C with a fourth city: `/sn dest add sw Stormwind "Stormwind City"` on a manager, then `/sn price sw 50s`. All clients
receive the new destination within ~10 s. Run 15-20 customers across the four cities and compare Queue/Stats on all clients.

## E. Failure drills

| Drill | Expected |
|---|---|
| Coordinator logs out mid-job | Within ~40 s another Warlock becomes coordinator (header changes); all bookings still visible; new `inv` still works; no duplicate whispers |
| Owner Warlock logs out before the customer is summoned | Booking reassigned to a live teammate (customer gets the new summoner whisper) |
| Owner logs out after summoning | Booking stays with the owner (payment is theirs); a manager can reassign |
| Customer leaves the raid | Disconnected; returning restores the state; 3 min later No-show |
| Customer ignores the invite | No-show after 3 min; **Requeue** works |
| Warlock with wrong `/sn key` | Ignored by the others; `/sn debug` shows `badmac` |
| `/reload` on any Warlock | Active bookings restored, sync within 20 s |
| 30-minute session with 5+ Warlocks | No Lua errors (`/sn debug` log), message queue length (`/sn debug`) returns to 0 |
