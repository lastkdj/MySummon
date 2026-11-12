-- Stats.lua: business analytics over ledger entries (pure Lua).
-- A ledger entry is the final booking record:
--   { id, cust, dest, owner, state, pay, price, got, created, begun, done }
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "Stats.lua" end
SN = SN or {}
local S = {}
SN.Stats = S

function S.Entry(b)
    return {
        id = b.id, cust = b.cust, dest = b.dest, owner = b.owner or "", state = b.state, pay = b.pay or "",
        price = b.price or 0, got = b.got or 0, created = b.created or 0, begun = b.begun or 0, done = b.done or 0,
    }
end

-- since: optional epoch lower bound on entry.done/created.
function S.Compute(ledger, since)
    local r = {
        completed = 0, revenue = 0, paid = 0, free = 0, unpaid = 0, cancelled = 0, noshow = 0,
        byDest = {}, byWarlock = {}, customers = {}, customerCount = 0,
        waitTotal = 0, waitCount = 0, total = 0,
    }
    for _, e in ipairs(ledger or {}) do
        local when = (e.done and e.done > 0) and e.done or e.created
        if not since or (when or 0) >= since then
            r.total = r.total + 1
            if e.state == "PAID" then
                r.completed = r.completed + 1
                r.revenue = r.revenue + (e.got or 0)
                if e.pay == "paid" then r.paid = r.paid + 1
                elseif e.pay == "free" then r.free = r.free + 1
                elseif e.pay == "unpaid" then r.unpaid = r.unpaid + 1 end
                local d = r.byDest[e.dest] or { count = 0, revenue = 0 }
                d.count, d.revenue = d.count + 1, d.revenue + (e.got or 0)
                r.byDest[e.dest] = d
                local w = r.byWarlock[e.owner] or { count = 0, revenue = 0 }
                w.count, w.revenue = w.count + 1, w.revenue + (e.got or 0)
                r.byWarlock[e.owner] = w
                if not r.customers[string.lower(e.cust)] then
                    r.customers[string.lower(e.cust)] = true
                    r.customerCount = r.customerCount + 1
                end
                if e.begun and e.begun > 0 and e.created and e.begun >= e.created then
                    r.waitTotal = r.waitTotal + (e.begun - e.created)
                    r.waitCount = r.waitCount + 1
                end
            elseif e.state == "CANCELLED" then
                r.cancelled = r.cancelled + 1
            elseif e.state == "NO_SHOW" then
                r.noshow = r.noshow + 1
            end
        end
    end
    r.avgWait = (r.waitCount > 0) and (r.waitTotal / r.waitCount) or 0
    return r
end

-- Ledger helper: append unless id already present; keep newest `cap` entries.
function S.Append(ledger, entry, cap)
    for i = #ledger, math.max(1, #ledger - 200), -1 do
        if ledger[i].id == entry.id then return false end
    end
    ledger[#ledger + 1] = entry
    cap = cap or 2000
    while #ledger > cap do table.remove(ledger, 1) end
    return true
end

return S
