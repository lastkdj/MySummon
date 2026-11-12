-- Queue.lua: booking (customer) state machine. Pure Lua, no WoW API.
--
--   REQUESTED -> AWAITING_INVITE -> INVITED -> IN_GROUP -> ASSIGNED/WAITING
--   -> SUMMONING -> SUMMONED -> PAYMENT_PENDING -> PAID
--   Terminal: PAID, CANCELLED, NO_SHOW.   Recoverable: DISCONNECTED.
--
-- Q.Apply(booking, event, arg, now) mutates the booking and returns true, or false, reason.
local _, SN = ...
SN = SN or {}
local U = SN.Util
local Q = {}
SN.Queue = Q

Q.STATES = {
    "REQUESTED", "AWAITING_INVITE", "INVITED", "IN_GROUP", "ASSIGNED", "WAITING",
    "SUMMONING", "SUMMONED", "PAYMENT_PENDING", "PAID", "CANCELLED", "DISCONNECTED", "NO_SHOW",
}

Q.LABEL = {
    REQUESTED = "Requested", AWAITING_INVITE = "Awaiting invite", INVITED = "Invited",
    IN_GROUP = "In group", ASSIGNED = "Assigned", WAITING = "Waiting",
    SUMMONING = "Summoning", SUMMONED = "Awaiting arrival", PAYMENT_PENDING = "Payment pending",
    PAID = "Paid / completed", CANCELLED = "Cancelled", DISCONNECTED = "Disconnected", NO_SHOW = "No-show",
}

-- r,g,b used by the UI status pills.
Q.COLOR = {
    REQUESTED = { 0.60, 0.60, 0.70 }, AWAITING_INVITE = { 0.95, 0.75, 0.25 }, INVITED = { 0.95, 0.60, 0.20 },
    IN_GROUP = { 0.40, 0.75, 0.95 }, ASSIGNED = { 0.35, 0.85, 0.55 }, WAITING = { 0.55, 0.65, 0.80 },
    SUMMONING = { 0.75, 0.40, 0.95 }, SUMMONED = { 0.60, 0.50, 0.95 }, PAYMENT_PENDING = { 1.00, 0.82, 0.20 },
    PAID = { 0.30, 0.90, 0.35 }, CANCELLED = { 0.55, 0.55, 0.55 }, DISCONNECTED = { 0.90, 0.35, 0.35 },
    NO_SHOW = { 0.80, 0.25, 0.25 },
}

Q.TERMINAL = { PAID = true, CANCELLED = true, NO_SHOW = true }

-- States where the customer is not yet in the ritual pipeline (can still be redirected/reassigned freely).
Q.PRE_SUMMON = {
    REQUESTED = true, AWAITING_INVITE = true, INVITED = true, IN_GROUP = true, ASSIGNED = true, WAITING = true,
}

-- Customer-message flag bits stored in booking.msgs (dedupes whispers across coordinator changes).
Q.MSG = { REGISTERED = 1, ASSIGNED = 2, READY = 4, ARRIVED = 8, PAID = 16, ENDED = 32, REMIND = 64 }

function Q.IsActive(b) return b and not Q.TERMINAL[b.state] end

function Q.New(id, cust, dest, price, recv, now)
    return {
        id = id, v = 1, cust = cust, dest = dest, owner = nil, ack = false,
        state = "REQUESTED", ps = "", pay = "", price = price or 0, got = 0,
        recv = recv or "", created = now, begun = 0, done = 0, msgs = 0,
    }
end

local function finish(b, now) b.done = now end

local A = {}

function A.ack(b)
    if not b.owner then return false, "no owner" end
    b.ack = true
    if b.state == "REQUESTED" then b.state = "AWAITING_INVITE" end
    return true
end

function A.invite(b)
    if b.state == "AWAITING_INVITE" or b.state == "INVITED" then
        b.state = "INVITED"
        return true
    end
    if b.state == "REQUESTED" then return false, "summoner has not confirmed yet" end
    return false, "not awaiting invite"
end

function A.joined(b)
    if b.state == "REQUESTED" or b.state == "AWAITING_INVITE" or b.state == "INVITED" then
        b.state = "IN_GROUP"
        return true
    end
    return false, "not waiting to join"
end

function A.promote(b, arg)
    if arg ~= "ASSIGNED" and arg ~= "WAITING" then return false, "bad target" end
    if b.state == "IN_GROUP" or b.state == "ASSIGNED" or b.state == "WAITING" then
        if not (b.owner and b.ack) then return false, "owner not confirmed" end
        b.state = arg
        return true
    end
    return false, "cannot promote"
end

function A.begin(b, _, now)
    if b.state ~= "ASSIGNED" then return false, "customer is not next in line" end
    b.state = "SUMMONING"
    if b.begun == 0 then b.begun = now end
    return true
end

function A.abort(b)
    if b.state ~= "SUMMONING" then return false, "not summoning" end
    b.state = "ASSIGNED"
    return true
end

function A.summoned(b)
    if b.state == "SUMMONING" or b.state == "ASSIGNED" then
        b.state = "SUMMONED"
        return true
    end
    return false, "not summoning"
end

local ARRIVABLE = { IN_GROUP = true, ASSIGNED = true, WAITING = true, SUMMONING = true, SUMMONED = true }

