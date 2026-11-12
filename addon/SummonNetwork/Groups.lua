-- Groups.lua: party/raid roster snapshot, invite permissions, customer arrival detection.
local _, SN = ...
SN = SN or {}
local U, API = SN.Util, SN.API
local G = {}
SN.Groups = G

local cache, cacheAt = nil, -1
local function nowf() return GetTime and GetTime() or 0 end

-- Returns { inGroup, isRaid, size, max, leader, canInvite, canConvert, roster = {lowername=true},
--           units = { lowername = {unit, name, subgroup, zone, online} } }
function G.Info(force)
    local t = nowf()
    if cache and not force and (t - cacheAt) < 0.5 then return cache end
    local me = API.Player()
    local info = { inGroup = false, isRaid = false, size = 1, max = 5, roster = {}, units = {}, leader = nil,
        canInvite = true, canConvert = false }
    local lm = U.lower(me)
    info.roster[lm] = true
    info.units[lm] = { unit = "player", name = me, subgroup = 1, online = true }
    if API.IsInRaid() then
        info.inGroup, info.isRaid, info.max = true, true, 40
        local n = API.GroupSize()
        info.size = n
        local myRank = 0
        for i = 1, n do
            local name, rank, subgroup, _, _, _, zone, online = GetRaidRosterInfo(i)
            if name then
                name = U.Short(name)
                local l = U.lower(name)
                info.roster[l] = true
                info.units[l] = { unit = "raid" .. i, name = name, subgroup = subgroup, zone = zone, online = online ~= false }
                if rank == 2 then info.leader = name end
                if l == lm then myRank = rank or 0 end
            end
        end
        info.canInvite = myRank >= 1
    elseif API.IsInGroup() then
        info.inGroup = true
        local n = API.GroupSize()
        info.size = n
        local leaderMe = API.UnitIsLeader("player")
        if leaderMe then info.leader = me end
        info.canInvite = leaderMe
        info.canConvert = leaderMe
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists and UnitExists(u) then
                local name = U.Short(UnitName(u))
                if name then
                    local l = U.lower(name)
                    info.roster[l] = true
                    info.units[l] = { unit = u, name = name, subgroup = 1, online = UnitIsConnected == nil or UnitIsConnected(u) }
                    if API.UnitIsLeader(u) then info.leader = name end
                end
            end
        end
    end
    cache, cacheAt = info, t
    return info
end

function G.Invalidate() cache = nil end

function G.Full()
    local i = G.Info()
    return i.inGroup and i.size >= i.max
end

function G.UnitFor(name)
    local u = G.Info().units[U.lower(name)]
    return u and u.unit or nil, u
end

-- Customer arrival heuristics (UNVERIFIED on Forever, see docs/API-NOTES.md):
--   raid zone name matches the destination zone, or the customer is within trade distance.
function G.HasArrived(b, dest)
    local unit, u = G.UnitFor(b.cust)
    if not unit or unit == "player" then return false end
    if u and u.zone and dest and dest.zone and U.lower(u.zone) == U.lower(dest.zone) then return true end
    if CheckInteractDistance and unit then
        local ok, near = pcall(CheckInteractDistance, unit, 2)
        if ok and near then return true end
    end
    return false
end

return G
