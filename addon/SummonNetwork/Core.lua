-- Core.lua: initialisation, event hub, shared helpers. Loaded last.
local ADDON, SN = ...
SN = SN or {}
local U, API, G = SN.Util, SN.API, SN.Groups

SN.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version"))
    or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "1.0.0"
math.randomseed(time())

------------------------------------------------------------------------
-- Logging and alerts
------------------------------------------------------------------------
local debugBuf = {}
function SN.Log(msg)
    debugBuf[#debugBuf + 1] = date("%H:%M:%S ") .. tostring(msg)
    if #debugBuf > 200 then table.remove(debugBuf, 1) end
end
function SN.DebugBuffer() return debugBuf end

function SN.Print(msg)
    print("|cff9be85aSummon Network:|r " .. tostring(msg))
end

function SN.Alert(text, kind)
    SN.Print(text)
    if SN.Kit then SN.Kit.Toast(text, kind) end
    if SN.db and SN.db.sound and kind == "alert" then API.PlaySound("alert") end
end

------------------------------------------------------------------------
-- Station settings
------------------------------------------------------------------------
local function pushSelf()
    if not SN.engine then return end
    SN.engine:SetSelf(SN.cdb.dest, SN.cdb.status, API.Shards())
    if SN.UI then SN.UI.Dirty() end
end

function SN.SetMyStatus(s)
    SN.cdb.status = s
    pushSelf()
    SN.Print("You are now " .. s)
end

function SN.SetMyDest(key)
    if not SN.engine.dests[key] then SN.Print("Unknown destination '" .. tostring(key) .. "'") return false end
    SN.cdb.dest = key
    pushSelf()
    SN.Print("You are standing in " .. SN.engine.dests[key].name)
    return true
end

function SN.EditDest(d)
    local ok, why = SN.engine:EditDest(d)
    if not ok then SN.Alert(tostring(why), "alert") end
    return ok
end

function SN.SetKey(text)
    SN.db.key = text or ""
    SN.engine.key = SN.db.key
    SN.Print(SN.db.key == "" and "Network key cleared (messages are unsigned)." or "Network key set.")
end

------------------------------------------------------------------------
-- Advertisement (always a player action)
------------------------------------------------------------------------
local lastAd = -1000
function SN.BuildAd()
    return SN.Ads.Build(SN.engine:ActiveDests(), { prefix = SN.db.adPrefix, suffix = SN.db.adSuffix })
end
function SN.AdCooldownLeft()
    return math.max(0, math.floor(lastAd + (SN.db.adCooldown or 60) - GetTime()))
end
function SN.PrepareAd()
    local ad, why = SN.BuildAd()
    if not ad then SN.Print("No ad: " .. tostring(why)) return end
    if SN.AdCooldownLeft() > 0 then
        SN.Print(string.format("Tip: your last ad was %ds ago - wait %ds to avoid spamming the channel.",
            (SN.db.adCooldown or 60) - SN.AdCooldownLeft(), SN.AdCooldownLeft()))
    end
    lastAd = GetTime()
    local id = API.TradeChannel()
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat((id and ("/" .. id .. " ") or "") .. ad)
        SN.Print(id and "Ad ready in the chat box - press Enter to post." or "Trade channel not found: copy the ad from the chat box and post it yourself.")
    else
        SN.Print(ad)
    end
end

------------------------------------------------------------------------
-- Engine wiring
------------------------------------------------------------------------
local function rebuildAliases()
    SN.aliasMap = SN.Parse.BuildAliasMap(SN.engine:DestList())
end

local function createEngine()
    local db = SN.db
    local final = {}
    for _, e in ipairs(db.ledger) do final[e.id] = true end
    local e = SN.Engine.New({
        name = SN.me, now = time, key = db.key, send = SN.Net.Send,
        cfg = function() return db end, groupInfo = G.Info, log = SN.Log, final = final,
        onFinal = function(b)
            SN.Stats.Append(db.ledger, SN.Stats.Entry(b), db.ledgerCap)
            if SN.UI then SN.UI.Dirty() end
        end,
    })
    SN.engine = e
    e:SetDestinations(U.copy(db.dests))
    rebuildAliases()
    e:On(function(kind, a, b, c)
        if kind == "booking" then
            SN.Whispers.OnBooking(a, b, c)
        elseif kind == "config" then
            db.dests = U.copy(e:DestList())
            rebuildAliases()
            if SN.UI then SN.UI.Dirty() end
        elseif SN.UI then
            SN.UI.Dirty()
        end
    end)
    e:Import(SN.cdb.session)
    e:SetSelf(SN.cdb.dest, SN.cdb.status, API.Shards())
    e:RequestSync()
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
SN.frame = frame

local function reg(ev) pcall(frame.RegisterEvent, frame, ev) end
for _, ev in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "CHAT_MSG_ADDON", "CHAT_MSG_WHISPER", "CHAT_MSG_SYSTEM",
    "GROUP_ROSTER_UPDATE", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED",
    "TRADE_SHOW", "TRADE_CLOSED", "TRADE_ACCEPT_UPDATE", "TRADE_MONEY_CHANGED", "UI_INFO_MESSAGE", "PLAYER_MONEY",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "PLAYER_REGEN_ENABLED", "BAG_UPDATE", "PLAYER_ENTERING_WORLD",
}) do reg(ev) end

