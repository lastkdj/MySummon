-- Trade.lua: passive trade tracking. The addon NEVER initiates, edits or accepts a trade.
-- It reads the trade window the player opens, and marks a booking paid only when the trade
-- really completed:  both sides accepted  +  "Trade complete" system message  +  money received.
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "Trade.lua" end
SN = SN or {}
local U, API = SN.Util, SN.API
local T = {}
SN.Trade = T

local session            -- current open trade { partner, id, offered, both, gave }
local pending            -- closed trade awaiting confirmation { id, expected, before, gave, closedAt, complete }
local CONFIRM_WINDOW = 5 -- seconds to wait for the money/complete signals after TRADE_CLOSED

local function partnerName()
    local n = UnitName and UnitName("NPC")
    if (not n or n == "") and TradeFrameRecipientNameText and TradeFrameRecipientNameText.GetText then
        n = TradeFrameRecipientNameText:GetText()
    end
    return n and U.Short(n) or nil
end

local function myBookingFor(name)
    local E = SN.engine
    local b = name and E:ActiveFor(name)
    if b and b.owner == SN.me then return b end
    return nil
end

function T.OnShow()
    local name = partnerName()
    local b = myBookingFor(name)
    session = { partner = name, id = b and b.id, offered = 0, both = false, gave = 0 }
    if b then
        -- A trade with the customer means they are at the destination.
        if b.state == "SUMMONING" or b.state == "SUMMONED" or b.state == "ASSIGNED" or b.state == "IN_GROUP" or b.state == "WAITING" then
            SN.engine:Do(b.id, "arrived")
        end
        if SN.UI then SN.UI.TradeHint(b) end
    end
end

local function readMoney()
    if not session then return end
    session.offered = GetTargetTradeMoney and GetTargetTradeMoney() or 0
    session.gave = GetPlayerTradeMoney and GetPlayerTradeMoney() or 0
end

function T.OnMoney()
    readMoney()
    local b = session and session.id and SN.engine.bookings[session.id]
    if b and SN.UI then SN.UI.TradeHint(b, session.offered) end
end

function T.OnAccept(playerAccepted, targetAccepted)
    if not session then return end
    readMoney()
    if playerAccepted == 1 and targetAccepted == 1 then
        session.both = true
        session.snapshot = session.offered
        session.gave = session.gave
        session.before = API.Money()
    elseif session.both then
        -- someone un-accepted after both had accepted: the offer changed, start over
        session.both = false
    end
end

function T.OnClosed()
    if session and session.both and session.id and (session.snapshot or 0) > 0 then
        pending = {
            id = session.id, expected = session.snapshot, before = session.before or API.Money(),
            gave = session.gave or 0, closedAt = GetTime(), complete = false, partner = session.partner,
        }
    end
    session = nil
end

local function resolve(ok, reason)
    local p = pending
    pending = nil
    if not p then return end
    local E = SN.engine
    local b = E.bookings[p.id]
    if not b then return end
    if ok then
        E:Do(p.id, "paid", p.expected)
        if p.expected >= b.price then
            SN.Alert(string.format(SN.L.ALERT_PAID, b.cust, U.FormatMoney(p.expected)), "info")
        else
            SN.Alert(string.format(SN.L.ALERT_SHORT, b.cust, U.FormatMoney(p.expected), U.FormatMoney(b.price)), "alert")
        end
    else
        SN.Log("trade with " .. tostring(p.partner) .. " not confirmed: " .. tostring(reason))
    end
end

local function check()
    if not pending then return end
    local delta = API.Money() - pending.before
    local net = pending.expected - pending.gave
    if pending.complete and delta >= net then
        resolve(true)
    end
end

-- UI_INFO_MESSAGE / CHAT_MSG_SYSTEM carry the localized "Trade complete." / "Trade cancelled." text.
function T.OnMessage(...)
    local msg
    for i = select("#", ...), 1, -1 do
        local a = select(i, ...)
        if type(a) == "string" then msg = a break end
    end
    if not msg or not pending then return end
    if ERR_TRADE_CANCELLED and msg == ERR_TRADE_CANCELLED then
        resolve(false, "cancelled")
    elseif ERR_TRADE_COMPLETE and msg == ERR_TRADE_COMPLETE then
        pending.complete = true
        check()
    end
end

function T.OnPlayerMoney() check() end

function T.Tick(now)
    if not pending then return end
    check()
    if pending and (now - pending.closedAt) > CONFIRM_WINDOW then
        -- Completion message seen but money signal late/missing: trust the client's completion message.
        if pending.complete then resolve(true) else resolve(false, "no completion signal") end
    end
end

function T.Session() return session end

return T
