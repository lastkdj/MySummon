-- Parse.lua: customer whisper parsing (pure Lua).
-- Recognises "inv ogr", "INV OGR", "inv orgrimmar", "invite uc please", etc.
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "Parse.lua" end
SN = SN or {}
local P = {}
SN.Parse = P

-- Lowercase, strip colour codes / hyperlinks, drop punctuation, collapse spaces.
function P.Normalize(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = string.lower(text)
    text = text:gsub("[^%a%d%s]", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^ ", ""):gsub(" $", "")
    return text
end

-- dests: array of { key=, name=, aliases={...} }.
-- Returns map normalizedAlias -> key. The key and the full name are always aliases.
function P.BuildAliasMap(dests)
    local map = {}
    for _, d in ipairs(dests or {}) do
        local list = { d.key, d.name }
        for _, a in ipairs(d.aliases or {}) do list[#list + 1] = a end
        for _, a in ipairs(list) do
            local n = P.Normalize(a)
            if n ~= "" and map[n] == nil then map[n] = d.key end
        end
    end
    return map
end

local INV_WORDS = { inv = true, invite = true, invites = true, inb = false }

-- Returns:
--   nil                  -> not an invite request (ignore)
--   "nodest"             -> invite request but no recognised destination
--   "dest", destKey      -> invite request for destKey
function P.Invite(text, aliasMap)
    local norm = P.Normalize(text)
    if norm == "" then return nil end
    local first, rest = norm:match("^(%S+)%s*(.*)$")
    if not first or not INV_WORDS[first] then return nil end
    if rest == "" then return "nodest" end
    local padded = " " .. rest .. " "
    local bestPos, bestKey, bestLen
    for alias, key in pairs(aliasMap) do
        local s = string.find(padded, " " .. alias .. " ", 1, true)
        if s and (not bestPos or s < bestPos or (s == bestPos and #alias > bestLen)) then
            bestPos, bestKey, bestLen = s, key, #alias
        end
    end
    if bestKey then return "dest", bestKey end
    return "nodest"
end

return P
