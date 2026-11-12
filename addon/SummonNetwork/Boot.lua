-- Boot.lua: loads first. Records which files started loading, captures errors that mention this
-- addon (including load-time errors), and provides /sumnet, a report that works even if later
-- files fail to load. Everything stays on this computer; nothing is sent to other players.
local _, SN = ...
SN = SN or {}
SN.boot = { "Boot.lua" }
SN.bootErrors = {}
SN.EXPECTED_FILES = 21

if geterrorhandler and seterrorhandler then
    local prev = geterrorhandler()
    seterrorhandler(function(msg)
        local s = tostring(msg)
        if s:find("SummonNetwork", 1, true) then
            SN.bootErrors[#SN.bootErrors + 1] = date("%H:%M:%S ") .. s:sub(1, 1500)
        end
        if prev then return prev(msg) end
    end)
end

local win
function SN.ShowText(title, text)
    if not win then
        win = CreateFrame("Frame", "SummonNetworkTextWindow", UIParent)
        win:SetSize(560, 340)
        win:SetPoint("CENTER")
        win:SetFrameStrata("DIALOG")
        local bg = win:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.04, 0.08, 0.97)
        win.title = win:CreateFontString(nil, "OVERLAY")
        win.title:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        win.title:SetPoint("TOPLEFT", 10, -8)
        local close = CreateFrame("Button", nil, win)
        close:SetSize(60, 20)
        close:SetPoint("TOPRIGHT", -6, -6)
        local ct = close:CreateFontString(nil, "OVERLAY")
        ct:SetFont(STANDARD_TEXT_FONT, 12, "")
        ct:SetAllPoints()
        ct:SetText("[close]")
        close:SetScript("OnClick", function() win:Hide() end)
        local sf = CreateFrame("ScrollFrame", nil, win)
        sf:SetPoint("TOPLEFT", 10, -32)
        sf:SetPoint("BOTTOMRIGHT", -10, 10)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFont(STANDARD_TEXT_FONT, 12, "")
        eb:SetWidth(530)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() win:Hide() end)
        sf:SetScrollChild(eb)
        win.edit = eb
        table.insert(UISpecialFrames, "SummonNetworkTextWindow")
    end
    win.title:SetText(title)
    win.edit:SetText(text)
    win:Show()
    win.edit:SetFocus()
    win.edit:HighlightText()
end

local function report()
    local L = {}
    local function add(s) L[#L + 1] = s end
    local v, build, _, toc = GetBuildInfo()
    add("Summon Network boot report")
    add(string.format("client %s build %s interface %s", tostring(v), tostring(build), tostring(toc)))
    local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if info then
        local name, _, _, loadable, reason = info("SummonNetwork")
        add(string.format("addon info: name=%s loadable=%s reason=%s", tostring(name), tostring(loadable), tostring(reason)))
    end
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if isLoaded then add("IsAddOnLoaded: " .. tostring(isLoaded("SummonNetwork"))) end
    add(string.format("files started: %d of %d (last: %s)", #SN.boot, SN.EXPECTED_FILES, tostring(SN.boot[#SN.boot])))
    add("order: " .. table.concat(SN.boot, ", "))
    add("slash /sn registered: " .. tostring(SlashCmdList and SlashCmdList["SUMMONNETWORK"] ~= nil))
    add("engine: " .. tostring(SN.engine ~= nil) .. "   dashboard frame: " .. tostring(_G.SummonNetworkFrame ~= nil))
    add("errors captured: " .. #SN.bootErrors)
    for _, e in ipairs(SN.bootErrors) do add(e) end
    if SN.Errors then for _, e in ipairs(SN.Errors()) do add(e) end end
    return table.concat(L, "\n")
end

SLASH_SUMNET1 = "/sumnet"
SlashCmdList["SUMNET"] = function() SN.ShowText("Summon Network report (Ctrl+C to copy)", report()) end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if #SN.boot < SN.EXPECTED_FILES then
        print(string.format("|cffff5555Summon Network:|r only %d of %d files loaded (stopped after %s). Type |cff9be85a/sumnet|r.",
            #SN.boot, SN.EXPECTED_FILES, tostring(SN.boot[#SN.boot])))
    end
end)
