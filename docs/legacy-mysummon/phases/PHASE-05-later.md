# Phase 5: Later features

**Goal:** Features that make the service richer after the public release. Each item is a separate mini-phase, prioritized from beta feedback.

**Depends on:** Phase 4 released.

Do not start any item until its design is written in `docs/` and its acceptance criteria are agreed with the user.

## 5.1 Scheduled availability
- [ ] Weekly schedule per Warlock (days and time ranges), stored in `MySummonCharDB`.
- [ ] Auto online and offline based on the schedule. Warlock can override manually.
- [ ] Schedule is broadcast as a short field in `HELLO` (keep it under the message limit).

## 5.2 Group summon mode
- [ ] Passenger can request a summon for a whole party or raid group, with a count.
- [ ] Driver sees the group count on the request card.
- [ ] Must respect the game's own group rules for the summon. Verify in Phase 0 results before building.

## 5.3 Warlock profiles
- [ ] Profile: languages (from a fixed list), short bio (max 120 characters), service notes.
- [ ] Profile is broadcast in a versioned message or fetched on demand by whisper.
- [ ] Profile is readable from the Warlock row. Reporting a profile uses the same report guidance as Phase 3.

## 5.4 Guild and friend preference
- [ ] Sort order option: guildmates and friends first, then everyone else.
- [ ] Optional filter: guild or friends only.
- [ ] Use the game's own guild and friend lists. Do not store copies beyond what the sort needs.

## 5.5 Personal statistics
- [ ] Statistics panel: jobs per week, average rating, response time (time from REQ to ACC), completion rate.
- [ ] All statistics are local, computed from history. No data leaves the client.

## 5.6 Accessibility and themes
- [ ] Theme options (light and dark, plus a high-contrast mode).
- [ ] Review against WCAG-style contrast targets for all panels.

## Release notes process for Phase 5

For each item:
1. Write a short design note in `docs/` with the protocol changes (if any).
2. If the protocol changes, bump the prefix only for breaking changes, and document it in `PROTOCOL.md`.
3. Test with beta users before release.
