# Installation and configuration

## Install (every Warlock)

1. Copy the `SummonNetwork` folder (from `addon/`, or unzip the output of `tools/package.sh`) into
   `World of Warcraft/<client folder>/Interface/AddOns/`. The folder name must be exactly `SummonNetwork`.
2. Start the game. If the addon shows as out of date, tick **Load out of date AddOns**, run `/sn diag`, and put the Interface
   number it prints into `SummonNetwork.toc`.
3. Customers install nothing.

## First-time configuration (same on every Warlock)

```text
/sn diag                       check that the client supports everything (read the red lines)
/sn key <shared phrase>        same phrase on all Warlocks (authenticates addon messages)
/sn manager add <Name>         optional: ordered list of network managers; the first live one coordinates
/sn member add <Name>          optional allow-list of Warlock names (add every Warlock)
/sn city ogr                   the city YOU are standing in (ogr, uc, tb or your own)
/sn price ogr 30s              prices accept 30s, 1g, 1g 5s, 50c ...
/sn available                  start taking customers
```

Everything above is also available in the dashboard **Setup** tab. Destination prices, aliases and zone names are
network configuration: the coordinator's copy wins, and only managers / the raid leader may change it.

## Forming the network

1. One Warlock creates the group and invites the other Warlocks (3 Warlocks = party; 9 or 12 need a raid: use **To raid**).
2. Each Warlock selects their city (`/sn city uc`, or **Cities** tab -> *I'm here*) and sets `/sn available`.
3. Check **Cities**: each team should show READY 3/3.
4. Post the ad: `/sn ad` (or **Advertise** tab) fills the chat box with the Trade-channel ad; **you** press Enter.
5. Customers whisper `inv ogr` etc. The addon registers them, tells them who their summoner is, and highlights **Invite**.

## Daily use

* **Queue** tab: customers grouped by city, with status pill, summoner, price and one primary button per row
  (Invite -> Select -> Arrived -> Mark paid). The `...` menu has reassign, change destination, discount, free, write-off,
  re-invite, remove from group, requeue and cancel.
* **Footer**: your status, your city, soul shards, your next customer, the secure **SUMMON** button (cast is your click),
  *Mark Paid*, *Remind*, *Reassign*, *Cancel*, *Compact*.
* **Compact mode** (`/sn compact` or the `_` button): a small panel with only your next customer, Summon and Paid.
* **Stats** tab: revenue, per city and per Warlock, wait time, cancelled/no-show, unpaid. Toggle session / all time.

## Customer commands they can send

`inv ogr`, `inv org`, `inv orgrimmar`, `INV UC`, `inv thunder bluff`, `invite tb please`. Add aliases with
`/sn alias ogr add orgy` or in **Setup**. Customer whisper texts are editable in **Setup** (placeholders `{dest} {price}
{pricelong} {owner} {pos} {cust} {list}`).

## Troubleshooting

* Nobody sees each other: same `/sn key` everywhere? Everyone in the same party/raid (or `/sn channel guild`)? `/sn members`.
* Customers get no replies: `/sn debug` shows failed whispers; check "Whisper customers" in Setup.
* Wrong coordinator: set `/sn manager add` identically on all Warlocks.
* After a crash: `/reload` restores your active bookings; the coordinator re-syncs the rest within seconds.
