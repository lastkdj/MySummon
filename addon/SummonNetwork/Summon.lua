-- Summon.lua: the secure Ritual of Summoning button and pre-cast checks.
--
-- COMPLIANCE: the spell is cast only by the player clicking a SecureActionButtonTemplate
-- button (a hardware click). This file never calls CastSpellByName/TargetUnit or any other
-- protected function from insecure code. Attributes are changed only out of combat.
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "Summon.lua" end
SN = SN or {}
local Q, API, G = SN.Queue, SN.API, SN.Groups
local S = {}
SN.Summon = S

local buttons = {}
local lastClick = 0
local wantRefresh = false

-- Which booking would the button summon right now?
function S.Target()
    local E = SN.engine
    local sel = SN.selected and E.bookings[SN.selected]
    if sel and sel.owner == SN.me and (sel.state == "ASSIGNED" or sel.state == "SUMMONING") then return sel end
    local best
    for _, b in ipairs(E:Mine()) do
        if b.state == "SUMMONING" then return b end
        if b.state == "ASSIGNED" and (not best or Q.Order(b, best)) then best = b end
    end
    return best
end

-- Returns ok, reason (reason is shown on the disabled button).
function S.Check(b)
    if not b then return false, "No customer ready" end
    if b.owner ~= SN.me then return false, "Not your customer" end
    if b.state ~= "ASSIGNED" and b.state ~= "SUMMONING" then return false, "Customer not ready" end
    if API.InCombat() then return false, "In combat" end
    if API.IsDead() then return false, "You are dead" end
    local known = API.KnowsRitual()
    if not known then return false, "Ritual not known" end
    if API.Shards() < 1 then return false, "No Soul Shard" end
    local unit, u = G.UnitFor(b.cust)
    if not unit then return false, "Customer not in group" end
    if u and u.online == false then return false, "Customer offline" end
    return true
end

local function macroFor(b)
    local unit = G.UnitFor(b.cust)
    local spell = API.RitualName()
    if not unit or not spell then return nil end
    return "/target " .. unit .. "\n/cast " .. spell
end

-- Called out of combat only.
local function apply(btn)
    local b = S.Target()
    local ok, reason = S.Check(b)
    btn.snBooking = b and b.id or nil
    if ok then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", macroFor(b) or "")
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", "")
    end
    S.reason = ok and ("Click to cast Ritual of Summoning on " .. (b and b.cust or "") .. " - your helpers click the portal.") or reason
    if btn.snStyle then btn.snStyle(btn, ok, b) end
end

function S.Refresh()
    if API.InCombat() then
        wantRefresh = true
        return
    end
    wantRefresh = false
    for _, btn in ipairs(buttons) do apply(btn) end
end

function S.OnRegenEnabled()
    if wantRefresh then S.Refresh() end
end

-- Create a secure summon button with its own look (disabled/ready states).
function S.NewButton(parent, name, w, h, fontSize)
    local Kit = SN.Kit
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(w, h)
    btn:RegisterForClicks("AnyUp")
    Kit.Box(btn, Kit.C.panel, Kit.C.purple)
    btn.label = Kit.Text(btn, fontSize or 12, Kit.C.dim, "CENTER", true)
    btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.snStyle = function(self, ok, b)
        self.label:SetText(ok and ("SUMMON " .. (b and b.cust or "")) or "SUMMON")
        Kit.SetColor(self.bgTex, ok and { 0.30, 0.15, 0.55 } or { 0.10, 0.09, 0.13 })
        Kit.SetTextColor(self.label, ok and { 1, 0.95, 1 } or Kit.C.dim)
    end
    btn:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(S.reason or "")
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- PreClick runs insecurely just before the secure handler: refresh the macro with a fresh unit token.
    btn:SetScript("PreClick", function(self)
        if not API.InCombat() then apply(self) end
    end)
    btn:SetScript("PostClick", function(self)
        local E = SN.engine
        local b = self.snBooking and E.bookings[self.snBooking]
        if b and S.Check(b) then
            lastClick = GetTime()
            if b.state == "ASSIGNED" then E:Do(b.id, "begin") end
        end
    end)
    buttons[#buttons + 1] = btn
    return btn
end

-- Spell events (only meaningful for the owner of a SUMMONING booking).
local function isRitual(...)
    local name = API.RitualName()
    for i = 1, select("#", ...) do
        local a = select(i, ...)
        if a == API.RITUAL_SPELL_ID or (name and a == name) then return true end
    end
    return false
end

function S.OnCastSucceeded(unit, ...)
    if unit ~= "player" or not isRitual(...) then return end
    for _, b in ipairs(SN.engine:Mine()) do
        if b.state == "SUMMONING" or b.state == "ASSIGNED" then
            SN.engine:Do(b.id, "summoned")
            break
        end
    end
end

function S.OnCastFailed(unit, ...)
    if unit ~= "player" or not isRitual(...) then return end
    if (GetTime() - lastClick) > 15 then return end
    for _, b in ipairs(SN.engine:Mine()) do
        if b.state == "SUMMONING" then
            SN.engine:Do(b.id, "abort")
            break
        end
    end
end

-- Arrival polling for my bookings (zone match / trade distance).
function S.PollArrivals()
    local E = SN.engine
    for _, b in ipairs(E:Mine()) do
        if b.state == "SUMMONING" or b.state == "SUMMONED" then
            if G.HasArrived(b, E.dests[b.dest]) then E:Do(b.id, "arrived") end
        end
    end
end

return S
