local L = dofile("tests/lib.lua")
local SN = L.newSN()
local U, P, Pr, Q, Ads, St = SN.Util, SN.Parse, SN.Protocol, SN.Queue, SN.Ads, SN.Stats

L.section("Util: money")
L.eq(U.FormatMoney(3000), "30s")
L.eq(U.FormatMoney(10500), "1g 5s")
L.eq(U.FormatMoney(0), "0c")
L.eq(U.ParseMoney("30s"), 3000)
L.eq(U.ParseMoney("1g 5s"), 10500)
L.eq(U.ParseMoney("1g5s20c"), 10520)
L.eq(U.ParseMoney("30 silver"), 3000)
L.eq(U.ParseMoney("2.5g"), 25000)
L.eq(U.ParseMoney("30"), 3000)
L.eq(U.ParseMoney("abc"), nil)
L.eq(U.ParseMoney("30x"), nil)
L.eq(U.ParseMoney(""), nil)
L.eq(U.MoneyWords(3000), "30 silver")

L.section("Util: misc")
L.eq(U.Short("Bob-Realm"), "Bob")
L.eq(U.Fmt("hi {a} {b}", { a = 1 }), "hi 1 {b}")
L.check(U.SetHas(U.SetAdd(0, 4), 4))
L.check(not U.SetHas(U.SetAdd(0, 4), 2))
L.eq(U.SetAdd(5, 1), 5)
local sp = U.split("a||b|", "|")
L.eq(#sp, 4)

L.section("Parse: inv commands")
local dests = {
    { key = "ogr", name = "Orgrimmar", aliases = { "org", "orgri" } },
    { key = "uc", name = "Undercity", aliases = { "under" } },
    { key = "tb", name = "Thunder Bluff", aliases = { "thunder", "thunderbluff" } },
}
local map = P.BuildAliasMap(dests)
local function inv(t) return P.Invite(t, map) end
L.eq(select(2, inv("inv ogr")), "ogr")
L.eq(select(2, inv("INV OGR")), "ogr")
L.eq(select(2, inv("inv org")), "ogr")
L.eq(select(2, inv("inv orgrimmar")), "ogr")
L.eq(select(2, inv("Inv uc")), "uc")
L.eq(select(2, inv("inv tb")), "tb")
L.eq(select(2, inv("inv thunder bluff")), "tb")
L.eq(select(2, inv("inv  Thunder  Bluff pls")), "tb")
L.eq(select(2, inv("inv. ogr!")), "ogr")
L.eq(select(2, inv("invite uc please")), "uc")
L.eq(select(2, inv("inv to undercity")), "uc")
L.eq(inv("inv"), "nodest")
L.eq(inv("inv mars"), "nodest")
L.eq(inv("hello there"), nil)
L.eq(inv("invalid ogr"), nil)
L.eq(inv("how much for ogr"), nil)
L.eq(inv(""), nil)
L.eq(select(2, inv("|cff00ff00inv|r ogr")), "ogr")

L.section("Protocol")
local msg = assert(Pr.Encode("BK", 5, { "a|b", "c%d", "line\nbreak", "" }, "k", "Bob"))
local ok, t, seq, f = Pr.Decode(msg, "k", "Bob")
L.check(ok); L.eq(t, "BK"); L.eq(seq, 5)
L.eq(f[1], "a|b"); L.eq(f[2], "c%d"); L.eq(f[3], "line\nbreak"); L.eq(f[4], "")
L.check(not msg:sub(1, -14):find("\n"), "no raw newline")
L.check(not (Pr.Decode(msg, "wrong", "Bob")), "wrong key rejected")
L.check(not (Pr.Decode(msg, "k", "Mallory")), "spoofed sender rejected")
local tampered = msg:gsub("BK", "XX", 1)
L.check(not (Pr.Decode(tampered, "k", "Bob")), "tamper rejected")
L.check(not (Pr.Decode("garbage", "k", "Bob")))
L.check(not (Pr.Decode("", "k", "Bob")))
L.check(not (Pr.Decode("bk|1|x|-", "", "Bob")), "lowercase type rejected")
L.check(Pr.Decode(Pr.Encode("HI", 1, { 1 }, "", "Bob"), "", "Bob"), "no key mode")
local long = {}
for i = 1, 40 do long[i] = "xxxxxxxxxx" end
L.check(Pr.Encode("BK", 1, long, "k", "Bob") == nil, "over-long rejected")

L.section("Queue: state machine")
local function nb(price) local b = Q.New("id1", "Cust", "ogr", price or 3000, "Recv", 100); b.owner = "Own"; return b end
local b = nb()
L.check(not Q.Apply(b, "invite", nil, 101), "cannot invite before ack")
L.check(Q.Apply(b, "ack", nil, 101)); L.eq(b.state, "AWAITING_INVITE")
L.check(Q.Apply(b, "invite", nil, 102)); L.eq(b.state, "INVITED")
L.check(Q.Apply(b, "joined", nil, 103)); L.eq(b.state, "IN_GROUP")
L.check(not Q.Apply(b, "begin", nil, 104), "cannot begin from IN_GROUP")
L.check(Q.Apply(b, "promote", "ASSIGNED", 104)); L.eq(b.state, "ASSIGNED")
L.check(Q.Apply(b, "begin", nil, 105)); L.eq(b.state, "SUMMONING"); L.eq(b.begun, 105)
L.check(Q.Apply(b, "abort", nil, 106)); L.eq(b.state, "ASSIGNED")
L.check(Q.Apply(b, "begin", nil, 107))
L.check(Q.Apply(b, "summoned", nil, 108)); L.eq(b.state, "SUMMONED")
L.check(Q.Apply(b, "arrived", nil, 109)); L.eq(b.state, "PAYMENT_PENDING")
L.check(Q.Apply(b, "paid", 1000, 110)); L.eq(b.state, "PAYMENT_PENDING"); L.eq(b.got, 1000)
L.check(Q.Apply(b, "paid", 2000, 111)); L.eq(b.state, "PAID"); L.eq(b.pay, "paid"); L.eq(b.got, 3000)
L.check(not Q.Apply(b, "cancel", nil, 112), "terminal is final")
L.check(not Q.Apply(b, "paid", 3000, 112), "no double payment")

b = nb(); Q.Apply(b, "ack"); Q.Apply(b, "joined"); Q.Apply(b, "promote", "ASSIGNED")
L.check(Q.Apply(b, "left")); L.eq(b.state, "DISCONNECTED"); L.eq(b.ps, "ASSIGNED")
L.check(Q.Apply(b, "back")); L.eq(b.state, "IN_GROUP")
L.check(Q.Apply(b, "noshow", nil, 200)); L.eq(b.state, "NO_SHOW")
L.check(Q.Apply(b, "requeue", nil, 300)); L.eq(b.state, "REQUESTED"); L.eq(b.owner, nil); L.eq(b.msgs, 0)

b = nb(0); Q.Apply(b, "ack"); Q.Apply(b, "joined"); Q.Apply(b, "promote", "ASSIGNED"); Q.Apply(b, "begin", nil, 5)
Q.Apply(b, "summoned"); Q.Apply(b, "arrived", nil, 9)
L.eq(b.state, "PAID", "free price completes on arrival"); L.eq(b.pay, "free")

b = nb(); Q.Apply(b, "ack"); Q.Apply(b, "joined"); Q.Apply(b, "promote", "ASSIGNED"); Q.Apply(b, "begin"); Q.Apply(b, "summoned")
Q.Apply(b, "arrived", nil, 9); L.check(Q.Apply(b, "free", nil, 10)); L.eq(b.state, "PAID"); L.eq(b.pay, "free")

b = nb(); Q.Apply(b, "ack"); Q.Apply(b, "joined"); Q.Apply(b, "promote", "ASSIGNED"); Q.Apply(b, "begin"); Q.Apply(b, "summoned")
Q.Apply(b, "arrived", nil, 9)
L.check(Q.Apply(b, "unpaid", nil, 10)); L.eq(b.state, "PAID"); L.eq(b.pay, "unpaid"); L.eq(b.got, 0)

b = nb(); Q.Apply(b, "ack"); Q.Apply(b, "joined"); Q.Apply(b, "promote", "ASSIGNED")
Q.Apply(b, "arrived", nil, 9); Q.Apply(b, "markpaid", 2500, 10)
L.eq(b.state, "PAID"); L.eq(b.got, 2500, "partial accepted as complete")

b = nb(); Q.Apply(b, "ack")
L.check(Q.Apply(b, "redirect", "uc")); L.eq(b.dest, "uc"); L.eq(b.owner, nil); L.eq(b.state, "REQUESTED")
b = nb(); Q.Apply(b, "ack"); Q.Apply(b, "joined"); Q.Apply(b, "promote", "ASSIGNED"); Q.Apply(b, "begin")
L.check(not Q.Apply(b, "redirect", "uc"), "cannot redirect mid-summon")
L.check(Q.Apply(b, "discount", 1500)); L.eq(b.price, 1500)
L.check(not Q.Apply(b, "bogus"))

L.section("Ads")
local act = {
    { key = "ogr", name = "Orgrimmar", price = 3000 }, { key = "uc", name = "Undercity", price = 3000 },
    { key = "tb", name = "Thunder Bluff", price = 3000 },
}
local ad = Ads.Build(act)
L.eq(ad, 'WTS SUMMONS - 30s! Need a quick summon? Whisper "inv ogr" for Orgrimmar, "inv uc" for Undercity, or "inv tb" for Thunder Bluff. Fast service!')
L.eq(Ads.Build({ act[1], act[3] }):find("Undercity"), nil, "inactive destination excluded")
act[2].price = 5000
L.check(Ads.Build(act):find("%(5s?0?s?%)") or Ads.Build(act):find("50s"), "per-city prices when they differ")
L.check(#Ads.Build(act) <= 255)
L.eq(Ads.Build({}), nil)

L.section("Stats")
local ledger = {
    { id = "a", cust = "X", dest = "ogr", owner = "W1", state = "PAID", pay = "paid", price = 3000, got = 3000, created = 100, begun = 130, done = 200 },
    { id = "b", cust = "Y", dest = "uc", owner = "W2", state = "PAID", pay = "paid", price = 3000, got = 3500, created = 100, begun = 160, done = 220 },
    { id = "c", cust = "x", dest = "ogr", owner = "W1", state = "PAID", pay = "free", price = 0, got = 0, created = 100, begun = 110, done = 230 },
    { id = "d", cust = "Z", dest = "tb", owner = "W3", state = "PAID", pay = "unpaid", price = 3000, got = 0, created = 100, begun = 100, done = 240 },
    { id = "e", cust = "Q", dest = "tb", owner = "W3", state = "CANCELLED", pay = "", price = 3000, got = 0, created = 100, begun = 0, done = 250 },
    { id = "f", cust = "R", dest = "tb", owner = "", state = "NO_SHOW", pay = "", price = 3000, got = 0, created = 100, begun = 0, done = 260 },
}
local s = St.Compute(ledger)
L.eq(s.completed, 4); L.eq(s.revenue, 6500); L.eq(s.paid, 2); L.eq(s.free, 1); L.eq(s.unpaid, 1)
L.eq(s.cancelled, 1); L.eq(s.noshow, 1); L.eq(s.customerCount, 3, "case-insensitive unique customers")
L.eq(s.byDest.ogr.revenue, 3000); L.eq(s.byWarlock.W2.revenue, 3500)
L.eq(s.avgWait, (30 + 60 + 10 + 0) / 4)
L.check(not St.Append(ledger, ledger[1]), "ledger dedupes by id")
L.check(St.Append(ledger, { id = "g", state = "PAID" }))

return L
