-- Minimal test harness + loader for pure-Lua modules. Run: lua tests/run.lua (from addon/SummonNetwork)
local print = print
local L = {}

L.pass, L.fail = 0, 0

function L.check(cond, msg)
    if cond then
        L.pass = L.pass + 1
    else
        L.fail = L.fail + 1
        print("  FAIL: " .. tostring(msg))
        print("  " .. (debug.traceback("", 2):gsub("\n", "\n  ")))
    end
end

function L.eq(a, b, msg)
    L.check(a == b, (msg or "") .. " expected <" .. tostring(b) .. "> got <" .. tostring(a) .. ">")
end

function L.section(name) print("== " .. name) end

-- Fresh addon namespace with all pure modules loaded.
function L.newSN()
    local SN = {}
    for _, f in ipairs({ "Util", "Parse", "Protocol", "Queue", "Engine", "Ads", "Stats" }) do
        local chunk = assert(loadfile("./" .. f .. ".lua"))
        chunk("SummonNetwork", SN)
    end
    return SN
end

------------------------------------------------------------------------
-- Multi-node network simulator
------------------------------------------------------------------------
function L.newNet(SN, opts)
    opts = opts or {}
    local net = { nodes = {}, order = {}, t = opts.t0 or 1800000000, queue = {}, roster = {}, leader = nil,
        key = opts.key or "secret", finals = {} }
    function net.now() return net.t end

    function net:add(name, dest, status, shards)
        local node
        local cfg = { managers = opts.managers or {}, requireShards = true, members = opts.members }
        local finals = {}
        net.finals[name] = finals
        node = SN.Engine.New({
            name = name, now = net.now, key = net.key,
            cfg = function() return cfg end,
            groupInfo = function() return { inGroup = true, leader = net.leader, roster = net.roster } end,
            send = function(raw)
                for _, other in ipairs(net.order) do
                    if other ~= name and net.nodes[other].up then
                        net.queue[#net.queue + 1] = { from = name, to = other, raw = raw }
                    end
                end
            end,
            onFinal = function(b) finals[#finals + 1] = b.id end,
            log = opts.log,
        })
        node:SetDestinations(opts.dests or {
            { key = "ogr", name = "Orgrimmar", zone = "Orgrimmar", price = 3000, aliases = { "org" }, enabled = true },
            { key = "uc", name = "Undercity", zone = "Undercity", price = 3000, aliases = {}, enabled = true },
            { key = "tb", name = "Thunder Bluff", zone = "Thunder Bluff", price = 3000, aliases = {}, enabled = true },
            { key = "sw", name = "Stormwind", zone = "Stormwind City", price = 5000, aliases = {}, enabled = true },
        })
        node.up = true
        node.cfg = cfg
        net.nodes[name] = node
        net.order[#net.order + 1] = name
        node:SetSelf(dest, status or "available", shards or 5)
        net:pump()
        return node
    end

    function net:pump()
        local guard = 0
        while #net.queue > 0 do
            guard = guard + 1
            assert(guard < 100000, "message storm")
            local m = table.remove(net.queue, 1)
            local n = net.nodes[m.to]
            if n and n.up then n:Receive(m.from, m.raw) end
        end
    end

    function net:tick(seconds, step)
        step = step or 1
        for _ = 1, seconds, step do
            net.t = net.t + step
            for _, name in ipairs(net.order) do
                if net.nodes[name].up then net.nodes[name]:Tick() end
            end
            net:pump()
        end
    end

    function net:kill(name) net.nodes[name].up = false end
    function net:join(cust) net.roster[string.lower(cust)] = true end
    function net:leave(cust) net.roster[string.lower(cust)] = nil end

    -- Every live node must hold identical (id, v, state, owner) for every booking.
    function net:consistent()
        local ref
        for _, name in ipairs(net.order) do
            local n = net.nodes[name]
            if n.up then
                local sig = {}
                for id, b in pairs(n.bookings) do
                    if SN.Queue.IsActive(b) then sig[#sig + 1] = id .. ":" .. b.v .. ":" .. b.state .. ":" .. tostring(b.owner) end
                end
                table.sort(sig)
                local s = table.concat(sig, ",")
                if ref == nil then ref = s elseif ref ~= s then return false, name .. " differs:\n" .. s .. "\nvs\n" .. ref end
            end
        end
        return true
    end

    return net
end

return L
