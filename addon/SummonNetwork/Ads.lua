-- Ads.lua: Trade-chat advertisement text builder (pure Lua).
-- Posting is always a player action; this only builds the text.
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "Ads.lua" end
SN = SN or {}
local U = SN.Util
local A = {}
SN.Ads = A

A.MAX = 255

-- dests: ordered list of ACTIVE destinations { key, name, price, aliases }.
-- opts: { prefix = "WTS SUMMONS", suffix = "Fast service!", cmd = "inv" }
function A.Build(dests, opts)
    opts = opts or {}
    local prefix = opts.prefix or "WTS SUMMONS"
    local suffix = opts.suffix or "Fast service!"
    local cmd = opts.cmd or "inv"
    if #dests == 0 then return nil, "no active destinations" end

    local samePrice = true
    for i = 2, #dests do
        if dests[i].price ~= dests[1].price then samePrice = false end
    end

    local function build(withNames, withPrices)
        local parts = {}
        for _, d in ipairs(dests) do
            local s = '"' .. cmd .. " " .. d.key .. '"'
            if withNames then s = s .. " for " .. d.name end
            if withPrices then s = s .. " (" .. U.FormatMoney(d.price) .. ")" end
            parts[#parts + 1] = s
        end
        local list
        if #parts == 1 then
            list = parts[1]
        elseif #parts == 2 then
            list = parts[1] .. " or " .. parts[2]
        else
            list = table.concat(parts, ", ", 1, #parts - 1) .. ", or " .. parts[#parts]
        end
        local head = prefix
        if samePrice then head = head .. " - " .. U.FormatMoney(dests[1].price) .. "!" else head = head .. "!" end
        return head .. " Need a quick summon? Whisper " .. list .. ". " .. suffix
    end

    local attempts = {
        { true, not samePrice }, { false, not samePrice }, { false, false },
    }
    for _, a in ipairs(attempts) do
        local s = build(a[1], a[2])
        if #s <= A.MAX then return s end
    end
    return string.sub(build(false, false), 1, A.MAX)
end

-- Slash-macro text that opens the same ad in the chat box (player still presses Enter).
function A.Macro() return "/sn ad" end

return A
