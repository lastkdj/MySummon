-- UI/Kit.lua: small widget toolkit with a dark "shadow & fel" look. No external libraries.
local _, SN = ...
SN = SN or {}
local Kit = {}
SN.Kit = Kit

Kit.C = {
    bg      = { 0.045, 0.040, 0.065, 0.97 },
    panel   = { 0.085, 0.075, 0.115, 1.00 },
    panel2  = { 0.115, 0.100, 0.155, 1.00 },
    row     = { 0.075, 0.068, 0.100, 1.00 },
    row2    = { 0.095, 0.086, 0.125, 1.00 },
    border  = { 0.24, 0.19, 0.34, 1.00 },
    fel     = { 0.55, 0.92, 0.30 },
    purple  = { 0.64, 0.40, 0.96 },
    text    = { 0.93, 0.92, 0.97 },
    dim     = { 0.60, 0.58, 0.70 },
    gold    = { 1.00, 0.82, 0.25 },
    red     = { 0.92, 0.32, 0.32 },
    green   = { 0.32, 0.90, 0.42 },
    amber   = { 0.98, 0.70, 0.22 },
}
local C = Kit.C

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

function Kit.SetColor(tex, c, a)
    local r, g, b = c[1], c[2], c[3]
    local al = a or c[4] or 1
    if tex.SetColorTexture then tex:SetColorTexture(r, g, b, al) else tex:SetTexture(r, g, b, al) end
end

function Kit.Tex(parent, layer, c, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    Kit.SetColor(t, c, a)
    return t
end

-- Flat background + 1px border.
function Kit.Box(f, bg, border)
    f.bgTex = Kit.Tex(f, "BACKGROUND", bg or C.panel)
    f.bgTex:SetAllPoints(f)
    if border then
        local function edge(p1, p2, w, h)
            local t = Kit.Tex(f, "BORDER", border)
            t:SetPoint(p1, f, p1, 0, 0)
            t:SetPoint(p2, f, p2, 0, 0)
            if w then t:SetWidth(w) end
            if h then t:SetHeight(h) end
            return t
        end
        f.borders = {
            edge("TOPLEFT", "TOPRIGHT", nil, 1), edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
            edge("TOPLEFT", "BOTTOMLEFT", 1, nil), edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil),
        }
    end
    return f
end

function Kit.Frame(parent, w, h, bg, border, name)
    local f = CreateFrame("Frame", name, parent)
    if w then f:SetSize(w, h) end
    Kit.Box(f, bg, border)
    return f
end

function Kit.Text(parent, size, color, justify, outline)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 12, outline and "OUTLINE" or "")
    local c = color or C.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function Kit.SetTextColor(fs, c, a) fs:SetTextColor(c[1], c[2], c[3], a or c[4] or 1) end

local KINDS = {
    primary = { bg = { 0.20, 0.42, 0.14 }, hov = { 0.28, 0.58, 0.18 }, txt = { 0.88, 1, 0.78 } },
    danger  = { bg = { 0.42, 0.13, 0.14 }, hov = { 0.60, 0.18, 0.20 }, txt = { 1, 0.82, 0.82 } },
    ghost   = { bg = { 0.14, 0.12, 0.20 }, hov = { 0.22, 0.19, 0.32 }, txt = { 0.90, 0.88, 0.97 } },
    accent  = { bg = { 0.30, 0.18, 0.50 }, hov = { 0.42, 0.26, 0.70 }, txt = { 0.96, 0.92, 1 } },
    gold    = { bg = { 0.45, 0.34, 0.08 }, hov = { 0.62, 0.47, 0.10 }, txt = { 1, 0.95, 0.75 } },
}

local function paint(btn)
    local k = KINDS[btn.kind] or KINDS.ghost
    local c = k.bg
    if not btn.enabled then
        Kit.SetColor(btn.bgTex, { 0.10, 0.09, 0.13 })
        Kit.SetTextColor(btn.label, C.dim, 0.7)
    else
        if btn.hover then c = k.hov end
        if btn.selected then c = k.hov end
        Kit.SetColor(btn.bgTex, c)
        Kit.SetTextColor(btn.label, k.txt)
    end
end

