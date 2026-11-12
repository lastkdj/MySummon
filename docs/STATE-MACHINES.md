# Summon Network: State machines

## Customer booking (implemented in `Queue.lua`, mutated only by the coordinator)

```
REQUESTED --ack--> AWAITING_INVITE --invite--> INVITED --joined--> IN_GROUP --promote--> ASSIGNED <-> WAITING
   ^ owner assigned & confirmed        (roster) any of the three ^        (head of city queue = ASSIGNED)
                                                                              |
                                                                  begin (secure button click)
                                                                              v
   PAID <--paid/markpaid/free/unpaid-- PAYMENT_PENDING <--arrived-- SUMMONED <--summoned-- SUMMONING
   (terminal)                                          (roster zone / distance / trade window)   abort -> ASSIGNED
 
 Any active state --cancel--> CANCELLED (terminal)     any active state --noshow--> NO_SHOW (terminal)
 IN_GROUP..PAYMENT_PENDING --left--> DISCONNECTED --back--> previous state     DISCONNECTED/NO_SHOW/CANCELLED --requeue--> REQUESTED
```

| State | Meaning | Who/what moves it on |
|---|---|---|
| Requested | Registered; owner not yet confirmed | owner `ack` |
| Awaiting invite | Owner confirmed; customer not invited | Invite button / auto-invite |
| Invited | Invitation sent | roster shows customer in group (or 180 s -> No-show) |
| In group | Customer in the raid/party | coordinator promotes |
| Assigned | Head of the city queue; owner can summon | owner clicks Summon |
| Waiting | Behind another customer of the same city | promoted when the one ahead is `SUMMONED` or gone |
| Summoning | Ritual started (portal up) | cast succeeded -> Summoned; cast failed/90 s -> back to Assigned |
| Summoned / awaiting arrival | Customer must accept | arrival detected (or 240 s -> No-show) |
| Payment pending | Customer at destination | completed trade >= price -> Paid; short trade stays pending |
| Paid / completed | `pay` = `paid`, `free` or `unpaid` (written off) | terminal |
| Cancelled / No-show | Ended without completion | terminal; can be requeued |
| Disconnected | Customer left the group | returns -> previous state; 180 s -> No-show |

Events accepted from the network: `ack invite begin abort summoned arrived paid markpaid unpaid free discount cancel noshow
requeue reassign redirect msg`. Internal only: `joined left back promote`.

Authorisation: owner (own booking), managers / group leader / coordinator (any), any member for `invite` and `msg`.
Payment events are applied only if the sender is the owner or an authorised manager.

## Warlock station

`available` (takes new customers) / `busy` (finishes current jobs, receives none) / `offline` (receives none; bookings still
unfinished by an offline owner are reassigned). A Warlock is also excluded from rotation when stale (35 s no heartbeat),
when `requireShards` is on and shards = 0, or when standing at a different `dest`.

## Team readiness (per city)

`READY` = at least 3 live Warlocks at the city and one available; `NEEDS n MORE`; `NO ONE AVAILABLE`; `NO TEAM`. A city is
**advertised** only when it is enabled and has an available Warlock.

## Coordinator

`COORDINATOR` (highest rank live member, does all mutation, timeouts, roster sync, assignment) or `CLIENT`.
Transition is purely a function of the live member list (see ARCHITECTURE section 4).
