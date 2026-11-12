# MySummon: Compliance

This document lists what MySummon may and may not do. Check it before adding any feature. Verify current rules before release.

## Sources to check before each release

- Blizzard Terms of Service
- Blizzard Add-On Policy
- Current API documentation (warcraft.wiki.gg and Blizzard's API docs)
- Patch notes for any change to addon communication or combat restrictions

## Allowed

| Area | Allowed behavior |
|---|---|
| Summoning | The player clicks a secure button to cast the spell |
| Discovery | Addon users broadcast presence over addon messages and channels |
| Messaging | Whispers and addon messages, rate-limited and not spammy |
| Waypoints | Map pins set by the player's own action |
| Tips | Suggested tip shown as text, paid manually in-game by the player |
| Interface | Frames, Settings panel, minimap button, keybinds, sounds |

## Not allowed

| Area | Reason |
|---|---|
| Real-money payments, gold sales, RMT | Violates Terms of Service |
| Automatic spell casting or targeting of other players | Protected actions; automation |
| Automatic trades or moving gold | Money handling is manual only |
| External servers, websites, HTTP calls | Not possible in addon sandbox; out of scope |
| Spam whispers or mass unsolicited messages | Abuse; can get the addon reported |
| Reading or storing personal data beyond name and realm | Privacy |
| Claiming endorsement by Blizzard, or using Blizzard logos | Trademark |
| Using the Uber name or logo | Trademark |

## Free-product rules

- No donation buttons, paid tiers, ads, or affiliate links.
- If that changes, this document must be reviewed against the Add-On Policy first.

## Privacy

- Store only character name and realm.
- Do not record chat logs.
- Do not transmit data outside the game client.

## Reporting abuse

The addon cannot file reports with Blizzard. The settings panel should link players to the in-game report feature and explain how to use it.

## Review checklist (run before each beta or release)

- [ ] No payment or money-related text or code
- [ ] No automated casting or trading
- [ ] No network calls outside the game
- [ ] No Blizzard logos or the Uber name
- [ ] Message rate limits enforced
- [ ] Blocklist enforced on incoming messages