-- kind: primary | danger | ghost | accent | gold
function Kit.Button(parent, text, w, h, onclick, kind, template)
    local b = CreateFrame("Button", nil, parent, template)
    b:SetSize(w, h)
    Kit.Box(b, C.panel, C.border)
    b.kind, b.enabled, b.hover = kind or "ghost", true, false
    b.label = Kit.Text(b, 11, C.text, "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(text or "")
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(self) self.hover = true; paint(self) end)
    b:SetScript("OnLeave", function(self) self.hover = false; paint(self) end)
    b:SetScript("OnClick", function(self, ...)
        if self.enabled and onclick then onclick(self, ...) end
    end)
    function b:SetLabel(t) self.label:SetText(t) end
    function b:SetKind(k) self.kind = k; paint(self) end
    function b:SetOn(on) self.enabled = on and true or false; paint(self) end
    function b:SetSelected(on) self.selected = on and true or false; paint(self) end
    function b:SetHandler(fn) onclick = fn end
    paint(b)
    return b
end

function Kit.EditBox(parent, w, h, onEnter)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w, h)
    Kit.Box(e, { 0.03, 0.028, 0.045, 1 }, C.border)
    e:SetFont(FONT, 11, "")
    e:SetTextColor(C.text[1], C.text[2], C.text[3])
    e:SetTextInsets(6, 6, 0, 0)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self)
        if onEnter then onEnter(self:GetText(), self) end
        self:ClearFocus()
    end)
    return e
end

------------------------------------------------------------------------
-- Popup menu (single shared instance)
------------------------------------------------------------------------
local menu
local function ensureMenu()
    if menu then return menu end
    menu = CreateFrame("Frame", "SummonNetworkMenu", UIParent)
    menu:SetFrameStrata("TOOLTIP")
    menu:Hide()
    Kit.Box(menu, C.panel2, C.purple)
    menu.items = {}
    menu.catcher = CreateFrame("Button", nil, UIParent)
    menu.catcher:SetAllPoints(UIParent)
    menu.catcher:SetFrameStrata("DIALOG")
    menu.catcher:Hide()
    menu.catcher:SetScript("OnClick", function() Kit.CloseMenu() end)
    return menu
end

function Kit.CloseMenu()
    if menu then menu:Hide(); menu.catcher:Hide() end
end

-- items: { { text=, func=, disabled=, color= }, ... }
function Kit.ShowMenu(anchor, items)
    local m = ensureMenu()
    local w, h = 170, 4
    for i, it in ipairs(items) do
        local row = m.items[i]
        if not row then
            row = Kit.Button(m, "", w - 8, 20, nil, "ghost")
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.label:SetJustifyH("LEFT")
            m.items[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -h)
        row:SetLabel(it.text)
        row:SetOn(not it.disabled)
        row:SetHandler(function() Kit.CloseMenu(); if it.func then it.func() end end)
        row:Show()
        h = h + 21
    end
    for i = #items + 1, #m.items do m.items[i]:Hide() end
    m:SetSize(w, h + 4)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    m.catcher:Show()
    m:Show()
end

------------------------------------------------------------------------
-- Toast notifications (top of screen, stackable, fade out)
------------------------------------------------------------------------
local toasts, toastHost = {}, nil
function Kit.Toast(text, kind)
    if not toastHost then
        toastHost = CreateFrame("Frame", "SummonNetworkToasts", UIParent)
        toastHost:SetSize(420, 200)
        toastHost:SetPoint("TOP", UIParent, "TOP", 0, -140)
        toastHost:SetFrameStrata("FULLSCREEN_DIALOG")
        toastHost:SetScript("OnUpdate", function(self, el)
            local now = GetTime()
            for i = #toasts, 1, -1 do
                local t = toasts[i]
                local age = now - t.born
                if age > 6 then
                    t:Hide(); table.remove(toasts, i)
                elseif age > 5 then
                    t:SetAlpha(6 - age)
                end
            end
            for i, t in ipairs(toasts) do
                t:ClearAllPoints()
                t:SetPoint("TOP", self, "TOP", 0, -(i - 1) * 34)
            end
        end)
    end
    if #toasts >= 5 then
        toasts[1]:Hide(); table.remove(toasts, 1)
    end
    local t = CreateFrame("Frame", nil, toastHost)
    t:SetSize(420, 30)
    local accent = (kind == "alert") and C.amber or C.fel
    Kit.Box(t, { 0.05, 0.045, 0.08, 0.96 }, accent)
    local bar = Kit.Tex(t, "ARTWORK", accent)
    bar:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
    bar:SetWidth(4)
    local fs = Kit.Text(t, 12, C.text, "LEFT")
    fs:SetPoint("LEFT", t, "LEFT", 12, 0)
    fs:SetPoint("RIGHT", t, "RIGHT", -8, 0)
    fs:SetText(text)
    t.born = GetTime()
    t:Show()
    toasts[#toasts + 1] = t
end

return Kit