local function settle(b, now)
    -- Called when a customer is at the destination: complete free/prepaid jobs automatically.
    if b.price <= 0 then
        b.state, b.pay = "PAID", "free"
        finish(b, now)
    elseif b.got >= b.price then
        b.state, b.pay = "PAID", "paid"
        finish(b, now)
    else
        b.state = "PAYMENT_PENDING"
    end
end

function A.arrived(b, _, now)
    if not ARRIVABLE[b.state] then return false, "cannot mark arrived" end
    if b.begun == 0 then b.begun = now end
    settle(b, now)
    return true
end

local PAYABLE = {
    IN_GROUP = true, ASSIGNED = true, WAITING = true, SUMMONING = true, SUMMONED = true, PAYMENT_PENDING = true,
}

-- arg = copper actually received through a completed trade.
function A.paid(b, arg, now)
    if not PAYABLE[b.state] then return false, "not payable in this state" end
    local amt = math.floor(tonumber(arg) or 0)
    if amt <= 0 then return false, "no payment" end
    b.got = b.got + amt
    -- Money received before arrival is credited; arrival (A.arrived) then settles the job.
    if b.state == "PAYMENT_PENDING" then settle(b, now) end
    return true
end

-- Owner confirms a manual/short payment as complete (Mark Paid / accept partial).
function A.markpaid(b, arg, now)
    if not PAYABLE[b.state] then return false, "not payable in this state" end
    local amt = tonumber(arg)
    if amt and amt > 0 then b.got = b.got + math.floor(amt) end
    b.state, b.pay = "PAID", "paid"
    if b.got == 0 then b.got = b.price end
    finish(b, now)
    return true
end

function A.unpaid(b, _, now)
    if b.state ~= "PAYMENT_PENDING" and b.state ~= "SUMMONED" then return false, "nothing to write off" end
    b.state, b.pay = "PAID", "unpaid"
    finish(b, now)
    return true
end

function A.discount(b, arg, now)
    if Q.TERMINAL[b.state] then return false, "already finished" end
    local p = math.floor(tonumber(arg) or -1)
    if p < 0 then return false, "bad price" end
    b.price = p
    if p == 0 and (b.state == "PAYMENT_PENDING") then settle(b, now) end
    return true
end

function A.free(b, _, now)
    return A.discount(b, 0, now)
end

function A.cancel(b, _, now)
    if Q.TERMINAL[b.state] then return false, "already finished" end
    b.state = "CANCELLED"
    finish(b, now)
    return true
end

function A.noshow(b, _, now)
    if Q.TERMINAL[b.state] then return false, "already finished" end
    b.state = "NO_SHOW"
    finish(b, now)
    return true
end

local LEAVABLE = {
    IN_GROUP = true, ASSIGNED = true, WAITING = true, SUMMONING = true, SUMMONED = true, PAYMENT_PENDING = true,
}

function A.left(b)
    if not LEAVABLE[b.state] then return false, "not in group" end
    b.ps = (b.state == "SUMMONING") and "ASSIGNED" or b.state
    b.state = "DISCONNECTED"
    return true
end

function A.back(b)
    if b.state ~= "DISCONNECTED" then return false, "not disconnected" end
    if b.ps == "SUMMONED" or b.ps == "PAYMENT_PENDING" then b.state = b.ps else b.state = "IN_GROUP" end
    b.ps = ""
    return true
end

function A.requeue(b, _, now)
    if b.state ~= "DISCONNECTED" and b.state ~= "NO_SHOW" and b.state ~= "CANCELLED" then
        return false, "only disconnected, no-show or cancelled bookings can be requeued"
    end
    b.state, b.owner, b.ack = "REQUESTED", nil, false
    b.created, b.begun, b.done, b.msgs, b.pay, b.got, b.ps = now, 0, 0, 0, "", 0, ""
    return true
end

function A.reassign(b, arg)
    if Q.TERMINAL[b.state] then return false, "already finished" end
    if arg == nil or arg == "" then
        b.owner = nil
    else
        b.owner = arg
    end
    b.ack = false
    if b.state == "AWAITING_INVITE" then b.state = "REQUESTED" end
    return true
end

function A.redirect(b, arg)
    if not Q.PRE_SUMMON[b.state] and b.state ~= "DISCONNECTED" then return false, "too late to change destination" end
    if not arg or arg == "" then return false, "no destination" end
    b.dest, b.owner, b.ack = arg, nil, false
    if b.state == "AWAITING_INVITE" or b.state == "INVITED" then b.state = "REQUESTED" end
    if b.state == "ASSIGNED" or b.state == "WAITING" then b.state = "IN_GROUP" end
    return true
end

function A.msg(b, arg)
    local bit = tonumber(arg)
    if not bit then return false, "bad flag" end
    b.msgs = U.SetAdd(b.msgs, bit)
    return true
end

-- Events that never travel over the network (generated by the coordinator itself).
Q.INTERNAL = { joined = true, left = true, back = true, promote = true }

function Q.Apply(b, event, arg, now)
    local fn = A[event]
    if not fn then return false, "unknown event " .. tostring(event) end
    return fn(b, arg, now)
end

function Q.Order(a, b)
    if a.created ~= b.created then return a.created < b.created end
    return a.id < b.id
end

-- Text summarising a booking for whispers/logs.
function Q.Describe(b)
    return string.format("%s -> %s [%s] owner=%s", b.cust, b.dest, Q.LABEL[b.state] or b.state, b.owner or "-")
end

return Q
