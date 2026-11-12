# Phase 4: Polish and release

**Goal:** A polished, localized, packaged addon ready for public release.

**Depends on:** Phase 3 passed and beta feedback reviewed.

## Tasks

### Navigation and timing
- [ ] **4.1** Improve waypoints: update the pin when the requester's broadcast position changes by more than a set distance. Remove it on completion or cancel.
- [ ] **4.2** Estimated time to arrival: distance divided by an assumed movement speed, shown as a range. Label it as an estimate.

### Tipping guide
- [ ] **4.3** Tip guide: a text-only, player-editable list of suggested tips by zone and time of day. Ship with a neutral default (empty), not prices.
- [ ] **4.4** Show the suggested tip on the request card. Never initiate a trade.

### Minimap and keybinds
- [ ] **4.5** Minimap button using LibDBIcon. Left click opens the dashboard, right click opens Settings, drag to reposition.
- [ ] **4.6** Keybindings in `Bindings.xml`: open dashboard, toggle online, open driver queue.

### Accessibility and UI
- [ ] **4.7** Status colors that also use text or icons (colorblind safe).
- [ ] **4.8** Font size option in Settings, applied to all panels.
- [ ] **4.9** Sound options: on or off per event type.
- [ ] **4.10** Review all UI for truncation at small window sizes.

### Localization
- [ ] **4.11** Move all remaining strings into `Locale/enUS.lua`. Confirm no hard-coded text remains (grep for string literals in UI files).
- [ ] **4.12** Create `Locale/esES.lua` with full translation. Fall back to English for missing keys.
- [ ] **4.13** Test both languages in the UI and in whisper templates.

### Quality and performance
- [ ] **4.14** Profile the addon with the built-in addon profiling tools. Confirm CPU use is negligible when idle.
- [ ] **4.15** Run Luacheck with WoW globals configured. Zero warnings in new code.
- [ ] **4.16** Run a 2-hour soak test with 5 or more clients. Record memory and errors.

### Packaging and release
- [ ] **4.17** Create `.pkgmeta` for the BigWigs packager. Exclude `tests/`, `spike/`, and `phases/` from the package.
- [ ] **4.18** Write the public README: what the addon does, how to use it, limitations, and how to report problems.
- [ ] **4.19** Write the release notes and changelog.
- [ ] **4.20** Run the compliance checklist from `docs/COMPLIANCE.md` and record the result.
- [ ] **4.21** Publish a beta build to one distribution site, then a full release after one week with no critical bugs.

## Acceptance criteria

- Waypoints and ETA update correctly while moving.
- Both English and Spanish display with no missing strings.
- Idle CPU and memory use are within the targets recorded in Phase 4.14.
- Package contains only the addon files, with the correct folder name and `.toc`.
- Compliance checklist is fully ticked with no unresolved items.
- At least one week in beta with no critical open bugs.

## Out of scope

- Scheduling, groups, profiles, and statistics (Phase 5)
