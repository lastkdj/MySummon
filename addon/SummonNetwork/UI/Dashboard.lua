-- UI/Dashboard.lua: main dashboard (Queue / Cities / Stats / Ads / Setup) and compact mode.
-- UI files never mutate bookings themselves: they call SN.engine:Do(...) and SN.* helpers.
local _, SN = ...
SN = SN or {}
local U, Q, Kit = SN.Util, SN.Queue, SN.Kit
local C = Kit.C
local UI = {}
SN.UI = UI

local WIDTH, HEIGHT = 640, 500
local main, compact
local tabs, tabFrames = {}, {}
local lists = {}
local dirty, lastRefresh = true, 0
local tradeHint, tradeHintAt = nil, 0
local statsPeriod = "session"

function UI.Dirty() dirty = true end
function UI.IsShown() return main and main:IsShown() end

local function E() return SN.engine end
local function destName(key)
    local d = E().dests[key]
    return d and d.name or key
end

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

------------------------------------------------------------------------
-- Scrolling list of reusable rows
------------------------------------------------------------------------
local function NewList(parent, n, rowH, make, fill)
    local Lst = { rows = {}, offset = 0, data = {}, n = n }
    for i = 1, n do
        local r = make(parent, i)
        r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * rowH)
        r:SetSize(parent:GetWidth(), rowH - 2)
        Lst.rows[i] = r
    end
    Lst.hint = Kit.Text(parent, 10, C.dim, "RIGHT")
    Lst.hint:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 2)
    parent:EnableMouseWheel(true)
    parent:SetScript("OnMouseWheel", function(_, d)
        Lst.offset = clamp(Lst.offset - d, 0, math.max(0, #Lst.data - n))
        Lst:Refresh()
    end)
    function Lst:SetData(data)
        self.data = data
        self.offset = clamp(self.offset, 0, math.max(0, #data - n))
        self:Refresh()
    end
    function Lst:Refresh()
        for i, r in ipairs(self.rows) do
            local item = self.data[self.offset + i]
            if item then r:Show(); fill(r, item, self.offset + i) else r:Hide() end
        end
        local more = #self.data - (self.offset + n)
        self.hint:SetText(more > 0 and ("scroll: " .. more .. " more") or (self.offset > 0 and "scroll up" or ""))
    end
    return Lst
end

------------------------------------------------------------------------
-- Focus booking (selected row, else this Warlock's next job)
------------------------------------------------------------------------
function UI.Focus()
    local e = E()
    local sel = SN.selected and e.bookings[SN.selected]
    if sel and Q.IsActive(sel) then return sel end
    return e:Next()
end

local function act(b, ev, arg)
    local ok, why = E():Do(b.id, ev, arg)
    if not ok then SN.Alert(tostring(why or "failed"), "alert") end
    UI.Dirty()
end

local function liveMenu(b, onPick)
    local items = {}
    for _, m in ipairs(E():LiveMembers()) do
        items[#items + 1] = { text = string.format("%s  (%s, %s)", m.name, destName(m.dest), m.status),
            func = function() onPick(m.name) end }
    end
    return items
end

function UI.RowMenu(anchor, b)
    local items = {
        { text = "Select", func = function() SN.selected = b.id; UI.Dirty() end },
        { text = "Reassign summoner...", func = function() Kit.ShowMenu(anchor, liveMenu(b, function(n) act(b, "reassign", n) end)) end },
        { text = "Change destination...", func = function()
            local its = {}
            for _, d in ipairs(E():DestList()) do
                its[#its + 1] = { text = d.name, func = function() act(b, "redirect", d.key) end }
            end
            Kit.ShowMenu(anchor, its)
        end },
        { text = "Mark paid (manual)", func = function() act(b, "markpaid") end },
        { text = "Free summon", func = function() act(b, "free") end },
        { text = "50% discount", func = function() act(b, "discount", math.floor(b.price / 2)) end },
        { text = "Write off as unpaid", func = function() act(b, "unpaid") end },
        { text = "Whisper payment reminder", func = function() UI.Remind(b) end },
        { text = "Re-invite", func = function() SN.Whispers.Invite(b) end },
        { text = "Mark no-show", func = function() act(b, "noshow") end },
        { text = "Requeue", func = function() act(b, "requeue") end },
        { text = "Remove from group", func = function()
            local ok = SN.API.Uninvite(b.cust)
            if not ok then SN.Alert("Could not remove " .. b.cust .. " (leader only)", "alert") end
        end },
        { text = "Cancel booking", func = function() act(b, "cancel") end },
    }
    Kit.ShowMenu(anchor, items)
end

function UI.Remind(b)
    if not b then return end
    SN.Whispers.Reply(b.cust, "arrived", SN.Whispers.Vars(b))
end

local function primary(b)
    local me, info = SN.me, SN.Groups.Info()
    local mine = b.owner == me
    local s = b.state
    if s == "AWAITING_INVITE" or s == "INVITED" then
        if info.canInvite then
            return (s == "INVITED") and "Re-invite" or "Invite", function() SN.Whispers.Invite(b) end, "primary"
        end
    elseif s == "ASSIGNED" and mine then
        return "Select", function() SN.selected = b.id; UI.Dirty() end, "accent"
    elseif s == "SUMMONED" and mine then
        return "Arrived", function() act(b, "arrived") end, "ghost"
    elseif s == "PAYMENT_PENDING" and mine then
        return "Mark paid", function() act(b, "markpaid") end, "gold"
    elseif s == "DISCONNECTED" or s == "CANCELLED" or s == "NO_SHOW" then
        return "Requeue", function() act(b, "requeue") end, "ghost"
    elseif s == "REQUESTED" and not b.owner then
        return "Assign", nil, "accent"
    end
    return nil
end

------------------------------------------------------------------------
-- Queue tab
------------------------------------------------------------------------
local function makeQueueRow(parent)
    local r = CreateFrame("Button", nil, parent)
    Kit.Box(r, C.row)
    r.stripe = Kit.Tex(r, "ARTWORK", C.fel)
    r.stripe:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.stripe:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    r.stripe:SetWidth(3)
    r.hdr = Kit.Text(r, 12, C.gold, "LEFT", true)
    r.hdr:SetPoint("LEFT", r, "LEFT", 10, 0)
    r.name = Kit.Text(r, 12, C.text, "LEFT")
    r.name:SetPoint("LEFT", r, "LEFT", 10, 0); r.name:SetWidth(108)
    r.dest = Kit.Text(r, 10, C.dim, "LEFT")
    r.dest:SetPoint("LEFT", r, "LEFT", 122, 0); r.dest:SetWidth(52)
    r.owner = Kit.Text(r, 11, C.purple, "LEFT")
    r.owner:SetPoint("LEFT", r, "LEFT", 176, 0); r.owner:SetWidth(96)
    r.pill = Kit.Frame(r, 116, 18, C.row2)
    r.pill:SetPoint("LEFT", r, "LEFT", 276, 0)
    r.pillText = Kit.Text(r.pill, 10, C.text, "CENTER")
    r.pillText:SetAllPoints(r.pill)
    r.price = Kit.Text(r, 11, C.gold, "RIGHT")
    r.price:SetPoint("LEFT", r, "LEFT", 396, 0); r.price:SetWidth(62)
    r.act = Kit.Button(r, "", 78, 20, nil, "ghost")
    r.act:SetPoint("RIGHT", r, "RIGHT", -34, 0)
    r.more = Kit.Button(r, "...", 26, 20, nil, "ghost")
    r.more:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r:SetScript("OnClick", function(self)
        if self.booking then SN.selected = self.booking.id; UI.Dirty() end
    end)
    return r
end

local function fillQueueRow(r, item)
    if item.kind == "hdr" then
        r.booking = nil
        r.hdr:Show(); r.name:Hide(); r.dest:Hide(); r.owner:Hide(); r.pill:Hide(); r.price:Hide()
        r.act:Hide(); r.more:Hide()
        Kit.SetColor(r.bgTex, C.panel2)
        Kit.SetColor(r.stripe, C.gold)
        r.hdr:SetText(string.format("%s   |cff8d8aa0%d in queue  -  %s|r", string.upper(item.name), item.count, item.price))
        return
    end
    local b = item.b
    r.booking = b
    r.hdr:Hide(); r.name:Show(); r.dest:Show(); r.owner:Show(); r.pill:Show(); r.price:Show()
    local col = Q.COLOR[b.state] or C.dim
    Kit.SetColor(r.stripe, col)
    Kit.SetColor(r.bgTex, (SN.selected == b.id) and C.panel2 or C.row)
    r.name:SetText(b.cust)
    r.dest:SetText(b.dest)
    local ownerText = b.owner or "unassigned"
    if b.owner and not b.ack then ownerText = ownerText .. "?" end
    if b.owner == SN.me then ownerText = "|cff9be85a" .. ownerText .. "|r" end
    r.owner:SetText(ownerText)
    Kit.SetColor(r.pill.bgTex, col, 0.30)
    r.pillText:SetText(Q.LABEL[b.state] or b.state)
    Kit.SetTextColor(r.pillText, col)
    local paid = b.pay == "free" and "free" or U.FormatMoney(b.state == "PAID" and b.got or b.price)
    if b.state == "PAID" and b.pay == "unpaid" then paid = "unpaid" end
    r.price:SetText(paid)
    local label, fn, kind = primary(b)
    if label then
        r.act:Show(); r.act:SetLabel(label); r.act:SetKind(kind or "ghost")
        r.act:SetHandler(fn or function(self) Kit.ShowMenu(self, liveMenu(b, function(n) act(b, "reassign", n) end)) end)
    else
        r.act:Hide()
    end
    r.more:Show()
    r.more:SetHandler(function(self) UI.RowMenu(self, b) end)
end

local function queueData()
    local e, out = E(), {}
    local now = e.now()
    for _, key in ipairs(e.destOrder) do
        local rows, count = {}, 0
        for _, b in pairs(e.bookings) do
            if b.dest == key then
                local active = Q.IsActive(b)
                if active or (now - (b.sat or now)) < 120 then
                    rows[#rows + 1] = b
                    if active then count = count + 1 end
                end
            end
        end
        table.sort(rows, Q.Order)
        if #rows > 0 or e.dests[key].enabled then
            local d = e.dests[key]
            out[#out + 1] = { kind = "hdr", name = d.name, count = count, price = U.FormatMoney(d.price) }
            for _, b in ipairs(rows) do out[#out + 1] = { kind = "bk", b = b } end
        end
    end
    -- bookings whose destination was removed
    for _, b in pairs(e.bookings) do
        if Q.IsActive(b) and not e.dests[b.dest] then out[#out + 1] = { kind = "bk", b = b } end
    end
    return out
end

------------------------------------------------------------------------
-- Cities tab
------------------------------------------------------------------------
local function makeCityRow(parent)
    local r = Kit.Frame(parent, 10, 10, C.row)
    r.name = Kit.Text(r, 13, C.gold, "LEFT", true)
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -6); r.name:SetWidth(150)
    r.sub = Kit.Text(r, 10, C.dim, "LEFT")
    r.sub:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 10, 6); r.sub:SetWidth(150)
    r.team = Kit.Text(r, 11, C.text, "LEFT")
    r.team:SetPoint("TOPLEFT", r, "TOPLEFT", 168, -6); r.team:SetWidth(250); r.team:SetHeight(30)
    r.team:SetWordWrap(true); r.team:SetJustifyV("TOP")
    r.ready = Kit.Text(r, 11, C.green, "LEFT", true)
    r.ready:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 168, 6); r.ready:SetWidth(250)
    r.join = Kit.Button(r, "I'm here", 70, 20, nil, "accent")
    r.join:SetPoint("RIGHT", r, "RIGHT", -86, 0)
    r.toggle = Kit.Button(r, "Offered", 76, 20, nil, "ghost")
    r.toggle:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    return r
end

local STATUS_HEX = { available = "ff55ee66", busy = "fff0b030", offline = "ffee5555" }

local function fillCityRow(r, d)
    local e = E()
    local team = e:Team(d.key)
    local avail = e:Available(d.key)
    r.name:SetText(d.name)
    r.sub:SetText(string.format("%s   |cff8d8aa0inv %s|r", U.FormatMoney(d.price), d.key))
    local parts = {}
    for _, m in ipairs(team) do
        parts[#parts + 1] = string.format("|c%s%s|r |cff8d8aa0(%d)|r", STATUS_HEX[m.status] or "ffffffff", m.name, m.shards or 0)
    end
    r.team:SetText(#parts > 0 and table.concat(parts, "  ") or "|cff8d8aa0" .. SN.L.NO_TEAM .. "|r")
    local qn = #e:Queue(d.key)
    if #team >= 3 and avail >= 1 then
        Kit.SetTextColor(r.ready, C.green)
        r.ready:SetText(string.format("READY  %d/3 Warlocks   |  queue %d", #team, qn))
    elseif #team > 0 then
        Kit.SetTextColor(r.ready, C.amber)
        local need = math.max(0, 3 - #team)
        r.ready:SetText(need > 0 and string.format("NEEDS %d MORE   |  queue %d", need, qn)
            or string.format("NO ONE AVAILABLE   |  queue %d", qn))
    else
        Kit.SetTextColor(r.ready, C.red)
        r.ready:SetText("NO TEAM")
    end
    r.join:SetHandler(function() SN.SetMyDest(d.key) end)
    r.join:SetSelected(SN.cdb.dest == d.key)
    r.toggle:SetLabel(d.enabled and "Offered" or "Hidden")
    r.toggle:SetKind(d.enabled and "primary" or "ghost")
    r.toggle:SetHandler(function()
        local nd = U.copy(d); nd.enabled = not d.enabled
        SN.EditDest(nd)
    end)
end

------------------------------------------------------------------------
-- Stats tab
------------------------------------------------------------------------
local function buildStats(frame)
    frame.cols = {}
    local heads = { "TOTALS", "BY CITY", "BY WARLOCK" }
    local xs = { 8, 214, 420 }
    for i = 1, 3 do
        local h = Kit.Text(frame, 11, C.gold, "LEFT", true)
        h:SetPoint("TOPLEFT", frame, "TOPLEFT", xs[i], -6)
        h:SetText(heads[i])
        local fs = Kit.Text(frame, 11, C.text, "LEFT")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", xs[i], -26)
        fs:SetWidth(200); fs:SetHeight(120); fs:SetJustifyV("TOP"); fs:SetWordWrap(true)
        frame.cols[i] = fs
    end
    frame.recent = Kit.Text(frame, 10, C.dim, "LEFT")
    frame.recent:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -150)
    frame.recent:SetWidth(600); frame.recent:SetHeight(110); frame.recent:SetJustifyV("TOP"); frame.recent:SetWordWrap(true)
    frame.period = Kit.Button(frame, "Session", 80, 20, function(self)
        statsPeriod = (statsPeriod == "session") and "all" or "session"
        UI.Dirty()
    end, "ghost")
    frame.period:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
end

local function refreshStats(frame)
    frame.period:SetLabel(statsPeriod == "session" and "This session" or "All time")
    local s = SN.Stats.Compute(SN.db.ledger, statsPeriod == "session" and SN.sessionStart or nil)
    frame.cols[1]:SetText(table.concat({
        string.format("Summons completed: |cff9be85a%d|r", s.completed),
        string.format("Revenue: |cffffd040%s|r", U.FormatMoney(s.revenue)),
        string.format("Paid: %d   Free: %d   Unpaid: %d", s.paid, s.free, s.unpaid),
        string.format("Cancelled: %d   No-show: %d", s.cancelled, s.noshow),
        string.format("Customers served: %d", s.customerCount),
        string.format("Avg wait: %s", U.Duration(s.avgWait)),
        string.format("Success rate: %s", s.total > 0 and (math.floor(100 * s.completed / s.total) .. "%") or "-"),
    }, "\n"))
    local lines = {}
    for _, d in ipairs(E():DestList()) do
        local x = s.byDest[d.key]
        lines[#lines + 1] = string.format("%s: %d  (%s)", d.name, x and x.count or 0, U.FormatMoney(x and x.revenue or 0))
    end
    frame.cols[2]:SetText(table.concat(lines, "\n"))
    local names = {}
    for n in pairs(s.byWarlock) do names[#names + 1] = n end
    table.sort(names, function(a, b) return s.byWarlock[a].revenue > s.byWarlock[b].revenue end)
    lines = {}
    for i = 1, math.min(7, #names) do
        local x = s.byWarlock[names[i]]
        lines[#lines + 1] = string.format("%s: %d  (%s)", names[i], x.count, U.FormatMoney(x.revenue))
    end
    frame.cols[3]:SetText(#lines > 0 and table.concat(lines, "\n") or "|cff8d8aa0no data yet|r")
    local rec = {}
    local led = SN.db.ledger
    for i = #led, math.max(1, #led - 7), -1 do
        local e = led[i]
        rec[#rec + 1] = string.format("%s  %-12s -> %-14s  %-10s %s  %s", date and date("%H:%M", e.done > 0 and e.done or e.created) or "",
            e.cust, destName(e.dest), e.owner ~= "" and e.owner or "-", Q.LABEL[e.state] or e.state,
            e.state == "PAID" and U.FormatMoney(e.got) or "")
    end
    frame.recent:SetText("RECENT TRANSACTIONS\n" .. (#rec > 0 and table.concat(rec, "\n") or "none yet"))
end

------------------------------------------------------------------------
-- Ads tab
------------------------------------------------------------------------
local function buildAds(frame)
    local h = Kit.Text(frame, 11, C.gold, "LEFT", true)
    h:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6); h:SetText("TRADE CHAT ADVERTISEMENT")
    frame.preview = Kit.Text(frame, 12, C.text, "LEFT")
    frame.preview:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
    frame.preview:SetWidth(610); frame.preview:SetHeight(70); frame.preview:SetWordWrap(true); frame.preview:SetJustifyV("TOP")
    frame.info = Kit.Text(frame, 10, C.dim, "LEFT")
    frame.info:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -104); frame.info:SetWidth(610); frame.info:SetHeight(40)
    frame.info:SetWordWrap(true); frame.info:SetJustifyV("TOP")
    frame.post = Kit.Button(frame, "Prepare in Trade chat", 160, 26, function() SN.PrepareAd() end, "primary")
    frame.post:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -150)
    local l1 = Kit.Text(frame, 10, C.dim, "LEFT"); l1:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -190); l1:SetText("Ad start:")
    frame.prefix = Kit.EditBox(frame, 200, 22, function(t) SN.db.adPrefix = t; UI.Dirty() end)
    frame.prefix:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -204)
    local l2 = Kit.Text(frame, 10, C.dim, "LEFT"); l2:SetPoint("TOPLEFT", frame, "TOPLEFT", 220, -190); l2:SetText("Ad end:")
    frame.suffix = Kit.EditBox(frame, 300, 22, function(t) SN.db.adSuffix = t; UI.Dirty() end)
    frame.suffix:SetPoint("TOPLEFT", frame, "TOPLEFT", 220, -204)
    local note = Kit.Text(frame, 10, C.dim, "LEFT")
    note:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -236); note:SetWidth(610); note:SetHeight(30); note:SetWordWrap(true)
    note:SetText("Posting is always your own action: the button opens the chat box with the ad ready and you press Enter. Only destinations that currently have an available Warlock are advertised.")
end

local function refreshAds(frame)
    local ad, why = SN.BuildAd()
    frame.preview:SetText(ad or ("|cffee5555" .. tostring(why) .. "|r"))
    local left = SN.AdCooldownLeft()
    local ch, name = SN.API.TradeChannel()
    frame.info:SetText(string.format("%s%s   Macro: |cff9be85a/sn ad|r",
        ch and ("Trade channel: " .. name .. " (#" .. ch .. ").  ") or "|cffee5555Trade channel not joined - join it first.|r  ",
        left > 0 and string.format("Next ad suggested in %ds.", left) or "Ready to post."))
    frame.post:SetOn(ad ~= nil)
    if not frame.prefix:HasFocus() then frame.prefix:SetText(SN.db.adPrefix or "") end
    if not frame.suffix:HasFocus() then frame.suffix:SetText(SN.db.adSuffix or "") end
end

------------------------------------------------------------------------
-- Setup tab (generic edit/toggle rows)
------------------------------------------------------------------------
local function makeSetupRow(parent)
    local r = Kit.Frame(parent, 10, 10, C.row)
    r.label = Kit.Text(r, 11, C.text, "LEFT")
    r.label:SetPoint("LEFT", r, "LEFT", 10, 0); r.label:SetWidth(250)
    r.edit = Kit.EditBox(r, 340, 20, nil)
    r.edit:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.toggle = Kit.Button(r, "", 120, 20, nil, "ghost")
    r.toggle:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    return r
end

local function csv(t) return table.concat(t or {}, ", ") end
local function parseCsv(s)
    local out = {}
    for part in tostring(s):gmatch("[^,]+") do
        part = U.trim(part)
        if part ~= "" then out[#out + 1] = part end
    end
    return out
end

local function setupItems()
    local db, items = SN.db, {}
    local function sep(t) items[#items + 1] = { kind = "sep", label = t } end
    local function edit(label, get, set) items[#items + 1] = { kind = "edit", label = label, get = get, set = set } end
    local function toggle(label, get, set) items[#items + 1] = { kind = "toggle", label = label, get = get, set = set } end

    sep("NETWORK")
    edit("Network key (identical on every Warlock)", function() return db.key ~= "" and string.rep("*", 8) or "" end,
        function(t) if not t:match("^%*+$") then SN.SetKey(t) end end)
    edit("Managers (coordinator order, comma list)", function() return csv(db.managers) end,
        function(t) db.managers = parseCsv(t); UI.Dirty() end)
    edit("Warlock allow-list (empty = any keyed sender)", function() return csv(db.members) end,
        function(t) db.members = parseCsv(t); UI.Dirty() end)
    toggle("Network channel", function() return db.channelMode == "GUILD" end,
        function() db.channelMode = (db.channelMode == "GUILD") and "GROUP" or "GUILD" end)
    sep("BEHAVIOUR")
    toggle("Auto-invite customers", function() return db.autoInvite end, function(v) db.autoInvite = v end)
    toggle("Whisper customers", function() return db.whisperCustomers end, function(v) db.whisperCustomers = v end)
    toggle("Alert sounds", function() return db.sound end, function(v) db.sound = v end)
    toggle("Require a Soul Shard to take customers", function() return db.requireShards end, function(v) db.requireShards = v end)
    sep("DESTINATIONS")
    for _, d in ipairs(E():DestList()) do
        local key = d.key
        local function cur() return E().dests[key] end
        edit(d.name .. " - price (e.g. 30s)", function() return U.FormatMoney(cur().price) end, function(t)
            local c = U.ParseMoney(t)
            if c then local nd = U.copy(cur()); nd.price = c; SN.EditDest(nd) end
        end)
        edit(d.name .. " - aliases (comma list)", function() return csv(cur().aliases) end, function(t)
            local nd = U.copy(cur()); nd.aliases = parseCsv(t); SN.EditDest(nd)
        end)
        edit(d.name .. " - zone name", function() return cur().zone end, function(t)
            local nd = U.copy(cur()); nd.zone = U.trim(t); SN.EditDest(nd)
        end)
    end
    edit("Add destination: key, Name, Zone, price", function() return "" end, function(t)
        local p = parseCsv(t)
        if #p >= 2 then
            SN.EditDest({ key = U.lower(p[1]), name = p[2], zone = p[3] or p[2], price = U.ParseMoney(p[4] or "30s") or 3000,
                aliases = {}, enabled = true, order = #E():DestList() + 1 })
        end
    end)
    sep("CUSTOMER MESSAGES  ({dest} {price} {pricelong} {owner} {pos} {cust} {list})")
    for _, k in ipairs({ "registered", "assigned", "ready", "arrived", "paid", "ended", "help", "unavailable", "already" }) do
        edit("message: " .. k, function() return db.msgs[k] end, function(t) if t ~= "" then db.msgs[k] = t end end)
    end
    return items
end

local function fillSetupRow(r, it)
    if it.kind == "sep" then
        r.label:SetWidth(600)
        r.label:SetText("|cffffd040" .. it.label .. "|r")
        Kit.SetColor(r.bgTex, C.panel2)
        r.edit:Hide(); r.toggle:Hide()
        return
    end
    Kit.SetColor(r.bgTex, C.row)
    r.label:SetWidth(250)
    r.label:SetText(it.label)
    if it.kind == "edit" then
        r.toggle:Hide(); r.edit:Show()
        r.edit.snSet = it.set
        r.edit:SetScript("OnEnterPressed", function(self)
            if self.snSet then self.snSet(self:GetText()) end
            self:ClearFocus(); UI.Dirty()
        end)
        if not r.edit:HasFocus() then r.edit:SetText(it.get() or ""); r.edit:SetCursorPosition(0) end
    else
        r.edit:Hide(); r.toggle:Show()
        local v = it.get()
        if it.label == "Network channel" then
            r.toggle:SetLabel(v and "GUILD" or "GROUP (raid/party)")
        else
            r.toggle:SetLabel(v and "ON" or "OFF")
        end
        r.toggle:SetKind(v and "primary" or "ghost")
        r.toggle:SetHandler(function() it.set(not v); UI.Dirty() end)
    end
end

------------------------------------------------------------------------
-- Build main frame
------------------------------------------------------------------------
local function setTab(name)
    SN.cdb.ui.tab = name
    for key, f in pairs(tabFrames) do f:SetShown(key == name) end
    for key, b in pairs(tabs) do b:SetSelected(key == name); b:SetKind(key == name and "accent" or "ghost") end
    UI.Dirty()
end

local function newTile(parent, x, label, color)
    local t = Kit.Frame(parent, 99, 42, C.panel, C.border)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
    t.value = Kit.Text(t, 16, color or C.text, "CENTER", true)
    t.value:SetPoint("TOP", t, "TOP", 0, -6); t.value:SetWidth(95)
    t.label = Kit.Text(t, 9, C.dim, "CENTER")
    t.label:SetPoint("BOTTOM", t, "BOTTOM", 0, 5); t.label:SetWidth(95)
    t.label:SetText(label)
    return t
end

function UI.Build()
    local cdb = SN.cdb
    main = CreateFrame("Frame", "SummonNetworkFrame", UIParent)
    main:SetSize(WIDTH, HEIGHT)
    main:SetFrameStrata("MEDIUM")
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:EnableMouse(true)
    main:SetScale(cdb.ui.scale or 1)
    main:SetPoint(cdb.ui.point or "CENTER", UIParent, cdb.ui.point or "CENTER", cdb.ui.x or 0, cdb.ui.y or 0)
    Kit.Box(main, C.bg, C.border)
    main:Hide()

    -- header
    local head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
    head:SetHeight(38)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() main:StartMoving() end)
    head:SetScript("OnDragStop", function()
        main:StopMovingOrSizing()
        local p, _, _, x, y = main:GetPoint()
        cdb.ui.point, cdb.ui.x, cdb.ui.y = p, x, y
    end)
    local bar1 = Kit.Tex(head, "ARTWORK", C.fel)
    bar1:SetPoint("TOPLEFT", head, "TOPLEFT", 0, 0); bar1:SetPoint("TOPRIGHT", head, "TOP", 0, 0); bar1:SetHeight(2)
    local bar2 = Kit.Tex(head, "ARTWORK", C.purple)
    bar2:SetPoint("TOPLEFT", head, "TOP", 0, 0); bar2:SetPoint("TOPRIGHT", head, "TOPRIGHT", 0, 0); bar2:SetHeight(2)
    local title = Kit.Text(head, 16, C.fel, "LEFT", true)
    title:SetPoint("LEFT", head, "LEFT", 12, 2)
    title:SetText("SUMMON NETWORK")
    local sub = Kit.Text(head, 10, C.dim, "LEFT")
    sub:SetPoint("LEFT", title, "RIGHT", 10, -2)
    sub:SetText(SN.L.SUBTITLE .. "  v" .. (SN.version or ""))
    main.coord = Kit.Text(head, 11, C.purple, "RIGHT", true)
    main.coord:SetPoint("RIGHT", head, "RIGHT", -142, 0)
    local close = Kit.Button(head, "X", 22, 20, function() main:Hide() end, "danger")
    close:SetPoint("RIGHT", head, "RIGHT", -8, 0)
    local mini = Kit.Button(head, "_", 22, 20, function() UI.SetCompact(true) end, "ghost")
    mini:SetPoint("RIGHT", close, "LEFT", -4, 0)
    main.raidBtn = Kit.Button(head, "To raid", 58, 20, function()
        local ok = SN.API.ConvertToRaid()
        if not ok then SN.Alert("Could not convert to raid (leader only)", "alert") end
        SN.Groups.Invalidate(); UI.Dirty()
    end, "gold")
    main.raidBtn:SetPoint("RIGHT", mini, "LEFT", -4, 0)

    -- KPI strip
    local kpi = CreateFrame("Frame", nil, main)
    kpi:SetPoint("TOPLEFT", main, "TOPLEFT", 8, -44)
    kpi:SetSize(WIDTH - 16, 42)
    main.tiles = {
        warlocks = newTile(kpi, 0, "WARLOCKS ONLINE", C.purple),
        cities = newTile(kpi, 108, "ACTIVE CITIES", C.fel),
        waiting = newTile(kpi, 216, "CUSTOMERS WAITING", C.text),
        progress = newTile(kpi, 324, "SUMMONS IN PROGRESS", C.fel),
        pay = newTile(kpi, 432, "PAYMENTS PENDING", C.amber),
        revenue = newTile(kpi, 540, "REVENUE (SESSION)", C.gold),
    }

    -- tabs
    local tabBar = CreateFrame("Frame", nil, main)
    tabBar:SetPoint("TOPLEFT", main, "TOPLEFT", 8, -94)
    tabBar:SetSize(WIDTH - 16, 24)
    local order = { { "queue", "Queue" }, { "cities", "Cities" }, { "stats", "Stats" }, { "ads", "Advertise" }, { "setup", "Setup" } }
    for i, t in ipairs(order) do
        local b = Kit.Button(tabBar, t[2], 96, 24, function() setTab(t[1]) end, "ghost")
        b:SetPoint("LEFT", tabBar, "LEFT", (i - 1) * 100, 0)
        tabs[t[1]] = b
    end

    -- content
    local content = Kit.Frame(main, WIDTH - 16, 272, C.panel, C.border)
    content:SetPoint("TOPLEFT", main, "TOPLEFT", 8, -122)
    for _, t in ipairs(order) do
        local f = CreateFrame("Frame", nil, content)
        f:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
        f:SetSize(WIDTH - 24, 264)
        f:Hide()
        tabFrames[t[1]] = f
    end
    lists.queue = NewList(tabFrames.queue, 9, 29, makeQueueRow, fillQueueRow)
    lists.cities = NewList(tabFrames.cities, 6, 44, makeCityRow, fillCityRow)
    lists.setup = NewList(tabFrames.setup, 9, 29, makeSetupRow, fillSetupRow)
    buildStats(tabFrames.stats)
    buildAds(tabFrames.ads)
    main.empty = Kit.Text(tabFrames.queue, 12, C.dim, "CENTER")
    main.empty:SetPoint("CENTER", tabFrames.queue, "CENTER", 0, 0)
    main.empty:SetText(SN.L.NO_CUSTOMERS)

    -- footer (this Warlock)
    local foot = Kit.Frame(main, WIDTH - 16, 96, C.panel, C.border)
    foot:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 8, 8)
    local me = Kit.Text(foot, 10, C.gold, "LEFT", true)
    me:SetPoint("TOPLEFT", foot, "TOPLEFT", 10, -8); me:SetText("YOUR STATION")
    main.stat = {}
    for i, s in ipairs({ "available", "busy", "offline" }) do
        local b = Kit.Button(foot, string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2), 74, 22, function() SN.SetMyStatus(s) end,
            s == "available" and "primary" or (s == "busy" and "gold" or "danger"))
        b:SetPoint("TOPLEFT", foot, "TOPLEFT", 100 + (i - 1) * 78, -5)
        main.stat[s] = b
    end
    main.destBtn = Kit.Button(foot, "City", 150, 22, function(self)
        local its = {}
        for _, d in ipairs(E():DestList()) do
            its[#its + 1] = { text = d.name, func = function() SN.SetMyDest(d.key) end }
        end
        Kit.ShowMenu(self, its)
    end, "accent")
    main.destBtn:SetPoint("TOPLEFT", foot, "TOPLEFT", 340, -5)
    main.shards = Kit.Text(foot, 11, C.text, "LEFT")
    main.shards:SetPoint("TOPLEFT", foot, "TOPLEFT", 500, -9); main.shards:SetWidth(120)

    main.nextText = Kit.Text(foot, 12, C.text, "LEFT")
    main.nextText:SetPoint("TOPLEFT", foot, "TOPLEFT", 10, -36); main.nextText:SetWidth(WIDTH - 40)
    main.reason = Kit.Text(foot, 10, C.dim, "LEFT")
    main.reason:SetPoint("TOPLEFT", foot, "TOPLEFT", 10, -52); main.reason:SetWidth(WIDTH - 40)

    main.summon = SN.Summon.NewButton(foot, "SummonNetworkSummonButton", 190, 28, 12)
    main.summon:SetPoint("BOTTOMLEFT", foot, "BOTTOMLEFT", 8, 6)

    local function focusBtn(text, x, w, kind, fn)
        local b = Kit.Button(foot, text, w, 28, function()
            local f = UI.Focus()
            if f then fn(f) else SN.Alert("No customer selected", "alert") end
        end, kind)
        b:SetPoint("BOTTOMLEFT", foot, "BOTTOMLEFT", x, 6)
        return b
    end
    focusBtn("Mark Paid", 206, 90, "gold", function(f) act(f, "markpaid") end)
    focusBtn("Remind", 300, 70, "ghost", function(f) UI.Remind(f) end)
    focusBtn("Reassign", 374, 80, "accent", function(f)
        Kit.ShowMenu(main.destBtn, liveMenu(f, function(n) act(f, "reassign", n) end))
    end)
    focusBtn("Cancel", 458, 70, "danger", function(f) act(f, "cancel") end)
    focusBtn("Compact", 532, 80, "ghost", function() UI.SetCompact(true) end)

    -- Stats / data refresh loop
    main:SetScript("OnUpdate", function(_, el)
        if main:IsShown() and (dirty or GetTime() - lastRefresh > 1) then UI.Refresh() end
    end)
    table.insert(UISpecialFrames, "SummonNetworkFrame")
    setTab(cdb.ui.tab or "queue")
end

------------------------------------------------------------------------
-- Compact mode
------------------------------------------------------------------------
function UI.BuildCompact()
    local cdb = SN.cdb
    compact = CreateFrame("Frame", "SummonNetworkCompact", UIParent)
    compact:SetSize(300, 96)
    compact:SetFrameStrata("MEDIUM")
    compact:SetClampedToScreen(true)
    compact:SetMovable(true)
    compact:EnableMouse(true)
    compact:RegisterForDrag("LeftButton")
    compact:SetScript("OnDragStart", function() compact:StartMoving() end)
    compact:SetScript("OnDragStop", function()
        compact:StopMovingOrSizing()
        local p, _, _, x, y = compact:GetPoint()
        cdb.ui.cpoint, cdb.ui.cx, cdb.ui.cy = p, x, y
    end)
    compact:SetPoint(cdb.ui.cpoint or "CENTER", UIParent, cdb.ui.cpoint or "CENTER", cdb.ui.cx or 0, cdb.ui.cy or -200)
    Kit.Box(compact, C.bg, C.border)
    local bar = Kit.Tex(compact, "ARTWORK", C.fel)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(2)
    local t = Kit.Text(compact, 11, C.fel, "LEFT", true)
    t:SetPoint("TOPLEFT", compact, "TOPLEFT", 8, -7); t:SetText("SUMMON NETWORK")
    compact.who = Kit.Text(compact, 10, C.dim, "RIGHT")
    compact.who:SetPoint("TOPRIGHT", compact, "TOPRIGHT", -36, -8); compact.who:SetWidth(120)
    local ex = Kit.Button(compact, "+", 22, 18, function() UI.SetCompact(false) end, "ghost")
    ex:SetPoint("TOPRIGHT", compact, "TOPRIGHT", -6, -5)
    compact.line1 = Kit.Text(compact, 12, C.text, "LEFT")
    compact.line1:SetPoint("TOPLEFT", compact, "TOPLEFT", 8, -26); compact.line1:SetWidth(284)
    compact.line2 = Kit.Text(compact, 10, C.dim, "LEFT")
    compact.line2:SetPoint("TOPLEFT", compact, "TOPLEFT", 8, -42); compact.line2:SetWidth(284)
    compact.summon = SN.Summon.NewButton(compact, "SummonNetworkSummonButtonCompact", 170, 26, 11)
    compact.summon:SetPoint("BOTTOMLEFT", compact, "BOTTOMLEFT", 8, 8)
    local paid = Kit.Button(compact, "Paid", 54, 26, function()
        local f = UI.Focus()
        if f then act(f, "markpaid") end
    end, "gold")
    paid:SetPoint("BOTTOMLEFT", compact, "BOTTOMLEFT", 184, 8)
    local rem = Kit.Button(compact, "Msg", 48, 26, function() UI.Remind(UI.Focus()) end, "ghost")
    rem:SetPoint("BOTTOMLEFT", compact, "BOTTOMLEFT", 242, 8)
    compact:SetScript("OnUpdate", function()
        if compact:IsShown() and (dirty or GetTime() - lastRefresh > 1) then UI.Refresh() end
    end)
    compact:Hide()
end

function UI.SetCompact(on)
    SN.cdb.compact = on and true or false
    if on then
        main:Hide(); compact:Show()
    else
        compact:Hide(); main:Show()
    end
    UI.Dirty()
end

function UI.Toggle()
    if SN.cdb.compact then
        compact:SetShown(not compact:IsShown())
    else
        main:SetShown(not main:IsShown())
    end
    UI.Dirty()
end

function UI.Show(tab)
    if SN.cdb.compact then compact:Show() else main:Show() end
    if tab and tabFrames[tab] then setTab(tab) end
    UI.Dirty()
end

function UI.TradeHint(b, offered)
    local need = U.FormatMoney(b.price)
    tradeHint = string.format("Trade with %s: offering %s (needs %s)", b.cust, U.FormatMoney(offered or 0), need)
    tradeHintAt = GetTime()
    UI.Dirty()
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local function nextLines()
    local b = UI.Focus()
    if not b then return "No customer assigned to you", "Waiting for the next 'inv <city>' whisper.", nil end
    local line = string.format("%s%s  >  %s   |cff8d8aa0%s|r   %s", (SN.selected == b.id) and "|cffffd040> |r" or "", b.cust,
        destName(b.dest), Q.LABEL[b.state] or b.state, U.FormatMoney(b.price))
    local hint
    if tradeHint and (GetTime() - tradeHintAt) < 45 then hint = tradeHint end
    return line, hint, b
end

function UI.Refresh()
    if not main or not SN.engine then return end
    dirty, lastRefresh = false, GetTime()
    local e = E()
    local counts = e:Counts()
    local members = e:LiveMembers()
    local stats = SN.Stats.Compute(SN.db.ledger, SN.sessionStart)
    local active, total = #e:ActiveDests(), #e.destOrder

    main.tiles.warlocks.value:SetText(#members)
    main.tiles.cities.value:SetText(active .. "/" .. total)
    main.tiles.waiting.value:SetText(counts.waiting)
    main.tiles.progress.value:SetText(counts.progress)
    main.tiles.pay.value:SetText(counts.pay)
    main.tiles.revenue.value:SetText(U.FormatMoney(stats.revenue))
    local gi = SN.Groups.Info()
    main.raidBtn:SetShown(gi.inGroup and not gi.isRaid and gi.canConvert)
    main.coord:SetText(e:IsCoord() and "COORDINATOR: you" or ("coordinator: " .. tostring(e.coord)))

    local line, hint, b = nextLines()
    main.nextText:SetText("NEXT  " .. line)
    for s, btn in pairs(main.stat) do btn:SetSelected(SN.cdb.status == s) end
    local d = e.dests[SN.cdb.dest]
    main.destBtn:SetLabel("City: " .. (d and d.name or "-"))
    main.shards:SetText(string.format("Soul Shards: |cff%s%d|r", SN.API.Shards() > 0 and "9be85a" or "ee5555", SN.API.Shards()))
    SN.Summon.Refresh()
    main.reason:SetText(hint or SN.Summon.reason or "")

    local qd = queueData()
    lists.queue:SetData(qd)
    main.empty:SetShown(#e:Queue() == 0 and #qd <= #e.destOrder)
    lists.cities:SetData(e:DestList())
    if tabFrames.stats:IsShown() then refreshStats(tabFrames.stats) end
    if tabFrames.ads:IsShown() then refreshAds(tabFrames.ads) end
    if tabFrames.setup:IsShown() then lists.setup:SetData(setupItems()) end

    if compact then
        compact.line1:SetText(b and (b.cust .. "  >  " .. destName(b.dest)) or "No customer assigned")
        compact.line2:SetText(b and ((Q.LABEL[b.state] or b.state) .. "  -  " .. U.FormatMoney(b.price) .. (hint and ("  -  " .. hint) or ""))
            or ("Waiting for whispers  -  " .. counts.waiting .. " in network queue"))
        compact.who:SetText((d and d.name or "-") .. " / " .. SN.cdb.status)
    end
end

function UI.Init()
    UI.Build()
    UI.BuildCompact()
    if SN.cdb.compact then compact:Show() end
end

return UI
