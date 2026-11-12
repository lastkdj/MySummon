-- Engine.lua: network synchronisation engine (pure Lua, no WoW API).
--
-- One coordinator (elected deterministically) owns every booking mutation and
-- replicates the full booking record ("BK") to all Warlocks. Everyone else sends
-- requests ("NEW", "EVT") to the coordinator. This gives:
--   * exactly one booking per customer (coordinator de-duplicates by name)
--   * exactly one owner per booking (coordinator assigns round-robin)
--   * deterministic fail-over (highest-ranked live member becomes coordinator)
-- All I/O is injected so the engine can be simulated with many nodes in tests.
local _, SN = ...
SN = SN or {}
local U, Q, P = SN.Util, SN.Queue, SN.Protocol
local E = {}
E.__index = E
SN.Engine = E

E.LIVE = 35          -- seconds without HI before a member counts as offline
E.HI_EVERY = 10      -- heartbeat interval
E.FORGET = 300       -- drop member records after this long
E.PURGE = 3600       -- drop finished bookings from memory after this long

local function inList(list, name)
    if not list then return false end
    local l = U.lower(name)
    for _, n in ipairs(list) do
        if U.lower(n) == l then return true, _ end
    end
    return false
end

function E.New(o)
    local n = setmetatable({}, E)
    n.name = o.name
    n.now = o.now
    n.rawSend = o.send
    n.key = o.key or ""
    n.cfgFn = o.cfg or function() return {} end
    n.groupInfo = o.groupInfo or function() return { inGroup = false, roster = {} } end
    n.log = o.log or function() end
    n.onFinal = o.onFinal
    n.final = o.final or {}
    n.members, n.bookings, n.dests, n.destOrder = {}, {}, {}, {}
    n.rr, n.seen, n.listeners = {}, {}, {}
    n.tried, n.absent, n.syncServed, n.acking = {}, {}, {}, {}
    n.seqOut = math.floor(o.now()) * 100
    n.coord = n.name
    n.lastHi = -1000
    n.members[n.name] = { dest = "", status = "available", shards = 0, seen = o.now(), load = 0, ver = P.VERSION }
    return n
end

function E:C(k, default)
    local c = self.cfgFn()
    local v = c and c[k]
    if v == nil then return default end
    return v
end

function E:T() return math.floor(self.now()) end

