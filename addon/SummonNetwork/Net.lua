-- Net.lua: bridges the pure Engine to the WoW addon-message channels.
--   * picks the channel (RAID / PARTY, or GUILD in guild mode)
--   * throttles outgoing messages (token bucket, well under the client limits)
--   * feeds CHAT_MSG_ADDON into Engine:Receive
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "Net.lua" end
SN = SN or {}
local P, API = SN.Protocol, SN.API
local Net = {}
SN.Net = Net

local RATE, BURST = 6, 10     -- messages per second, burst capacity
local MAX_QUEUE = 300
local out, tokens, lastFill = {}, BURST, 0

function Net.Channel()
    local mode = SN.db and SN.db.channelMode or "GROUP"
    if mode == "GUILD" then
        if IsInGuild and IsInGuild() then return "GUILD" end
        return nil
    end
    if API.IsInRaid() then return "RAID" end
    if API.IsInGroup() then return "PARTY" end
    return nil
end

-- Engine "send" hook: queue the raw payload.
function Net.Send(raw)
    if #out >= MAX_QUEUE then table.remove(out, 1) end
    out[#out + 1] = raw
end

function Net.Pump(now)
    tokens = math.min(BURST, tokens + (now - lastFill) * RATE)
    lastFill = now
    if #out == 0 then return end
    local ch = Net.Channel()
    if not ch then
        -- Solo / no channel: the local engine is its own coordinator; nothing to send.
        out = {}
        return
    end
    while #out > 0 and tokens >= 1 do
        local raw = table.remove(out, 1)
        tokens = tokens - 1
        if not API.SendAddon(P.PREFIX, raw, ch) then
            SN.Log("addon message send failed on " .. ch)
        end
    end
end

function Net.QueueLength() return #out end

function Net.OnAddon(prefix, text, channel, sender)
    if prefix ~= P.PREFIX or not SN.engine then return end
    SN.engine:Receive(sender, text)
end

function Net.Init()
    local ok = API.RegisterPrefix(P.PREFIX)
    if not ok then SN.Log("could not register addon prefix " .. P.PREFIX) end
    lastFill = GetTime()
end

return Net
