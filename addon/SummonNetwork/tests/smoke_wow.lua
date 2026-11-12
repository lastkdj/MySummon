-- Headless smoke test: loads the whole addon against the mock client and drives a full job.
local L = dofile("tests/lib.lua")
local M = dofile("tests/wowmock.lua")
local SN = M.loadAddon(".")

M.fire("ADDON_LOADED", "SummonNetwork")
M.fire("PLAYER_LOGIN")
M.advance(3)
L.check(SN.engine ~= nil, "engine created")
L.eq(SN.me, "Shadowlock")
SN.db.msgs.paid = SN.db.msgs.paid

local function slash(s) SlashCmdList["SUMMONNETWORK"](s) end
local function lastWhisperTo(n)
    for i = #M.whispers, 1, -1 do if M.whispers[i].to == n then return M.whispers[i].msg end end
end
local function whispersTo(n)
    local o = {}
    for _, w in ipairs(M.whispers) do if w.to == n then o[#o + 1] = w.msg end end
    return o
end

L.section("smoke: slash commands never throw")
for _, c in ipairs({ "", "status", "queue", "stats", "setup", "available", "busy", "available", "city ogr", "price ogr 30s",
    "alias ogr add orgy", "alias ogr del orgy", "dest add sw Stormwind Stormwind City", "dest off sw", "dest on sw", "dest del sw",
    "ad", "diag", "members", "debug", "debug", "key hunter2", "manager add Shadowlock", "member add Shadowlock", "channel group",
    "compact", "compact", "help", "bogus", "paid nobody", "discount nobody 5s" }) do
    local ok, err = pcall(slash, c)
    L.check(ok, "/sn " .. c .. " -> " .. tostring(err))
end
slash("manager del Shadowlock"); slash("member del Shadowlock")
L.check(M.chatBox and M.chatBox:find("inv ogr"), "ad prepared in chat box (not sent)")
L.check(M.chatBox:find("^/2 "), "ad targets the Trade channel number")
L.eq(#M.whispers, 0, "no whispers from slash setup")

L.section("smoke: customer whisper -> registered")
SN.cdb.status = "available"; SN.SetMyDest("ogr"); M.advance(2)
M.say("Bigdaddy", "INV OGR")
M.advance(3)
local b = SN.engine:Find("Bigdaddy")
L.check(b ~= nil, "booking created")
L.eq(b.owner, "Shadowlock"); L.eq(b.dest, "ogr"); L.eq(b.state, "AWAITING_INVITE")
local w = whispersTo("Bigdaddy")
L.eq(#w, 2, "registered + assigned whispers: " .. #w)
L.check(w[1]:find("Orgrimmar summon requested") and w[1]:find("30s"), w[1])
L.check(w[2]:find("Your Orgrimmar summoner is Shadowlock") and w[2]:find("#1") and w[2]:find("30 silver"), w[2])
M.say("Bigdaddy", "inv ogr"); M.advance(3)
L.check(lastWhisperTo("Bigdaddy"):find("already registered"), "duplicate request gets status, not a new booking")
M.say("Bigdaddy", "inv uc"); M.advance(2)
local n = 0; for _ in pairs(SN.engine.bookings) do n = n + 1 end
L.eq(n, 1, "still one booking")
M.say("Rando", "hello there"); M.advance(2)
L.eq(#whispersTo("Rando"), 0, "non-invite whispers are ignored")
M.say("Lost", "inv"); M.advance(3)
L.check(lastWhisperTo("Lost"):find("inv <city>"), "help reply for unknown destination")
local before = #whispersTo("Lost")
M.say("Lost", "inv"); M.advance(3)
L.eq(#whispersTo("Lost"), before, "help reply is rate limited")

L.section("smoke: invite -> group -> summon -> arrival -> trade -> paid")
local ok = SN.Whispers.Invite(b)
L.check(ok and M.invites[1] == "Bigdaddy", "one-click invite")
M.advance(2)
L.eq(SN.engine:Find("Bigdaddy").state, "INVITED")
M.inRaid = true
M.raid = { { name = "Shadowlock", rank = 2, zone = "Orgrimmar" }, { name = "Bigdaddy", zone = "Stormwind City" } }
SN.Groups.Invalidate(); M.fire("GROUP_ROSTER_UPDATE"); M.advance(3)
L.eq(SN.engine:Find("Bigdaddy").state, "ASSIGNED", "ready once in group")

SN.selected = nil
SN.Summon.Refresh()
local btn = SummonNetworkSummonButton
L.eq(btn.attrs.type, "macro", "secure button armed")
L.check(btn.attrs.macrotext:find("/target raid2") and btn.attrs.macrotext:find("/cast Ritual of Summoning"), btn.attrs.macrotext)
btn.scripts.PreClick(btn); btn.scripts.PostClick(btn); M.advance(2)
L.eq(SN.engine:Find("Bigdaddy").state, "SUMMONING")
L.check(lastWhisperTo("Bigdaddy"):find("summon is ready"), "ready whisper")
M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 698); M.advance(2)
L.eq(SN.engine:Find("Bigdaddy").state, "SUMMONED")

M.combat = true; SN.Summon.Refresh(); M.combat = false
M.raid[2].zone = "Orgrimmar"; SN.Groups.Invalidate(); M.advance(4)
L.eq(SN.engine:Find("Bigdaddy").state, "PAYMENT_PENDING", "arrival detected from roster zone")
L.check(lastWhisperTo("Bigdaddy"):find("trade 30 silver to Shadowlock"), lastWhisperTo("Bigdaddy"))

-- trade: placing money alone must NOT mark paid
M.tradePartner = "Bigdaddy"
M.fire("TRADE_SHOW"); M.tradeOffer = 3000; M.fire("TRADE_MONEY_CHANGED"); M.advance(2)
L.eq(SN.engine:Find("Bigdaddy").state, "PAYMENT_PENDING", "offer alone is not payment")
M.fire("TRADE_ACCEPT_UPDATE", 1, 1)
M.fire("TRADE_CLOSED"); M.advance(2)
M.fire("UI_INFO_MESSAGE", 1, ERR_TRADE_CANCELLED); M.advance(8)
L.eq(SN.engine:Find("Bigdaddy").state, "PAYMENT_PENDING", "cancelled trade is not payment")
-- real completed trade
M.fire("TRADE_SHOW"); M.tradeOffer = 3000; M.fire("TRADE_MONEY_CHANGED")
M.fire("TRADE_ACCEPT_UPDATE", 1, 1)
M.fire("TRADE_CLOSED")
M.money = M.money + 3000
M.fire("UI_INFO_MESSAGE", 1, ERR_TRADE_COMPLETE)
M.fire("PLAYER_MONEY"); M.advance(3)
b = SN.engine:Find("Bigdaddy")
L.eq(b.state, "PAID"); L.eq(b.pay, "paid"); L.eq(b.got, 3000)
L.check(lastWhisperTo("Bigdaddy"):find("Payment received"), "paid whisper")
L.eq(#SN.db.ledger, 1, "ledger entry"); L.eq(SN.db.ledger[1].owner, "Shadowlock")
local allw = whispersTo("Bigdaddy")
L.eq(#allw, 6, "exactly 6 whispers across the job (no duplicates): " .. #allw)

L.section("smoke: short payment keeps job open")
M.say("Cheap", "inv tb"); M.advance(3)
-- nobody at tb: unavailable reply, no booking
L.check(lastWhisperTo("Cheap"):find("unavailable"), lastWhisperTo("Cheap"))
L.eq(SN.engine:ActiveFor("Cheap"), nil)
M.say("Cheap", "inv ogr"); M.advance(3)
local cb = SN.engine:Find("Cheap")
SN.engine:Do(cb.id, "invite")
M.raid[#M.raid + 1] = { name = "Cheap", zone = "Orgrimmar" }; SN.Groups.Invalidate(); M.advance(4)
L.eq(SN.engine:Find("Cheap").state, "ASSIGNED")
SN.engine:Do(cb.id, "arrived"); M.advance(2)
M.tradePartner = "Cheap"
M.fire("TRADE_SHOW"); M.tradeOffer = 1000; M.fire("TRADE_ACCEPT_UPDATE", 1, 1); M.fire("TRADE_CLOSED")
M.money = M.money + 1000; M.fire("UI_INFO_MESSAGE", 1, ERR_TRADE_COMPLETE); M.fire("PLAYER_MONEY"); M.advance(3)
L.eq(SN.engine:Find("Cheap").state, "PAYMENT_PENDING", "1s of 30s is not paid"); L.eq(SN.engine:Find("Cheap").got, 1000)
slash("paid Cheap"); M.advance(2)
L.eq(SN.engine:Find("Cheap").state, "PAID")

L.section("smoke: UI renders every tab")
SN.UI.Show("queue"); M.advance(2)
for _, tab in ipairs({ "queue", "cities", "stats", "ads", "setup" }) do
    local ok, err = pcall(SN.UI.Show, tab)
    L.check(ok, tab .. ": " .. tostring(err))
    local ok2, err2 = pcall(function() SN.UI.Dirty(); M.advance(1.5) end)
    L.check(ok2, tab .. " refresh: " .. tostring(err2))
end
L.check(SummonNetworkFrame.shown)
SN.UI.SetCompact(true); M.advance(2); L.check(SummonNetworkCompact.shown); SN.UI.SetCompact(false)
local ok3, err3 = pcall(function() SN.Kit.Toast("x", "alert"); SN.Kit.ShowMenu(SummonNetworkFrame, { { text = "a" } }); SN.Kit.CloseMenu() end)
L.check(ok3, tostring(err3))

L.section("smoke: persistence and errors")
M.fire("PLAYER_LOGOUT")
L.check(SN.cdb.session and SN.cdb.session.bookings, "session exported")
for _, p in ipairs(M.prints) do
    L.check(not p:find("error in") and not p:find("Error:"), "no error printed: " .. p)
end
local bad = 0
for _, line in ipairs(SN.DebugBuffer()) do if line:find("failed") then bad = bad + 1 M.realprint("  log: " .. line) end end
L.eq(bad, 0, "no failures in debug log")
L.check(#M.addonMsgs >= 0)

print = M.realprint
return L