function E:On(fn) self.listeners[#self.listeners + 1] = fn end

function E:Emit(kind, a, b, c)
    for _, fn in ipairs(self.listeners) do
        local ok, err = pcall(fn, kind, a, b, c)
        if not ok then self.log("listener error: " .. tostring(err)) end
    end
end

------------------------------------------------------------------------
-- Transport
------------------------------------------------------------------------
function E:Send(mtype, fields)
    self.seqOut = self.seqOut + 1
    local msg, err = P.Encode(mtype, self.seqOut, fields or {}, self.key, self.name)
    if not msg then
        self.log("encode failed: " .. tostring(err))
        return false
    end
    self.rawSend(msg)
    return true
end

function E:Receive(sender, raw)
    sender = U.Short(sender)
    if not sender or sender == self.name then return end
    local ok, mtype, seq, f = P.Decode(raw, self.key, sender)
    if not ok then
        self.log("dropped message from " .. tostring(sender) .. ": " .. tostring(mtype))
        return
    end
    local allow = self:C("members")
    if allow and #allow > 0 and not inList(allow, sender) then
        self.log("dropped message from non-member " .. sender)
        return
    end
    local w = self.seen[sender]
    if not w then
        w = { set = {}, list = {} }
        self.seen[sender] = w
    end
    if w.set[seq] then return end
    w.set[seq] = true
    w.list[#w.list + 1] = seq
    if #w.list > 128 then w.set[table.remove(w.list, 1)] = nil end
    local h = self["on" .. mtype]
    if h then
        local pok, err = pcall(h, self, sender, f)
        if not pok then self.log("handler " .. mtype .. " failed: " .. tostring(err)) end
    end
end

------------------------------------------------------------------------
-- Membership and election
------------------------------------------------------------------------
function E:IsLive(name)
    if name == self.name then return true end
    local m = self.members[name]
    return m ~= nil and (self.now() - m.seen) <= E.LIVE
end

function E:Touch(name)
    local m = self.members[name]
    if not m then
        m = { dest = "", status = "available", shards = 0, load = 0, ver = P.VERSION }
        self.members[name] = m
    end
    m.seen = self.now()
    return m
end

-- Coordinator preference: party/raid leader first, then listed managers (in order), then name.
function E:Rank(name)
    local gi = self.groupInfo()
    if gi and gi.leader and U.lower(gi.leader) == U.lower(name) then return "0" .. name end
    local idx = select(2, inList(self:C("managers"), name))
    if idx then return string.format("1%03d%s", idx, name) end
    return "2" .. name
end

-- Network configuration (prices, aliases, destinations) may only be changed by the party/raid
-- leader. Outside a group only this Warlock (or a listed manager) may change its own copy.
function E:CanConfig(name)
    local gi = self.groupInfo()
    if gi and gi.inGroup then
        return gi.leader ~= nil and U.lower(gi.leader) == U.lower(name)
    end
    return name == self.name or inList(self:C("managers"), name)
end

function E:IsCoord() return self.coord == self.name end

function E:IsAuthorized(name)
    if name == self.coord then return true end
    if inList(self:C("managers"), name) then return true end
    local gi = self.groupInfo()
    return gi and gi.leader and U.lower(gi.leader) == U.lower(name) or false
end

function E:Elect()
    local best, bestRank
    for name in pairs(self.members) do
        if self:IsLive(name) then
            local r = self:Rank(name)
            if not bestRank or r < bestRank then best, bestRank = name, r end
        end
    end
    best = best or self.name
    if best ~= self.coord then
        local old = self.coord
        self.coord = best
        if best == self.name then
            self:BecomeCoord()
        else
            self:Send("SYNC", {})
        end
        self:Emit("coord", best, old)
    end
end

function E:BecomeCoord()
    -- Rebuild round-robin pointers from the replicated history.
    for key in pairs(self.dests) do
        local newest
        for _, b in pairs(self.bookings) do
            if b.dest == key and b.owner and (not newest or Q.Order(newest, b)) then newest = b end
        end
        if newest then self.rr[key] = newest.owner end
    end
    self:SendConfig()
    for _, b in pairs(self.bookings) do
        if Q.IsActive(b) then self:Broadcast(b) end
    end
    self:AssignPending()
end

function E:SetSelf(dest, status, shards)
    local m = self.members[self.name]
    local changed = (m.dest ~= dest) or (m.status ~= status) or (m.shards ~= shards)
    m.dest, m.status, m.shards, m.seen = dest, status, shards or 0, self.now()
    if changed then
        self:SendHI()
        self:Emit("member", self.name)
        if self:IsCoord() then self:AssignPending() end
    end
end

function E:Load(name)
    local n = 0
    for _, b in pairs(self.bookings) do
        if b.owner == name and Q.IsActive(b) then n = n + 1 end
    end
    return n
end

function E:SendHI()
    local m = self.members[self.name]
    m.load = self:Load(self.name)
    self.lastHi = self.now()
    self:Send("HI", { P.VERSION, m.dest, m.status, m.shards, m.load })
end

function E:onHI(sender, f)
    local isNew = self.members[sender] == nil
    local m = self:Touch(sender)
    local dest, status, shards = f[2] or "", f[3] or "available", tonumber(f[4]) or 0
    local changed = isNew or m.dest ~= dest or m.status ~= status or m.shards ~= shards
    m.ver, m.dest, m.status, m.shards, m.load = tonumber(f[1]) or 1, dest, status, shards, tonumber(f[5]) or 0
    if isNew then self:SendHI() end
    self:Elect()
    if changed then
        self:Emit("member", sender)
        if self:IsCoord() then
            if isNew then self:SendConfig() end
            self:AssignPending()
        end
    end
end

-- Sorted list of live Warlocks.
function E:LiveMembers()
    local out = {}
    for name, m in pairs(self.members) do
        if self:IsLive(name) then
            out[#out + 1] = { name = name, dest = m.dest, status = m.status, shards = m.shards, load = m.load, ver = m.ver }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function E:Team(dest)
    local t = {}
    for _, m in ipairs(self:LiveMembers()) do
        if m.dest == dest then t[#t + 1] = m end
    end
    return t
end

-- Number of Warlocks at dest able to take new customers right now.
function E:Available(dest)
    local n = 0
    for _, m in ipairs(self:Team(dest)) do
        if m.status == "available" and (not self:C("requireShards", true) or (m.shards or 0) >= 1) then n = n + 1 end
    end
    return n
end

------------------------------------------------------------------------
-- Destinations (network configuration)
------------------------------------------------------------------------
function E:applyDest(d)
    local nd = {
        key = d.key, name = d.name, price = d.price, zone = d.zone or d.name,
        aliases = d.aliases or {}, enabled = d.enabled ~= false, order = d.order or 99,
    }
    if not self.dests[nd.key] then self.destOrder[#self.destOrder + 1] = nd.key end
    self.dests[nd.key] = nd
    table.sort(self.destOrder, function(a, b)
        local da, db = self.dests[a], self.dests[b]
        if da.order ~= db.order then return da.order < db.order end
        return a < b
    end)
end

function E:SetDestinations(list)
    self.dests, self.destOrder = {}, {}
    for i, d in ipairs(list or {}) do
        d.order = d.order or i
        self:applyDest(d)
    end
end

function E:DestList()
    local out = {}
    for _, k in ipairs(self.destOrder) do out[#out + 1] = self.dests[k] end
    return out
end

local function destFields(d)
    return { d.key, d.name, d.price, d.zone, table.concat(d.aliases or {}, ","), d.enabled and 1 or 0, d.order or 99 }
end

function E:SendConfig()
    for _, k in ipairs(self.destOrder) do self:Send("DST", destFields(self.dests[k])) end
end

local function destFromFields(f)
    local aliases = {}
    if f[5] and f[5] ~= "" then aliases = U.split(f[5], ",") end
    return {
        key = f[1], name = f[2], price = tonumber(f[3]) or 0, zone = f[4], aliases = aliases,
        enabled = f[6] ~= "0", order = tonumber(f[7]) or 99,
    }
end

-- Local edit (slash command / UI). The coordinator applies and broadcasts it;
-- other Warlocks ask the coordinator (which checks authorisation).
function E:EditDest(d)
    if not d.key or d.key == "" then return false, "no key" end
    if not self:CanConfig(self.name) then return false, "only the party/raid leader can change prices and destinations" end
    if self:IsCoord() then
        self:applyDest(d)
        self:Send("DST", destFields(self.dests[d.key]))
        self:Emit("config")
        return true
    end
    self:Send("SETDST", destFields(d)) -- the coordinator checks the leader and answers with DST
    self:Emit("config")
    return true
end

function E:RemoveDest(key)
    if not self:CanConfig(self.name) then return false, "only the party/raid leader can change destinations" end
    if self:IsCoord() then
        self:removeDest(key)
        self:Send("DELDST", { key })
    else
        self:Send("SETDEL", { key })
    end
    return true
end

function E:removeDest(key)
    self.dests[key] = nil
    for i, k in ipairs(self.destOrder) do
        if k == key then table.remove(self.destOrder, i) break end
    end
    self:Emit("config")
end

function E:onSETDST(sender, f)
    if self:IsCoord() and self:CanConfig(sender) then
        local d = destFromFields(f)
        self:applyDest(d)
        self:Send("DST", destFields(self.dests[d.key]))
        self:Emit("config")
    end
end

function E:onSETDEL(sender, f)
    if self:IsCoord() and self:CanConfig(sender) then
        self:removeDest(f[1])
        self:Send("DELDST", { f[1] })
    end
end

function E:onDST(sender, f)
    self:Touch(sender)
    self:Elect()
    if sender ~= self.coord then return end
    self:applyDest(destFromFields(f))
    self:Emit("config")
end

function E:onDELDST(sender, f)
    self:Touch(sender)
    self:Elect()
    if sender ~= self.coord then return end
    self:removeDest(f[1])
end

------------------------------------------------------------------------
-- Bookings
------------------------------------------------------------------------
function E:ActiveFor(cust, exceptId)
    local l = U.lower(cust)
    for id, b in pairs(self.bookings) do
        if id ~= exceptId and Q.IsActive(b) and U.lower(b.cust) == l then return b end
    end
    return nil
end

function E:Find(idOrName)
    if self.bookings[idOrName] then return self.bookings[idOrName] end
    local act = self:ActiveFor(idOrName)
    if act then return act end
    local l, best = U.lower(idOrName), nil
    for _, b in pairs(self.bookings) do
        if U.lower(b.cust) == l and (not best or b.created > best.created) then best = b end
    end
    return best
end

function E:NewId()
    local base = U.B36(self:T() - 1700000000, 5)
    for _ = 1, 20 do
        local id = base .. U.B36(math.random(0, 1295), 2)
        if not self.bookings[id] then return id end
    end
    return base .. U.B36(math.random(0, 46655), 3)
end

-- Called by whisper handling on whichever Warlock the customer whispered.
function E:Register(cust, dest)
    cust = U.Short(cust)
    local ex = self:ActiveFor(cust)
    if ex then return ex, "duplicate" end
    if not self.dests[dest] then return nil, "unknown destination" end
    if self:IsCoord() then return self:CreateBooking(cust, dest, self.name) end
    self:Send("NEW", { cust, dest })
    return nil, "sent"
end

function E:CreateBooking(cust, dest, recv)
    local ex = self:ActiveFor(cust)
    if ex then
        self:Broadcast(ex)
        return ex, "duplicate"
    end
    local d = self.dests[dest]
    if not d then return nil, "unknown destination" end
    local t = self:T()
    local b = Q.New(self:NewId(), cust, dest, d.price, recv, t)
    b.lseen, b.sat = t, t
    self.bookings[b.id] = b
    local owner = self:Pick(dest)
    if owner then Q.Apply(b, "reassign", owner, t) end
    self:Publish(b, nil, "new")
    return b, "created"
end

function E:onNEW(sender, f)
    if not self:IsCoord() then return end
    self:Touch(sender)
    self:CreateBooking(U.Short(f[1]), f[2], sender)
end

-- Round-robin owner for a destination among available members.
function E:Pick(dest, exclude)
    local cands = {}
    for name, m in pairs(self.members) do
        if self:IsLive(name) and m.dest == dest and m.status == "available"
            and (not self:C("requireShards", true) or (m.shards or 0) >= 1)
            and not (exclude and exclude[name]) then
            cands[#cands + 1] = name
        end
    end
    if #cands == 0 then return nil end
    table.sort(cands)
    local pick, last = cands[1], self.rr[dest]
    if last then
        for _, n in ipairs(cands) do
            if n > last then pick = n break end
        end
    end
    self.rr[dest] = pick
    return pick
end

local EVENT_BY_ANY_MEMBER = { invite = true, msg = true }

function E:Allowed(sender, b, ev)
    if sender == self.name and self:IsCoord() then return true end
    if sender ~= b.recv and not self.members[sender] then return false end
    if sender == b.owner or self:IsAuthorized(sender) then return true end
    return EVENT_BY_ANY_MEMBER[ev] == true
end

-- Public entry for every local action.
function E:Do(id, ev, arg)
    local b = self.bookings[id]
    if not b then return false, "unknown booking" end
    if Q.INTERNAL[ev] then return false, "internal event" end
    if self:IsCoord() then return self:Mutate(b, ev, arg, self.name) end
    if not self:Allowed(self.name, b, ev) then return false, "not authorised" end
    self:Send("EVT", { id, ev, arg == nil and "" or tostring(arg) })
    return true, "sent"
end

function E:onEVT(sender, f)
    if not self:IsCoord() then return end
    self:Touch(sender)
    local b = self.bookings[f[1]]
    local ev, arg = f[2], f[3]
    if not b or Q.INTERNAL[ev] then return end
    self:Mutate(b, ev, (arg ~= "" and arg) or nil, sender)
end

function E:Mutate(b, ev, arg, sender)
    if not self:Allowed(sender, b, ev) then return false, "not authorised" end
    if ev == "reassign" and arg and arg ~= "" and not self:IsLive(arg) then return false, "that Warlock is offline" end
    if ev == "redirect" then
        if not (arg and self.dests[arg]) then return false, "unknown destination" end
    end
    local old = b.state
    local ok, err = Q.Apply(b, ev, arg, self:T())
    if not ok then return false, err end
    if ev == "redirect" then b.price = self.dests[arg].price end
    b.v = b.v + 1
    b.lseen = self.now()
    if b.state ~= old then b.sat = self.now() end
    self:Publish(b, old, ev)
    return true
end

function E:Publish(b, old, ev)
    self:Broadcast(b)
    self:Notify(b, old, ev)
    self:AutoAck(b)
    self:Promote(b.dest)
end

function E:AutoAck(b)
    if b.owner == self.name and not b.ack and Q.IsActive(b) then
        local k = b.id .. ":" .. b.v
        if not self.acking[k] then
            self.acking[k] = true
            self:Do(b.id, "ack")
        end
    end
end

function E:Notify(b, old, ev)
    if Q.TERMINAL[b.state] and not self.final[b.id] then
        self.final[b.id] = true
        if self.onFinal then
            local ok, err = pcall(self.onFinal, b)
            if not ok then self.log("onFinal failed: " .. tostring(err)) end
        end
    end
    self:Emit("booking", b, old, ev)
end

local function bkFields(b)
    return {
        b.id, b.v, b.cust, b.dest, b.owner or "", b.ack and 1 or 0, b.state, b.ps or "", b.pay or "",
        b.price, b.got, b.recv or "", b.created, b.begun or 0, b.done or 0, b.msgs or 0,
    }
end

function E:Broadcast(b)
    if self:IsCoord() then self:Send("BK", bkFields(b)) end
end

local function recFromFields(f)
    local r = {
        id = f[1], v = tonumber(f[2]), cust = f[3], dest = f[4], owner = (f[5] ~= "" and f[5]) or nil,
        ack = f[6] == "1", state = f[7], ps = f[8], pay = f[9], price = tonumber(f[10]) or 0,
        got = tonumber(f[11]) or 0, recv = f[12], created = tonumber(f[13]) or 0,
        begun = tonumber(f[14]) or 0, done = tonumber(f[15]) or 0, msgs = tonumber(f[16]) or 0,
    }
    if not r.id or not r.v or not Q.LABEL[r.state or ""] then return nil end
    return r
end

function E:onBK(sender, f)
    local rec = recFromFields(f)
    if not rec then return end
    self:Touch(sender)
    self:Elect()
    if sender ~= self.coord then
        -- A lower-ranked node that believed it was coordinator (split brain): keep its bookings if new.
        if self:IsCoord() then self:MergeForeign(rec) end
        return
    end
    self:ApplyRecord(rec)
end

function E:MergeForeign(rec)
    if self.bookings[rec.id] or (Q.IsActive(rec) and self:ActiveFor(rec.cust)) then return end
    if not Q.IsActive(rec) then return end
    rec.v = rec.v + 1
    rec.lseen, rec.sat = self.now(), self.now()
    self.bookings[rec.id] = rec
    self:Publish(rec, nil, "merge")
end

function E:ApplyRecord(rec)
    local b = self.bookings[rec.id]
    if b and b.v >= rec.v then
        b.imported = nil
        return
    end
    if Q.IsActive(rec) then
        local other = self:ActiveFor(rec.cust, rec.id)
        if other then
            if Q.Order(rec, other) then
                local old = other.state
                other.state, other.done = "CANCELLED", self:T()
                self:Notify(other, old, "dup")
            else
                return
            end
        end
    end
    local old = b and b.state
    local now = self.now()
    if not b then
        b = rec
        self.bookings[rec.id] = b
        b.sat = now
    else
        for k, v in pairs(rec) do b[k] = v end
        b.owner = rec.owner
        if old ~= b.state then b.sat = now end
    end
    b.lseen, b.imported = now, nil
    self:Notify(b, old, "sync")
    self:AutoAck(b)
end

------------------------------------------------------------------------
-- Sync / recovery
------------------------------------------------------------------------
function E:RequestSync()
    self.syncDeadline = self.now() + 20
    self:Send("SYNC", {})
end

function E:onSYNC(sender)
    if not self:IsCoord() then return end
    self:Touch(sender)
    local t = self.now()
    if t - (self.syncServed[sender] or -100) < 10 then return end
    self.syncServed[sender] = t
    self:SendConfig()
    for _, b in pairs(self.bookings) do
        if Q.IsActive(b) or (t - (b.sat or t)) < 600 then self:Broadcast(b) end
    end
end

-- Snapshot of active bookings for /reload recovery.
function E:Export()
    local out = { bookings = {}, rr = U.copy(self.rr) }
    for _, b in pairs(self.bookings) do
        if Q.IsActive(b) then
            local c = U.copy(b)
            c.lseen, c.sat, c.imported = nil, nil, nil
            out.bookings[#out.bookings + 1] = c
        end
    end
    return out
end

function E:Import(snap)
    if type(snap) ~= "table" then return end
    local t = self.now()
    for _, b in ipairs(snap.bookings or {}) do
        if b.id and b.v and Q.LABEL[b.state or ""] and not self.bookings[b.id] then
            b.lseen, b.sat, b.imported = t, t, true
            self.bookings[b.id] = b
        end
    end
    for k, v in pairs(snap.rr or {}) do self.rr[k] = v end
    self.syncDeadline = t + 20
    self.hasImport = true
end

------------------------------------------------------------------------
-- Coordinator duties
------------------------------------------------------------------------
local WAIT_STATES = { IN_GROUP = true, ASSIGNED = true, WAITING = true, SUMMONING = true }

function E:Promote(dest)
    if not self:IsCoord() or self.promoting then return end
    self.promoting = true
    local list = {}
    for _, b in pairs(self.bookings) do
        if b.dest == dest and WAIT_STATES[b.state] and b.owner and b.ack then list[#list + 1] = b end
    end
    table.sort(list, Q.Order)
    local blocked = false
    for _, b in ipairs(list) do
        if b.state == "SUMMONING" then
            blocked = true
        else
            local want = blocked and "WAITING" or "ASSIGNED"
            blocked = true
            if b.state ~= want then self:Mutate(b, "promote", want, self.name) end
        end
    end
    self.promoting = false
end

function E:AssignPending()
    if not self:IsCoord() then return end
    local t = self.now()
    for _, b in pairs(self.bookings) do
        if Q.IsActive(b) and Q.PRE_SUMMON[b.state] then
            local o = b.owner
            local m = o and self.members[o]
            local ownerBad = o and (not self:IsLive(o) or (m and m.status == "offline"))
            local ackLate = o and not b.ack and (t - b.lseen) > self:C("ackTimeout", 15)
            if not o or ownerBad or ackLate then
                if ackLate or ownerBad then
                    self.tried[b.id] = self.tried[b.id] or {}
                    self.tried[b.id][o] = true
                end
                local pick = self:Pick(b.dest, self.tried[b.id])
                if pick ~= o and (pick or o) then
                    self:Mutate(b, "reassign", pick, self.name)
                end
            end
        end
    end
end

function E:SyncRoster()
    local gi = self.groupInfo()
    if not gi then return end
    local roster = gi.roster or {}
    local t = self.now()
    for _, b in pairs(self.bookings) do
        if Q.IsActive(b) then
            local here = roster[U.lower(b.cust)]
            if here then
                self.absent[b.id] = nil
                if b.state == "REQUESTED" or b.state == "AWAITING_INVITE" or b.state == "INVITED" then
                    self:Mutate(b, "joined", nil, self.name)
                elseif b.state == "DISCONNECTED" then
                    self:Mutate(b, "back", nil, self.name)
                end
            elseif gi.inGroup and (b.state == "IN_GROUP" or b.state == "ASSIGNED" or b.state == "WAITING"
                or b.state == "SUMMONING" or b.state == "SUMMONED" or b.state == "PAYMENT_PENDING") then
                self.absent[b.id] = self.absent[b.id] or t
                if t - self.absent[b.id] >= 5 then
                    self.absent[b.id] = nil
                    self:Mutate(b, "left", nil, self.name)
                end
            end
        end
    end
end

function E:Timeouts()
    local t = self.now()
    for id, b in pairs(self.bookings) do
        local age = t - (b.sat or t)
        if Q.IsActive(b) then
            if (b.state == "AWAITING_INVITE" or b.state == "INVITED") and age > self:C("inviteTimeout", 180) then
                self:Mutate(b, "noshow", nil, self.name)
            elseif b.state == "DISCONNECTED" and age > self:C("disconnectTimeout", 180) then
                self:Mutate(b, "noshow", nil, self.name)
            elseif b.state == "SUMMONED" and age > self:C("arrivalTimeout", 240) then
                self:Mutate(b, "noshow", nil, self.name)
            elseif b.state == "SUMMONING" and age > self:C("castTimeout", 90) then
                self:Mutate(b, "abort", nil, self.name)
            end
        elseif age > E.PURGE then
            self.bookings[id], self.tried[id], self.absent[id] = nil, nil, nil
        end
    end
end

function E:Tick()
    local t = self.now()
    for name, m in pairs(self.members) do
        if name ~= self.name and t - m.seen > E.FORGET then self.members[name] = nil end
    end
    self.members[self.name].seen = t
    self:Elect()
    if t - self.lastHi >= E.HI_EVERY then self:SendHI() end
    if self.syncDeadline and t > self.syncDeadline then
        self.syncDeadline = nil
        if not self:IsCoord() then
            -- Bookings restored from disk that the coordinator never confirmed are stale.
            for id, b in pairs(self.bookings) do
                if b.imported then self.bookings[id] = nil end
            end
        end
        self.hasImport = nil
    end
    if self:IsCoord() then
        self:SyncRoster()
        self:AssignPending()
        self:Timeouts()
        for _, k in ipairs(self.destOrder) do self:Promote(k) end
    end
end

------------------------------------------------------------------------
-- Queries for the UI
------------------------------------------------------------------------
function E:Queue(dest)
    local list = {}
    for _, b in pairs(self.bookings) do
        if Q.IsActive(b) and (dest == nil or b.dest == dest) then list[#list + 1] = b end
    end
    table.sort(list, Q.Order)
    return list
end

function E:Position(b)
    local n = 1
    for _, o in pairs(self.bookings) do
        if o.dest == b.dest and o.id ~= b.id and Q.IsActive(o) and Q.PRE_SUMMON[o.state]
            and o.state ~= "REQUESTED" and Q.Order(o, b) then
            n = n + 1
        end
    end
    return n
end

function E:Mine()
    local list = {}
    for _, b in pairs(self.bookings) do
        if b.owner == self.name and Q.IsActive(b) then list[#list + 1] = b end
    end
    table.sort(list, Q.Order)
    return list
end

-- The booking this Warlock should act on next.
function E:Next()
    local mine = self:Mine()
    local rank = { PAYMENT_PENDING = 1, SUMMONED = 2, SUMMONING = 3, ASSIGNED = 4, WAITING = 5, IN_GROUP = 6,
        INVITED = 7, AWAITING_INVITE = 8, REQUESTED = 9, DISCONNECTED = 10 }
    local best
    for _, b in ipairs(mine) do
        if not best or (rank[b.state] or 99) < (rank[best.state] or 99) then best = b end
    end
    return best
end

function E:Counts()
    local c = { waiting = 0, progress = 0, pay = 0, active = 0 }
    for _, b in pairs(self.bookings) do
        if Q.IsActive(b) then
            c.active = c.active + 1
            if b.state == "SUMMONING" or b.state == "SUMMONED" then
                c.progress = c.progress + 1
            elseif b.state == "PAYMENT_PENDING" then
                c.pay = c.pay + 1
            else
                c.waiting = c.waiting + 1
            end
        end
    end
    return c
end

-- Destinations currently able to take customers (enabled and at least one available Warlock).
function E:ActiveDests()
    local out = {}
    for _, k in ipairs(self.destOrder) do
        local d = self.dests[k]
        if d.enabled and self:Available(k) > 0 then out[#out + 1] = d end
    end
    return out
end

return E
