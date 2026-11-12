-- UI/Minimap.lua: draggable minimap button (no library dependency).
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "UI/Minimap.lua" end
SN = SN or {}
local Kit = SN.Kit
local M = {}
SN.Minimap = M

local btn

local function place()
    local angle = math.rad(SN.db.minimap.angle or 200)
    local r = 80
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function M.Init()
    if not Minimap then return end
    btn = CreateFrame("Button", "SummonNetworkMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20); bg:SetPoint("CENTER", 0, 0)
    Kit.SetColor(bg, { 0.08, 0.05, 0.12 }, 1)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20); icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_Twilight")
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            Kit.ShowMenu(self, {
                { text = "Available", func = function() SN.SetMyStatus("available") end },
                { text = "Busy", func = function() SN.SetMyStatus("busy") end },
                { text = "Offline", func = function() SN.SetMyStatus("offline") end },
                { text = "Compact mode", func = function() SN.UI.SetCompact(not SN.cdb.compact) end },
                { text = "Prepare Trade ad", func = function() SN.PrepareAd() end },
            })
        else
            SN.UI.Toggle()
        end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            SN.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            place()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Summon Network", 0.55, 0.92, 0.30)
        local e = SN.engine
        if e then
            local c = e:Counts()
            GameTooltip:AddLine(string.format("%d Warlocks online - %d waiting - %d pending payment", #e:LiveMembers(), c.waiting, c.pay), 1, 1, 1)
            GameTooltip:AddLine(e:IsCoord() and "You are the coordinator" or ("Coordinator: " .. tostring(e.coord)), 0.64, 0.4, 0.96)
        end
        GameTooltip:AddLine("Left-click: dashboard   Right-click: menu   Drag: move", 0.6, 0.6, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    place()
    btn:SetShown(not SN.db.minimap.hide)
end

return M
