-- Protocol.lua: addon message encoding/decoding (pure Lua).
-- Wire format:  TYPE|seq|field|field|...|mac
-- Fields are percent-escaped so they never contain "|", "%" or control characters.
-- mac = first 12 hex chars of Hash(key, sender, body); "-" when no network key is set.
local _, SN = ...
SN = SN or {}
local U = SN.Util
local P = {}
SN.Protocol = P

P.PREFIX = "SNET1"
P.VERSION = 1
P.MAX_LEN = 250 -- hard WoW limit is 255 bytes

local function esc(s)
    return (tostring(s):gsub("[%%|%c]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function unesc(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

P.Escape, P.Unescape = esc, unesc

function P.Mac(key, sender, body)
    if not key or key == "" then return "-" end
    return string.sub(U.Hash(key .. "\1" .. tostring(sender) .. "\1" .. body), 1, 12)
end

-- fields: dense array of strings/numbers. Returns msg or nil, err.
function P.Encode(mtype, seq, fields, key, sender)
    local parts = { mtype, tostring(seq) }
    for i = 1, #fields do parts[#parts + 1] = esc(fields[i]) end
    local body = table.concat(parts, "|")
    local msg = body .. "|" .. P.Mac(key, sender, body)
    if #msg > P.MAX_LEN then return nil, "too long (" .. #msg .. ")" end
    return msg
end

-- Returns true, mtype, seq, fields   or   false, reason
function P.Decode(msg, key, sender)
    if type(msg) ~= "string" or msg == "" then return false, "empty" end
    local parts = U.split(msg, "|")
    if #parts < 3 then return false, "malformed" end
    local mac = table.remove(parts)
    local body = table.concat(parts, "|")
    if key and key ~= "" then
        if mac ~= P.Mac(key, sender, body) then return false, "badmac" end
    end
    local mtype = table.remove(parts, 1)
    local seq = tonumber(table.remove(parts, 1))
    if not seq or not mtype:match("^%u+$") then return false, "malformed" end
    for i = 1, #parts do parts[i] = unesc(parts[i]) end
    return true, mtype, seq, parts
end

return P
