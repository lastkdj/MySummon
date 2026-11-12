# Summon Network: Addon message protocol (prefix `SNET1`)

Wire format: `TYPE|seq|field|field|...|mac`. Fields are percent-escaped (`%`, `|`, control chars), so they never contain
a pipe. Maximum length 250 bytes (client limit 255). `seq` is per sender and time-seeded; receivers keep a window of the
last 128 values per sender and drop repeats. `mac` is the first 12 hex chars of a keyed hash over
`key + sender + body` (`-` when no key is configured). Unknown types are ignored; unknown major versions use another prefix.

| Type | Sender | Fields | Processed by | Purpose |
|---|---|---|---|---|
| `HI` | any | ver, dest, status, shards, load | all | Heartbeat / presence (every 10 s and on change) |
| `NEW` | any | customer, dest | coordinator | Register a customer who whispered this Warlock |
| `EVT` | any | bookingId, event, arg | coordinator | Request a state change (checked for authorisation) |
| `BK` | coordinator | id, v, cust, dest, owner, ack, state, ps, pay, price, got, recv, created, begun, done, msgs | all | Authoritative booking record |
| `SYNC` | any | - | coordinator | Ask for config + all bookings (join / reload / coordinator change) |
| `DST` | coordinator | key, name, price, zone, aliases(csv), enabled, order | all | Destination config |
| `SETDST` | leader | same as DST | coordinator | Request a destination change (accepted only from the party/raid leader) |
| `DELDST` / `SETDEL` | coordinator / leader | key | all / coordinator | Remove a destination |

Acceptance rules: a `BK`/`DST` is accepted only from the node the receiver currently believes is coordinator (a higher-ranked
sender triggers re-election first). Messages from non-members of the allow-list, with a wrong key, or with a bad checksum
are dropped and logged (`/sn debug`).

## Security limits (be honest with users)

The checksum is a simple keyed hash: it stops accidental interference and casual spoofing by people without the key. It is
**not** cryptographically strong; anyone who learns the key (every Warlock knows it) can forge messages. Use the allow-list and
manager list for defence in depth, and change the key if a Warlock leaves the network. Customers never receive addon traffic.
