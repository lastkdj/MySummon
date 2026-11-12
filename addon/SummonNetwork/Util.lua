-- Util.lua: pure helpers (no WoW API). Testable with standalone Lua 5.1.
local _, SN = ...
SN = SN or {}
local U = {}
SN.Util = U

function U.trim(s)
    s = tostring(s or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

-- Split on a plain single-character separator, keeping empty fields.
function U.split(s, sep)
    local out, from = {}, 1
    while true do
        local i = string.find(s, sep, from, true)
        if not i then
            out[#out + 1] = string.sub(s, from)
            break
        end
        out[#out + 1] = string.sub(s, from, i - 1)
        from = i + #sep
    end
    return out
end

-- "Name-Realm" -> "Name". Cross-realm names are reduced to the character name.
function U.Short(name)
    if not name then return nil end
    return (tostring(name):match("^([^%-]+)") or tostring(name))
end

function U.lower(s) return string.lower(tostring(s or "")) end

function U.copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = U.copy(v) end
    return o
end

-- Fill missing keys of dst from defaults (deep). Never overwrites existing values.
function U.fill(dst, defaults)
    for k, v in pairs(defaults) do
        if dst[k] == nil then
            dst[k] = U.copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            U.fill(dst[k], v)
        end
    end
    return dst
end

------------------------------------------------------------------------
-- Money (all amounts are integer copper)
------------------------------------------------------------------------
function U.FormatMoney(c)
    c = math.floor(tonumber(c) or 0)
    if c <= 0 then return "0c" end
    local g = math.floor(c / 10000)
    local s = math.floor((c % 10000) / 100)
    local cc = c % 100
    local t = {}
    if g > 0 then t[#t + 1] = g .. "g" end
    if s > 0 then t[#t + 1] = s .. "s" end
    if cc > 0 then t[#t + 1] = cc .. "c" end
    return table.concat(t, " ")
end

function U.MoneyWords(c)
    c = math.floor(tonumber(c) or 0)
    if c <= 0 then return "0 copper" end
    local g = math.floor(c / 10000)
    local s = math.floor((c % 10000) / 100)
    local cc = c % 100
    local t = {}
    if g > 0 then t[#t + 1] = g .. " gold" end
    if s > 0 then t[#t + 1] = s .. " silver" end
    if cc > 0 then t[#t + 1] = cc .. " copper" end
    return table.concat(t, " ")
end

local UNIT = { g = 10000, gold = 10000, s = 100, silver = 100, c = 1, copper = 1 }

-- "30s", "1g 5s", "30 silver", "2.5g", "50c". A bare number means silver.
function U.ParseMoney(str)
    str = U.lower(U.trim(str))
    if str == "" then return nil end
    local total, found = 0, 0
    local pos = 1
    while pos <= #str do
        local a, b, num, unit = string.find(str, "^%s*(%d+%.?%d*)%s*(%a*)", pos)
        if not a then break end
        local mult
        if unit == "" then
            mult = 100
            if found > 0 then return nil end
        else
            mult = UNIT[unit]
            if not mult then return nil end
        end
        total = total + tonumber(num) * mult
        found = found + 1
        pos = b + 1
    end
    if found == 0 then return nil end
    if string.find(string.sub(str, pos), "%S") then return nil end
    return math.floor(total + 0.5)
end

------------------------------------------------------------------------
-- Misc
------------------------------------------------------------------------
local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
function U.B36(n, width)
    n = math.floor(n)
    local s = ""
    repeat
        local d = n % 36
        s = string.sub(B36, d + 1, d + 1) .. s
        n = math.floor(n / 36)
    until n == 0
    while width and #s < width do s = "0" .. s end
    return s
end

-- Keyed 64-bit-ish checksum. This is an integrity/anti-spoof check against casual
-- tampering, NOT cryptographic security. See docs/PROTOCOL.md.
function U.Hash(s)
    local h1, h2 = 5381, 52711
    for i = 1, #s do
        local b = string.byte(s, i)
        h1 = (h1 * 33 + b) % 4294967296
        h2 = (h2 * 131 + b + i) % 4294967296
    end
    return string.format("%08x%08x", h1, h2)
end

function U.SetHas(m, bit) return math.floor((m or 0) / bit) % 2 == 1 end
function U.SetAdd(m, bit)
    m = m or 0
    if U.SetHas(m, bit) then return m end
    return m + bit
end

function U.Fmt(template, vars)
    return (tostring(template):gsub("{(%w+)}", function(k)
        local v = vars[k]
        if v == nil then return "{" .. k .. "}" end
        return tostring(v)
    end))
end

function U.Duration(sec)
    sec = math.floor(tonumber(sec) or 0)
    if sec < 0 then sec = 0 end
    if sec < 60 then return sec .. "s" end
    if sec < 3600 then return math.floor(sec / 60) .. "m" .. string.format("%02d", sec % 60) .. "s" end
    return math.floor(sec / 3600) .. "h" .. string.format("%02d", math.floor((sec % 3600) / 60)) .. "m"
end

return U
