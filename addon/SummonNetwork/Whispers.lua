-- Whispers.lua: everything the customer sees. Customers need no addon; they only get whispers.
--   * parses "inv <city>" whispers and registers the customer with the network
--   * sends configurable, de-duplicated, rate-limited status whispers
--   * drives the group-invite step (one-click by default, optional auto-invite)
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "Whispers.lua" end
SN = SN or {}
local U, Q, API, G, Parse = SN.Util, SN.Queue, SN.API, SN.Groups, SN.Parse
local W = {}
SN.Whispers = W

local WHISPER_GAP = 1.2       -- seconds between outgoing customer whispers
local QUEUE_CAP = 40
local wq, lastSend = {}, 0
local sentLocal = {}          -- id:bit -> true, protects against double sends within a session
local cool = {}               -- sender:kind -> time

------------------------------------------------------------------------
-- Outgoing whisper queue
------------------------------------------------------------------------
function W.Whisper(name, text)
    if #wq >= QUEUE_CAP then table.remove(wq, 1) end
    wq[#wq + 1] = { name = name, text = text }
end

function W.Pump(now)
    if #wq == 0 or (now - lastSend) < WHISPER_GAP then return end
    local m = table.remove(wq, 1)
    lastSend = now
    if not API.Whisper(m.text, m.name) then SN.Log("whisper to " .. m.name .. " failed") end
end

local function cooldown(sender, kind, secs)
    local k = U.lower(sender) .. ":" .. kind
    local t = GetTime()
    if cool[k] and (t - cool[k]) < secs then return false end
    cool[k] = t
    return true
end

------------------------------------------------------------------------
-- Templates
------------------------------------------------------------------------
local function destList(withKeys)
    local parts = {}
    for _, d in ipairs(SN.engine:ActiveDests()) do
        parts[#parts + 1] = string.format('"inv %s" = %s (%s)', d.key, d.name, U.FormatMoney(d.price))
    end
    if #parts == 0 then return "none right now" end
    return table.concat(parts, ", ")
end

function W.Vars(b)
    local E = SN.engine
    local d = E.dests[b.dest] or { name = b.dest }
    return {
        dest = d.name, key = b.dest, price = U.FormatMoney(b.price), pricelong = U.MoneyWords(b.price),
        owner = b.owner or "a Warlock", pos = E:Position(b), cust = b.cust, list = destList(),
    }
end

local function render(kind, vars)
    local tpl = (SN.db.msgs and SN.db.msgs[kind]) or SN.Config.DEFAULT_MSGS[kind]
    return U.Fmt(tpl, vars)
end

function W.Reply(sender, kind, vars, secs)
    if not SN.db.whisperCustomers then return end
    if secs and not cooldown(sender, kind, secs) then return end
    W.Whisper(sender, render(kind, vars))
end

------------------------------------------------------------------------
-- Incoming customer whispers
------------------------------------------------------------------------
function W.OnWhisper(text, sender)
    local E = SN.engine
    sender = U.Short(sender)
    if not E or not sender or sender == SN.me or E.members[sender] then return end
    local kind, key = Parse.Invite(text, SN.aliasMap)
    if not kind then return end
    if kind == "nodest" then
        W.Reply(sender, "help", { list = destList() }, 60)
        return
    end
    local d = E.dests[key]
    if not d then return end
    local ex = E:ActiveFor(sender)
    if ex then
        W.Reply(sender, "already", W.Vars(ex), 30)
        return
    end
    if not d.enabled or E:Available(key) == 0 then
        W.Reply(sender, "unavailable", { dest = d.name, list = destList() }, 60)
        return
    end
    local b, why = E:Register(sender, key)
    if not b and why ~= "sent" then SN.Log("register failed: " .. tostring(why)) end
    SN.Alert(string.format("%s requested %s", sender, d.name), "info")
end

------------------------------------------------------------------------
-- Invites
------------------------------------------------------------------------
function W.Invite(b, manual)
    local E = SN.engine
    local info = G.Info(true)
    if info.inGroup and info.size >= info.max then
        SN.Alert(SN.L.ALERT_NEEDRAID, "alert")
        return false
    end
    if not info.canInvite then
        SN.Alert("You cannot invite (not leader/assistant). Ask the raid leader to invite " .. b.cust, "alert")
        return false
    end
    local ok, err = API.Invite(b.cust)
    if ok then
        E:Do(b.id, "invite")
        return true
    end
    -- Fallback: prefill the chat box; the player presses Enter (a normal user action).
    SN.Log("invite API unavailable: " .. tostring(err))
    if ChatFrame_OpenChat then ChatFrame_OpenChat("/invite " .. b.cust) end
    SN.Alert("Press Enter to invite " .. b.cust, "alert")
    return false
end

local function designatedInviter(b)
    local E = SN.engine
    if b.recv == SN.me then return true end
    return (b.recv == "" or not E:IsLive(b.recv)) and b.owner == SN.me
end

------------------------------------------------------------------------
-- Booking events -> customer whispers, invites and Warlock alerts
------------------------------------------------------------------------
local function designatedSender(b, early)
    local E = SN.engine
    if early then
        if b.recv == SN.me then return true end
        if b.recv ~= "" and E:IsLive(b.recv) then return false end
    end
    return b.owner == SN.me
end

local function mark(b, bit, kind)
    local E = SN.engine
    local k = b.id .. ":" .. bit
    if sentLocal[k] or U.SetHas(b.msgs, bit) then return end
    sentLocal[k] = true
    W.Reply(b.cust, kind, W.Vars(b))
    E:Do(b.id, "msg", bit)
end

function W.OnBooking(b, old, ev)
    local E = SN.engine
    local M = Q.MSG
    local me = SN.me

    if SN.db.whisperCustomers then
        if Q.IsActive(b) then
            if designatedSender(b, true) then
                mark(b, M.REGISTERED, "registered")
                if b.owner and b.ack then mark(b, M.ASSIGNED, "assigned") end
            end
            if b.owner == me then
                if b.state == "SUMMONING" then mark(b, M.READY, "ready") end
                if b.state == "PAYMENT_PENDING" then mark(b, M.ARRIVED, "arrived") end
            end
        elseif b.state == "PAID" then
            if b.owner == me and (b.pay == "paid" or b.pay == "free") then mark(b, M.PAID, "paid") end
        elseif (b.state == "CANCELLED" or b.state == "NO_SHOW") and U.SetHas(b.msgs, M.REGISTERED) then
            if designatedSender(b, true) then mark(b, M.ENDED, "ended") end
        end
    end

    -- Invite step
    if b.state == "AWAITING_INVITE" and old ~= "AWAITING_INVITE" and b.ack and designatedInviter(b) then
        if SN.db.autoInvite then
            W.Invite(b)
        elseif G.Info().canInvite then
            SN.Alert(string.format(SN.L.ALERT_INVITE, b.cust, (E.dests[b.dest] or {}).name or b.dest), "alert")
        end
    end

    -- Warlock-facing alerts
    if old ~= b.state then
        if b.state == "SUMMONING" and b.owner ~= me then
            local mm = E.members[me]
            if mm and mm.dest == b.dest then
                SN.Alert(string.format(SN.L.ALERT_PORTAL, b.owner or "?", b.cust), "alert")
            end
        elseif b.state == "PAYMENT_PENDING" and b.owner == me then
            SN.Alert(string.format(SN.L.ALERT_PAY, b.cust, U.FormatMoney(b.price)), "alert")
        end
    end
    if ev == "reassign" and b.owner == me and old ~= nil then
        SN.Alert(string.format("%s was assigned to you (%s)", b.cust, (E.dests[b.dest] or {}).name or b.dest), "info")
    end
    if SN.UI then SN.UI.Dirty() end
end

------------------------------------------------------------------------
-- System messages (invite failures)
------------------------------------------------------------------------
local function fmtPat(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%%%s", "(.+)")
    return "^" .. p .. "$"
end

local sysPats
function W.OnSystem(msg)
    if not msg then return end
    if not sysPats then
        sysPats = {
            { fmtPat(ERR_BAD_PLAYER_NAME_S), "could not be found (offline or wrong name)" },
            { fmtPat(ERR_ALREADY_IN_GROUP_S), "is already in a group" },
            { fmtPat(ERR_DECLINE_GROUP_S), "declined the group invitation" },
        }
    end
    for _, e in ipairs(sysPats) do
        if e[1] then
            local who = msg:match(e[1])
            if who then
                if e[2] then SN.Alert(string.format("%s %s", who, e[2]), "alert") end
                return
            end
        end
    end
    if ERR_GROUP_FULL and msg == ERR_GROUP_FULL then SN.Alert(SN.L.ALERT_NEEDRAID, "alert") end
end

return W
