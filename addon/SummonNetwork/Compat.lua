-- Compat.lua: every WoW API used by the addon is reached through here so that a missing or
-- renamed function on the target client degrades to a manual fallback instead of an error.
-- Nothing in this file calls a protected function. See docs/API-NOTES.md.
local _, SN = ...
SN = SN or {}
local API = {}
SN.API = API

API.RITUAL_SPELL_ID = 698   -- Ritual of Summoning (UNVERIFIED on Forever; diag checks it)
API.SOUL_SHARD_ITEM = 6265  -- Soul Shard item id (UNVERIFIED on Forever; diag checks it)

function API.Player() return (UnitName("player")) end

function API.RegisterPrefix(prefix)
    local f = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
    if not f then return true end -- very old clients do not need registration
    local ok, res = pcall(f, prefix)
    return ok and (res == nil or res == true or res == 0)
end

-- Returns true if the message was handed to the client.
function API.SendAddon(prefix, msg, channel)
    local f = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
    if not f then return false end
    local ok = pcall(f, prefix, msg, channel)
    return ok
end

function API.IsInRaid()
    if IsInRaid then return IsInRaid() and true or false end
    return GetNumRaidMembers and GetNumRaidMembers() > 0 or false
end

function API.IsInGroup()
    if IsInGroup then return IsInGroup() and true or false end
    return (GetNumPartyMembers and GetNumPartyMembers() > 0) or API.IsInRaid()
end

function API.GroupSize()
    if GetNumGroupMembers then return GetNumGroupMembers() or 0 end
    if API.IsInRaid() then return GetNumRaidMembers() end
    return (GetNumPartyMembers and GetNumPartyMembers() or 0) + 1
end

function API.UnitIsLeader(unit)
    if UnitIsGroupLeader then return UnitIsGroupLeader(unit) and true or false end
    if UnitIsPartyLeader then return UnitIsPartyLeader(unit) and true or false end
    return false
end

function API.Whisper(msg, name)
    local f = SendChatMessage or (C_ChatInfo and C_ChatInfo.SendChatMessage)
    if not f then return false end
    return (pcall(f, msg, "WHISPER", nil, name))
end

-- Midnight-era clients hand addons "secret" values (e.g. chat during chat lockdown). Comparing or
-- string-matching one raises an error, so every inbound text is checked first.
function API.IsSecret(...)
    if not issecretvalue then return false end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return true end
    end
    return false
end

-- Group invitation. May be protected/hardware-event-restricted on some clients; always pcall'd.
function API.Invite(name)
    local f = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if not f then return false, "no invite API" end
    local ok, err = pcall(f, name)
    return ok, err
end

function API.ConvertToRaid()
    local f = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid
    if not f then return false, "no API" end
    return pcall(f)
end

function API.Uninvite(name)
    local f = (C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit
    if not f then return false, "no API" end
    return pcall(f, name)
end

function API.RitualName()
    if GetSpellInfo then
        local n = GetSpellInfo(API.RITUAL_SPELL_ID)
        if type(n) == "table" then n = n.name end
        if n then return n end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(API.RITUAL_SPELL_ID)
        if i then return i.name end
    end
    return nil
end

function API.KnowsRitual()
    local name = API.RitualName()
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(API.RITUAL_SPELL_ID) then return true, name end
    if IsSpellKnown and IsSpellKnown(API.RITUAL_SPELL_ID) then return true, name end
    if IsPlayerSpell and IsPlayerSpell(API.RITUAL_SPELL_ID) then return true, name end
    return false, name
end

function API.Shards()
    local f = (C_Item and C_Item.GetItemCount) or GetItemCount
    if f then return f(API.SOUL_SHARD_ITEM) or 0 end
    return 0
end

function API.InCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
end

function API.IsDead()
    return (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) and true or false
end

function API.Money() return GetMoney and GetMoney() or 0 end

function API.Time() return time() end

function API.ClassIsWarlock()
    local _, c = UnitClass("player")
    return c == "WARLOCK"
end

function API.BuildInfo()
    if GetBuildInfo then return GetBuildInfo() end
    return "?", "?", "?", 0
end

function API.TradeChannel()
    if not GetChannelList then return nil end
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local id, name = list[i], list[i + 1]
        if type(name) == "string" and string.lower(name):find("^trade") then return id, name end
    end
    return nil
end

function API.PlaySound(kind)
    if not PlaySound then return end
    pcall(PlaySound, kind == "alert" and 8959 or 882)
end

return API