local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    SN.db, SN.cdb = SN.Config.Init()
end

function handlers.PLAYER_LOGIN()
    SN.me = API.Player()
    SN.sessionStart = time()
    if not SN.db then SN.db, SN.cdb = SN.Config.Init() end
    SN.Net.Init()
    createEngine()
    SN.UI.Init()
    SN.Minimap.Init()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        pcall(function()
            local panel = CreateFrame("Frame")
            panel.name = "Summon Network"
            local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            t:SetPoint("TOPLEFT", 16, -16)
            t:SetText("Summon Network")
            local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            b:SetSize(180, 24); b:SetPoint("TOPLEFT", 16, -50); b:SetText("Open dashboard")
            b:SetScript("OnClick", function() SN.UI.Show("setup") end)
            local cat = Settings.RegisterCanvasLayoutCategory(panel, "Summon Network")
            Settings.RegisterAddOnCategory(cat)
        end)
    end
    if not API.ClassIsWarlock() then
        SN.Print("Note: this character is not a Warlock; you can still coordinate but not cast the summon.")
    end
    SN.Print(string.format("v%s loaded. Type |cff9be85a/sn|r to open. Key %s.", SN.version,
        SN.db.key ~= "" and "set" or "|cffee5555NOT set|r (see Setup)"))
end

function handlers.PLAYER_LOGOUT()
    if SN.engine then SN.cdb.session = SN.engine:Export() end
end

function handlers.CHAT_MSG_ADDON(prefix, text, channel, sender)
    if API.IsSecret(prefix, text, sender) then return end
    SN.Net.OnAddon(prefix, text, channel, sender)
end

function handlers.CHAT_MSG_WHISPER(text, sender)
    if API.IsSecret(text, sender) then return end
    if SN.engine then SN.Whispers.OnWhisper(text, sender) end
end

function handlers.CHAT_MSG_SYSTEM(msg)
    if not SN.engine or API.IsSecret(msg) then return end
    SN.Whispers.OnSystem(msg)
    SN.Trade.OnMessage(msg)
end

local function roster()
    G.Invalidate()
    if SN.UI then SN.UI.Dirty() end
end
handlers.GROUP_ROSTER_UPDATE = roster
handlers.RAID_ROSTER_UPDATE = roster
handlers.PARTY_MEMBERS_CHANGED = roster

function handlers.TRADE_SHOW() if SN.engine then SN.Trade.OnShow() end end
function handlers.TRADE_CLOSED() if SN.engine then SN.Trade.OnClosed() end end
function handlers.TRADE_ACCEPT_UPDATE(a, b) if SN.engine then SN.Trade.OnAccept(a, b) end end
function handlers.TRADE_MONEY_CHANGED() if SN.engine then SN.Trade.OnMoney() end end
function handlers.UI_INFO_MESSAGE(...) if SN.engine and not API.IsSecret(...) then SN.Trade.OnMessage(...) end end
function handlers.PLAYER_MONEY() if SN.engine then SN.Trade.OnPlayerMoney() end end

function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, ...) if SN.engine then SN.Summon.OnCastSucceeded(unit, ...) end end
function handlers.UNIT_SPELLCAST_FAILED(unit, ...) if SN.engine then SN.Summon.OnCastFailed(unit, ...) end end
function handlers.UNIT_SPELLCAST_INTERRUPTED(unit, ...) if SN.engine then SN.Summon.OnCastFailed(unit, ...) end end

function handlers.PLAYER_REGEN_ENABLED() SN.Summon.OnRegenEnabled() end
function handlers.BAG_UPDATE() if SN.engine then pushSelf() end end
function handlers.PLAYER_ENTERING_WORLD() if SN.engine then roster(); pushSelf() end end

frame:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then
        local ok, err = pcall(h, ...)
        if not ok then
            SN.Log("event " .. event .. " failed: " .. tostring(err))
            if SN.debug then SN.Print("error in " .. event .. ": " .. tostring(err)) end
        end
    end
end)

------------------------------------------------------------------------
-- Heartbeat
------------------------------------------------------------------------
local acc1, acc2, acc3, acc4 = 0, 0, 0, 0
frame:SetScript("OnUpdate", function(_, el)
    if not SN.engine then return end
    acc1, acc2, acc3, acc4 = acc1 + el, acc2 + el, acc3 + el, acc4 + el
    if acc1 >= 0.2 then
        acc1 = 0
        local now = GetTime()
        local ok, err = pcall(function()
            SN.Net.Pump(now)
            SN.Whispers.Pump(now)
            SN.Trade.Tick(now)
        end)
        if not ok then SN.Log("pump failed: " .. tostring(err)) end
    end
    if acc2 >= 1 then
        acc2 = 0
        local ok, err = pcall(function()
            SN.engine:Tick()
            pushSelf()
        end)
        if not ok then SN.Log("tick failed: " .. tostring(err)) end
    end
    if acc3 >= 2 then
        acc3 = 0
        pcall(SN.Summon.PollArrivals)
    end
    if acc4 >= 30 then
        acc4 = 0
        SN.cdb.session = SN.engine:Export()
    end
end)
