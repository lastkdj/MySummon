# Compliance

Check before every release and whenever the target client or Blizzard's policies change (Terms of Service, Add-On Policy,
patch notes about addon communication or combat restrictions).

| Area | Allowed behaviour in this addon |
|---|---|
| Summoning | Player clicks a secure button; nothing is cast by code |
| Trading | Read-only observation of the player's own trade windows; never initiates or accepts |
| Payment | In-game gold/silver only; paid status needs a **completed** trade |
| Advertising | Ad text is prepared; the player presses Enter. Cooldown hint shown. No timers that post |
| Whispers | Only in reply to a customer's whisper or booking milestone; each message sent once; 1 per 1.2 s; cooldowns on help/unavailable replies |
| Invites | One click per invite by default; auto-invite is opt-in |
| Network | Addon messages inside the game only; no external servers |
| Privacy | Only character names, destinations and amounts are stored; no chat logging |

## Things the project owners must decide / verify (not addressable in code)

* Owner decision (2026-11): selling summons for in-game gold/silver and automatic whisper replies are acceptable. Do not use the addon for real-money trading. Replies can be disabled: Setup -> Whisper customers.
* Re-check Blizzard's Add-On Policy and the Forever addon-restriction notes before each release.
* The addon is free; the Warlocks charge in-game prices themselves.

## Release checklist

- [ ] No real-money text, links or code
- [ ] No automated casting, targeting from insecure code, trading or Trade-chat posting
- [ ] `docs/API-NOTES.md` UNVERIFIED items re-tested on the live client
- [ ] Message rate limits present (`Net.lua`, `Whispers.lua`)
- [ ] `lua tests/run.lua` and `luacheck .` clean
