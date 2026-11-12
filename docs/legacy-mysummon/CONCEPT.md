# MySummon: Concept

## Summary

MySummon is a free addon that helps players find a nearby Warlock to summon them, and helps Warlocks find players who need a summon. It is a request-and-accept service, like a ride-hailing app, but it runs inside the game with no money involved.

## Goals

- Players can find an available Warlock nearby within seconds.
- Warlocks can see and accept requests without leaving their current activity.
- Every request has a clear status from start to finish.
- Bad actors are easy to block, and reputation is visible.
- It is free, transparent, and respects Blizzard's rules.

## Non-goals

- No real-money payments, gold sales, or RMT
- No automatic casting, trading, or moving characters
- No external servers, accounts, or websites
- No replacement for the Ritual of Summoning mechanic itself

## Roles

| Role | Name in UI | Description |
|---|---|---|
| Player who needs a summon | Passenger | Browses nearby Warlocks, sends requests, rates service |
| Warlock who provides it | Driver | Goes online, handles request queue, summons, completes jobs |

## Feature list

### MVP (Phases 1 and 2)
- Presence broadcast: addon users announce themselves and their status
- Passenger dashboard: list of nearby Warlocks with status, zone, rating, suggested tip
- Request flow: request, accept, decline, cancel, complete, with expiry
- Driver queue: incoming requests with requester zone, estimated distance, note
- Warlock online toggle and service rules (zones, minimum level, auto-decline in combat or while dead, no instance summons)
- Secure one-click summon button with pre-cast checks
- Whisper templates for accept, arrival, and completion
- Sound and alert on new requests and status changes
- Settings panel, minimap button, keybinds

### Trust and safety (Phase 3)
- Ratings after each completed job (1 to 5 stars, one rating per job)
- Average rating shown with job count, so new Warlocks are not misread
- Blocklist and favorites, enforced on both sides
- Rate limits and cooldowns to stop request spam
- Job history for both roles

### Polish and release (Phase 4)
- Map waypoints to the requester's last broadcast position
- Estimated time to arrival
- Suggested tip guide (player-editable, text only)
- Localization: English first, then Spanish
- Packaging and beta release

### Later (Phase 5)
- Scheduled availability ("online Friday to Sunday, 8pm to midnight")
- Group summon mode for raids and dungeon groups
- Warlock profile: languages, bio, service notes
- Guild and friend preference (show guildmates and friends first)
- Personal statistics: jobs per week, average rating, response time
- Accessibility: colorblind-safe status colors, scalable font size

## Key limitations (be honest with users)

- Only players with MySummon installed appear in the list. There is no global lookup.
- Distance is an estimate, based on each Warlock's broadcast position in the same zone.
- Summons still depend on the game's own rules (cost, group requirements, instance rules, cooldowns).
- Ratings can be gamed. Show job counts next to averages.

## Open decisions

| Decision | Status | Owner |
|---|---|---|
| Which client: retail, Classic, or private server ("World of Warcraft Forever") | Open | User |
| Exact Interface number for the target client | Open (verify in Phase 0) | Phase 0 |
| Final name (MySummon) | Decided | User |
| Monetization | None (free) | User |
| Localization languages beyond English and Spanish | Open | User |

## Success measures

- A request-to-accept round trip works in under 10 seconds between two test accounts.
- No Lua errors across a 30-minute test session with 5 or more simultaneous users.
- Beta testers complete at least 20 jobs with no unrecovered state errors.
