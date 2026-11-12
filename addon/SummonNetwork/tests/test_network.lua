local L = dofile("tests/lib.lua")
local SN = L.newSN()
local Q = SN.Queue

local function states(net, name)
    local out = {}
    for _, b in pairs(net.nodes[name].bookings) do out[b.cust] = b end
    return out
end

-- Drive one customer end to end through the coordinator. Returns the booking on `via`.
local function fullFlow(net, via, cust, owner, amount)
    local n = net.nodes
    net:join(cust)
    net:tick(2)
    local b = n[via]:Find(cust)
    L.eq(b.state ~= "REQUESTED" and b.state ~= "AWAITING_INVITE" and b.state ~= "INVITED", true, cust .. " reached group state")
    return b
end

------------------------------------------------------------------------
L.section("3 Warlocks, one city: round robin + single owner")
do
    local net = L.newNet(SN)
    net:add("Alpha", "ogr"); net:add("Bravo", "ogr"); net:add("Charlie", "ogr")
    net:tick(3)
    local coord = net.nodes.Alpha.coord
    L.eq(coord, "Alpha", "alphabetical coordinator with no manager/leader")
    L.eq(net.nodes.Bravo.coord, "Alpha"); L.eq(net.nodes.Charlie.coord, "Alpha")

    local owners = {}
    for i, c in ipairs({ "C1", "C2", "C3", "C4" }) do
        -- customers whisper different Warlocks
        local via = ({ "Alpha", "Bravo", "Charlie", "Bravo" })[i]
        net.nodes[via]:Register(c, "ogr"); net:pump()
        owners[#owners + 1] = net.nodes.Alpha:Find(c).owner
    end
    L.eq(table.concat(owners, ","), "Alpha,Bravo,Charlie,Alpha", "round robin A,B,C,A")
    net:tick(2)
    for _, name in ipairs({ "Alpha", "Bravo", "Charlie" }) do
        L.eq(net.nodes[name]:Find("C2").owner, "Bravo", name .. " sees same owner")
        L.eq(net.nodes[name]:Find("C2").state, "AWAITING_INVITE", "owner acknowledged")
    end
    L.check(net:consistent())
end

------------------------------------------------------------------------
L.section("Duplicate whispers: one booking, even from several Warlocks")
do
    local net = L.newNet(SN)
    net:add("Alpha", "ogr"); net:add("Bravo", "ogr"); net:add("Charlie", "uc")
    net:tick(3)
    net.nodes.Alpha:Register("Bigdaddy", "ogr")
    net.nodes.Bravo:Register("Bigdaddy", "ogr")
    net.nodes.Charlie:Register("bigdaddy", "uc")   -- same person, other city, other case
    net:pump(); net:tick(2)
    local n = 0
    for _ in pairs(net.nodes.Charlie.bookings) do n = n + 1 end
    L.eq(n, 1, "exactly one booking")
    L.eq(net.nodes.Charlie:Find("Bigdaddy").dest, "ogr", "first request wins")
    local _, why = net.nodes.Bravo:Register("BIGDADDY", "ogr")
    L.eq(why, "duplicate", "known locally as duplicate")
end

------------------------------------------------------------------------
L.section("Full customer lifecycle, queue order, serial summoning")
do
    local net = L.newNet(SN)
    net:add("Alpha", "ogr"); net:add("Bravo", "ogr"); net:add("Charlie", "ogr")
    net:tick(3)
    net.nodes.Alpha:Register("P1", "ogr"); net:pump(); net.t = net.t + 1
    net.nodes.Bravo:Register("P2", "ogr"); net:pump(); net.t = net.t + 1
    net:tick(1)
    local b1, b2 = net.nodes.Alpha:Find("P1"), net.nodes.Alpha:Find("P2")
    L.eq(b1.owner, "Alpha"); L.eq(b2.owner, "Bravo")

    -- Only the right people may drive each booking.
    L.check(not net.nodes.Charlie:Do(b1.id, "invite") == false, "any member may record an invite")
    net:pump()
    L.eq(net.nodes.Alpha:Find("P1").state, "INVITED")
    local ok = net.nodes.Charlie:Do(b1.id, "paid", 3000); net:pump()
    L.check(ok == false or net.nodes.Alpha:Find("P1").state ~= "PAID", "non-owner cannot mark paid")

    net:join("P1"); net:join("P2"); net:tick(2)
    L.eq(net.nodes.Alpha:Find("P1").state, "ASSIGNED", "head of queue is assigned")
    L.eq(net.nodes.Alpha:Find("P2").state, "WAITING", "second customer waits")
    local ok2, why = net.nodes.Bravo:Do(b2.id, "begin"); net:pump()
    L.check(net.nodes.Alpha:Find("P2").state == "WAITING", "cannot begin out of turn: " .. tostring(why))

    L.check(net.nodes.Alpha:Do(b1.id, "begin")); net:pump()
    L.eq(net.nodes.Charlie:Find("P1").state, "SUMMONING", "everyone sees SUMMONING")
    L.eq(net.nodes.Alpha:Find("P2").state, "WAITING")
    net.nodes.Alpha:Do(b1.id, "summoned"); net:pump()
    L.eq(net.nodes.Alpha:Find("P2").state, "ASSIGNED", "next customer promoted once team is free")

    net.nodes.Alpha:Do(b1.id, "arrived"); net:pump()
    L.eq(net.nodes.Bravo:Find("P1").state, "PAYMENT_PENDING")
    net.nodes.Alpha:Do(b1.id, "paid", 3000); net:pump()
    L.eq(net.nodes.Charlie:Find("P1").state, "PAID")
    L.eq(net.nodes.Charlie:Find("P1").got, 3000)
    for _, name in ipairs({ "Alpha", "Bravo", "Charlie" }) do
        L.eq(#net.finals[name], 1, name .. " recorded exactly one final transaction")
    end
    L.check(net:consistent())
    local c = net.nodes.Bravo:Counts()
    L.eq(c.active, 1)
end

------------------------------------------------------------------------
L.section("9 Warlocks / three cities: routing across cities")
do
    local net = L.newNet(SN)
    local teams = { ogr = { "Ao", "Bo", "Co" }, uc = { "Au", "Bu", "Cu" }, tb = { "At", "Bt", "Ct" } }
    for dest, names in pairs(teams) do for _, n in ipairs(names) do net:add(n, dest) end end
    net:tick(5)
    -- A Warlock in Orgrimmar receives "inv uc" and "inv tb".
    net.nodes.Bo:Register("PlayerOne", "uc"); net:pump()
    net.nodes.Bo:Register("PlayerTwo", "ogr"); net:pump()
    net.nodes.Bo:Register("PlayerThree", "tb"); net:pump()
    net:tick(3)
    local b1 = net.nodes.Co:Find("PlayerOne")
    L.eq(b1.dest, "uc"); L.check(b1.owner:sub(2, 2) == "u", "routed to an Undercity Warlock: " .. tostring(b1.owner))
    L.check(net.nodes.Co:Find("PlayerTwo").owner:sub(2, 2) == "o")
    L.check(net.nodes.Co:Find("PlayerThree").owner:sub(2, 2) == "t")
    L.eq(b1.recv, "Bo", "receiving Warlock recorded")
    L.check(net:consistent())
    -- queues are per city
    L.eq(#net.nodes.Au:Queue("uc"), 1); L.eq(#net.nodes.Au:Queue("ogr"), 1)
    -- simultaneous processing in three cities
    for _, c in ipairs({ "PlayerOne", "PlayerTwo", "PlayerThree" }) do net:join(c) end
    net:tick(3)
    for _, c in ipairs({ "PlayerOne", "PlayerTwo", "PlayerThree" }) do
        L.eq(net.nodes.Ao:Find(c).state, "ASSIGNED", c .. " ready to summon")
        local b = net.nodes.Ao:Find(c)
        net.nodes[b.owner]:Do(b.id, "begin")
    end
    net:pump()
    for _, c in ipairs({ "PlayerOne", "PlayerTwo", "PlayerThree" }) do
        L.eq(net.nodes.At:Find(c).state, "SUMMONING", "parallel summoning in different cities")
    end
end

------------------------------------------------------------------------
L.section("12 Warlocks / four cities")
do
    local net = L.newNet(SN)
    for _, dest in ipairs({ "ogr", "uc", "tb", "sw" }) do
        for _, s in ipairs({ "a", "b", "c" }) do net:add(s .. dest, dest) end
    end
    net:tick(5)
    L.eq(#net.nodes.aogr:LiveMembers(), 12)
    L.eq(#net.nodes.aogr:ActiveDests(), 4)
    for i = 1, 8 do
        local dest = ({ "ogr", "uc", "tb", "sw" })[(i - 1) % 4 + 1]
        net.nodes.asw:Register("Cust" .. i, dest); net:pump()
    end
    net:tick(2)
    for i = 1, 8 do
        local b = net.nodes.cogr:Find("Cust" .. i)
        L.check(b and b.owner, "Cust" .. i .. " has an owner")
    end
    L.check(net:consistent())
    L.eq(net.nodes.aogr:Find("Cust1").price, 3000); L.eq(net.nodes.aogr:Find("Cust4").price, 5000, "sw price")
end

------------------------------------------------------------------------
L.section("Coordinator fail-over keeps every booking")
do
    local net = L.newNet(SN)
    net:add("Alpha", "ogr"); net:add("Bravo", "ogr"); net:add("Charlie", "ogr")
    net:tick(3)
    net.nodes.Charlie:Register("Keep1", "ogr"); net:pump()
    net.nodes.Charlie:Register("Keep2", "ogr"); net:pump(); net:tick(2)
    net:join("Keep1"); net:tick(2)
    local before = net.nodes.Charlie:Find("Keep1")
    L.eq(before.state, "ASSIGNED")
    net:kill("Alpha")
    net:tick(50)                               -- Alpha silent > LIVE
    L.eq(net.nodes.Bravo.coord, "Bravo", "next-ranked member takes over")
    L.eq(net.nodes.Charlie.coord, "Bravo")
    L.check(net.nodes.Bravo:Find("Keep1") ~= nil and net.nodes.Bravo:Find("Keep2") ~= nil, "state preserved")
    -- Alpha owned Keep1 (round robin first); ownership moves to a live Warlock.
    local k1 = net.nodes.Charlie:Find("Keep1")
    L.check(k1.owner ~= "Alpha", "bookings of the dead owner are reassigned: " .. tostring(k1.owner))
    -- New customers keep flowing, round robin continues without duplicates.
    net.nodes.Charlie:Register("New1", "ogr"); net:pump(); net:tick(2)
    net.nodes.Bravo:Register("New2", "ogr"); net:pump(); net:tick(2)
    local n = 0
    for _ in pairs(net.nodes.Charlie.bookings) do n = n + 1 end
    L.eq(n, 4, "no duplicate bookings after fail-over")
    L.check(net:consistent())
    L.check(net.nodes.Charlie:Find("New1").owner ~= "Alpha")
end

------------------------------------------------------------------------
L.section("Rejoin: restarted Warlock re-syncs, coordinator by manager list")
do
    local net = L.newNet(SN, { managers = { "Zed" } })
    net:add("Alpha", "ogr"); net:add("Zed", "ogr")
    net:tick(3)
    L.eq(net.nodes.Alpha.coord, "Zed", "configured manager outranks alphabet")
    net.nodes.Alpha:Register("Late1", "ogr"); net:pump(); net:tick(2)
    net:add("Bravo", "ogr"); net:tick(3)
    L.check(net.nodes.Bravo:Find("Late1") ~= nil, "new member received existing bookings via SYNC")
    L.eq(#net.nodes.Bravo:DestList(), 4, "and the destination config")
    L.check(net:consistent())
end

------------------------------------------------------------------------
L.section("Raid leader outranks plain members")
do
    local net = L.newNet(SN)
    net.leader = "Mike"
    net:add("Alpha", "ogr"); net:add("Mike", "ogr")
    net:tick(3)
    L.eq(net.nodes.Alpha.coord, "Mike", "leader coordinates")
end

------------------------------------------------------------------------
L.section("Unavailable Warlocks are skipped; unassigned bookings are picked up")
do
    local net = L.newNet(SN)
    net:add("Alpha", "ogr", "busy"); net:add("Bravo", "ogr", "available", 0); net:add("Charlie", "ogr")
    net:tick(3)
    net.nodes.Alpha:Register("S1", "ogr"); net:pump(); net:tick(2)
    L.eq(net.nodes.Alpha:Find("S1").owner, "Charlie", "skips busy and shardless Warlocks")
    -- Nobody available at uc: booking waits unassigned, then is assigned when someone arrives.
    net.nodes.Alpha:Register("S2", "uc"); net:pump(); net:tick(2)
    L.eq(net.nodes.Alpha:Find("S2").owner, nil)
    net:add("Dave", "uc"); net:tick(3)
    L.eq(net.nodes.Alpha:Find("S2").owner, "Dave", "assigned once a Warlock appears")
    net.nodes.Charlie:SetSelf("ogr", "offline", 5); net:pump()
    net.nodes.Alpha:Register("S3", "ogr"); net:pump(); net:tick(2)
    L.eq(net.nodes.Alpha:Find("S3").owner, nil, "offline Warlock does not receive customers")
    net.nodes.Alpha:SetSelf("ogr", "available", 3); net:pump(); net:tick(3)
    L.eq(net.nodes.Alpha:Find("S3").owner, "Alpha")
end

------------------------------------------------------------------------
L.section("Authorization and spoofing")
do
    local net = L.newNet(SN)
    net:add("Alpha", "ogr"); net:add("Bravo", "ogr"); net:add("Charlie", "ogr")
    net:tick(3)
    net.nodes.Alpha:Register("V1", "ogr"); net:pump(); net:tick(2)
    local b = net.nodes.Alpha:Find("V1")
    -- A node with the wrong key is ignored entirely.
    local rogue = SN.Engine.New({ name = "Rogue", now = net.now, key = "wrong",
        send = function(raw) for _, o in ipairs(net.order) do net.queue[#net.queue + 1] = { from = "Rogue", to = o, raw = raw } end end })
    rogue:SetSelf("ogr", "available", 9)
    rogue:Send("EVT", { b.id, "cancel", "" })
    rogue:Send("HI", { 1, "ogr", "available", 9, 0 })
    net:pump(); net:tick(1)
    L.eq(net.nodes.Alpha:Find("V1").state, "AWAITING_INVITE", "wrong-key EVT ignored")
    L.check(not net.nodes.Alpha.members.Rogue, "wrong-key node is not a member")
    -- Replays of the same message are dropped.
    local before = #net.queue
    -- Non-owner, non-manager cannot cancel or mark paid.
    net.nodes.Charlie:Do(b.id, "cancel"); net:pump()
    L.eq(net.nodes.Alpha:Find("V1").state, "AWAITING_INVITE", "non-owner cannot cancel")
    net.nodes.Alpha:Do(b.id, "cancel"); net:pump()
    L.eq(net.nodes.Charlie:Find("V1").state, "CANCELLED", "owner can cancel")
    -- Whitelist enforcement
    local net2 = L.newNet(SN, { members = { "Alpha", "Bravo" } })
    net2:add("Alpha", "ogr"); net2:add("Bravo", "ogr"); net2:add("Mallory", "ogr")
    net2:tick(3)
    L.check(not net2.nodes.Alpha.members.Mallory, "non-allowlisted sender ignored")
end

------------------------------------------------------------------------
L.section("Reassign, redirect, requeue (authorised actions)")
do
    local net = L.newNet(SN, { managers = { "Alpha" } })
    net:add("Alpha", "ogr"); net:add("Bravo", "ogr"); net:add("Cu", "uc")
    net:tick(3)
    net.nodes.Bravo:Register("R1", "ogr"); net:pump(); net:tick(2)
    local b = net.nodes.Alpha:Find("R1")
    L.eq(b.owner, "Alpha")
    L.check(net.nodes.Alpha:Do(b.id, "reassign", "Bravo")); net:pump(); net:tick(2)
    L.eq(net.nodes.Cu:Find("R1").owner, "Bravo"); L.eq(net.nodes.Cu:Find("R1").state, "AWAITING_INVITE", "re-acked by the new owner")
    local ok = net.nodes.Alpha:Do(b.id, "reassign", "Ghost")
    L.check(not ok, "cannot reassign to unknown Warlock")
    net.nodes.Bravo:Do(b.id, "redirect", "uc"); net:pump(); net:tick(2)
    L.eq(net.nodes.Alpha:Find("R1").dest, "uc"); L.eq(net.nodes.Alpha:Find("R1").owner, "Cu", "re-routed to the other city's Warlock")
    net.nodes.Cu:Do(b.id, "cancel"); net:pump()
    L.eq(net.nodes.Alpha:Find("R1").state, "CANCELLED")
    net.nodes.Alpha:Do(b.id, "requeue"); net:pump(); net:tick(2)
    L.eq(net.nodes.Bravo:Find("R1").state, "AWAITING_INVITE", "requeued and re-assigned")
end

------------------------------------------------------------------------
L.section("Disconnect recovery, no-show timeout, partial payments")
do
    local net = L.newNet(SN)
    net:add("Alpha", "ogr"); net:add("Bravo", "ogr")
    net:tick(3)
    net.nodes.Bravo:Register("D1", "ogr"); net:pump(); net:tick(1)
    net:join("D1"); net:tick(2)
    L.eq(net.nodes.Bravo:Find("D1").state, "ASSIGNED")
    net:leave("D1"); net:tick(8)
    L.eq(net.nodes.Bravo:Find("D1").state, "DISCONNECTED")
    net:join("D1"); net:tick(2)
    L.eq(net.nodes.Bravo:Find("D1").state, "ASSIGNED", "recovered when the customer returns")
    net:leave("D1"); net:tick(200)
    L.eq(net.nodes.Alpha:Find("D1").state, "NO_SHOW", "no-show after disconnect timeout")
    L.eq(#net.finals.Alpha, 1)

    -- invite never accepted
    net.nodes.Alpha:Register("D2", "ogr"); net:pump(); net:tick(2)
    net.nodes.Alpha:Do(net.nodes.Alpha:Find("D2").id, "invite"); net:pump()
    net:tick(200)
    L.eq(net.nodes.Bravo:Find("D2").state, "NO_SHOW", "invite timeout")

    -- partial payment keeps the job open
    net.nodes.Alpha:Register("D3", "ogr"); net:pump(); net:tick(2)
    local b = net.nodes.Alpha:Find("D3")
    net:join("D3"); net:tick(2)
    local owner = net.nodes[b.owner]
    owner:Do(b.id, "begin"); net:pump(); owner:Do(b.id, "summoned"); net:pump(); owner:Do(b.id, "arrived"); net:pump()
    owner:Do(b.id, "paid", 1000); net:pump()
    L.eq(net.nodes.Alpha:Find("D3").state, "PAYMENT_PENDING", "short payment is not completion")
    owner:Do(b.id, "markpaid"); net:pump()
    L.eq(net.nodes.Alpha:Find("D3").state, "PAID")
    L.eq(net.nodes.Alpha:Find("D3").got, 1000, "records what was actually received")

    -- ritual that never completes is aborted back to the queue
    net.nodes.Alpha:Register("D4", "ogr"); net:pump(); net:tick(2)
    local b4 = net.nodes.Alpha:Find("D4"); net:join("D4"); net:tick(2)
    net.nodes[b4.owner]:Do(b4.id, "begin"); net:pump()
    L.eq(net.nodes.Alpha:Find("D4").state, "SUMMONING")
    net:tick(100)
    L.eq(net.nodes.Alpha:Find("D4").state, "ASSIGNED", "stuck SUMMONING aborts")
end

------------------------------------------------------------------------
L.section("Config changes: only the party/raid leader, replicated to everyone")
do
    local net = L.newNet(SN)
    net.leader = "Alpha"
    net:add("Alpha", "ogr"); net:add("Bravo", "ogr")
    net:tick(3)
    L.eq(net.nodes.Bravo.coord, "Alpha", "leader coordinates")
    L.check(net.nodes.Alpha:EditDest({ key = "ogr", name = "Orgrimmar", zone = "Orgrimmar", price = 5000, aliases = { "org", "og" }, enabled = true, order = 1 }))
    net:pump()
    L.eq(net.nodes.Bravo.dests.ogr.price, 5000, "leader price change replicated")
    L.eq(net.nodes.Bravo.dests.ogr.aliases[2], "og")
    local ok = net.nodes.Bravo:EditDest({ key = "ogr", name = "Orgrimmar", zone = "Orgrimmar", price = 1, aliases = {}, enabled = true, order = 1 })
    L.check(not ok, "non-leader edit refused locally")
    net.nodes.Bravo:Send("SETDST", { "ogr", "Orgrimmar", 1, "Orgrimmar", "", 1, 1 })   -- forged request
    net:pump()
    L.eq(net.nodes.Alpha.dests.ogr.price, 5000, "non-leader SETDST ignored by the coordinator")
    L.check(not net.nodes.Bravo:RemoveDest("ogr"), "non-leader cannot remove destinations")
    -- leadership moves: the new leader may edit, the old one may not
    net.leader = "Bravo"
    net:tick(40)
    L.eq(net.nodes.Alpha.coord, "Bravo", "new leader becomes coordinator")
    L.check(net.nodes.Bravo:EditDest({ key = "ogr", name = "Orgrimmar", zone = "Orgrimmar", price = 4000, aliases = {}, enabled = true, order = 1 }))
    net:pump()
    L.eq(net.nodes.Alpha.dests.ogr.price, 4000)
    L.check(not net.nodes.Alpha:EditDest({ key = "ogr", name = "x", price = 1 }), "old leader refused")
    net.nodes.Bravo:Register("Z1", "ogr"); net:pump(); net:tick(2)
    L.eq(net.nodes.Alpha:Find("Z1").price, 4000, "price locked at booking time")

    local snap = net.nodes.Bravo:Export()
    L.check(#snap.bookings == 1)
    net:kill("Bravo")
    local net2 = L.newNet(SN)
    local n = net2:add("Bravo", "ogr")
    n:Import(snap)
    L.check(n:Find("Z1") ~= nil, "restored after reload")
    net2:tick(30)
    L.check(n:Find("Z1") ~= nil, "kept while it is the only node (coordinator)")
end

return L
