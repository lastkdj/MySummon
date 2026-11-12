-- Slash.lua: /sn and /summonnetwork commands.
local _, SN = ...
if SN and SN.boot then SN.boot[#SN.boot + 1] = "Slash.lua" end
SN = SN or {}
local U, Q, API = SN.Util, SN.Queue, SN.API
local S = {}
SN.Slash = S

local function say(m) SN.Print(m) end
local function E() return SN.engine end

local function findBooking(name)
    local b = name and E():Find(name)
    if not b then say("No booking found for '" .. tostring(name) .. "'") end
    return b
end

local function words(msg)
    local t = {}
    for w in tostring(msg or ""):gmatch("%S+") do t[#t + 1] = w end
    return t
end

local cmds = {}

function cmds.status()
    local e = E()
    local c = e:Counts()
    say(string.format("Coordinator: %s | Warlocks online: %d | waiting %d | in progress %d | payment pending %d",
        e:IsCoord() and "you" or e.coord, #e:LiveMembers(), c.waiting, c.progress, c.pay))
    for _, k in ipairs(e.destOrder) do
        local d = e.dests[k]
        local names = {}
        for _, m in ipairs(e:Team(k)) do names[#names + 1] = m.name .. "(" .. m.status .. "," .. m.shards .. ")" end
        say(string.format("  %s [%s] %s%s - team: %s - queue %d", d.name, k, U.FormatMoney(d.price), d.enabled and "" or " (hidden)",
            #names > 0 and table.concat(names, ", ") or "none", #e:Queue(k)))
    end
end

function cmds.queue()
    SN.UI.Show("queue")
    local list = E():Queue()
    if #list == 0 then say("Queue is empty.") end
    for _, b in ipairs(list) do say("  " .. Q.Describe(b)) end
end

function cmds.stats() SN.UI.Show("stats") end
function cmds.setup() SN.UI.Show("setup") end
function cmds.compact() SN.UI.SetCompact(not SN.cdb.compact) end
function cmds.available() SN.SetMyStatus("available") end
function cmds.busy() SN.SetMyStatus("busy") end
function cmds.offline() SN.SetMyStatus("offline") end
function cmds.ad() SN.PrepareAd() end

function cmds.city(a) SN.SetMyDest(U.lower(a[2] or "")) end

function cmds.price(a)
    local key, amount = U.lower(a[2] or ""), U.ParseMoney(a[3] or "")
    local d = E().dests[key]
    if not d or not amount then say("Usage: /sn price <key> <30s>") return end
    local nd = U.copy(d); nd.price = amount
    SN.EditDest(nd)
    say(d.name .. " price set to " .. U.FormatMoney(amount))
end

function cmds.alias(a)
    local key, op, word = U.lower(a[2] or ""), a[3], a[4]
    local d = E().dests[key]
    if not d or not word or (op ~= "add" and op ~= "del") then say("Usage: /sn alias <key> add|del <word>") return end
    local nd = U.copy(d)
    local w = U.lower(word)
    local out, found = {}, false
    for _, x in ipairs(nd.aliases) do
        if U.lower(x) == w then found = true if op == "add" then out[#out + 1] = x end else out[#out + 1] = x end
    end
    if op == "add" and not found then out[#out + 1] = w end
    nd.aliases = out
    SN.EditDest(nd)
    say(d.name .. " aliases: " .. table.concat(out, ", "))
end

function cmds.dest(a)
    local op, key = a[2], U.lower(a[3] or "")
    if op == "add" and key ~= "" and a[4] then
        local name = a[4]
        local zone = a[5]
        SN.EditDest({ key = key, name = name, zone = zone or name, price = 3000, aliases = {}, enabled = true, order = #E():DestList() + 1 })
        say("Added destination " .. name .. " (inv " .. key .. ")")
    elseif op == "del" and E().dests[key] then
        local ok, why = E():RemoveDest(key)
        say(ok and ("Removed " .. key) or tostring(why))
    elseif (op == "on" or op == "off") and E().dests[key] then
        local nd = U.copy(E().dests[key]); nd.enabled = (op == "on")
        SN.EditDest(nd)
    else
        say("Usage: /sn dest add <key> <Name> [zone] | del <key> | on|off <key>")
    end
end

local function simple(ev, label)
    return function(a)
        local b = findBooking(a[2])
        if not b then return end
        local ok, why = E():Do(b.id, ev, a[3])
        say(ok and (label .. ": " .. b.cust) or ("Cannot " .. label .. ": " .. tostring(why)))
    end
end
cmds.paid = simple("markpaid", "marked paid")
cmds.free = simple("free", "free summon")
cmds.cancel = simple("cancel", "cancelled")
cmds.noshow = simple("noshow", "no-show")
cmds.requeue = simple("requeue", "requeued")
cmds.arrived = simple("arrived", "arrived")
cmds.unpaid = simple("unpaid", "written off")

function cmds.invite(a)
    local b = findBooking(a[2])
    if b then SN.Whispers.Invite(b, true) end
end

function cmds.assign(a)
    local b = findBooking(a[2])
    if not b then return end
    local ok, why = E():Do(b.id, "reassign", a[3] or "")
    say(ok and ("Reassigning " .. b.cust .. " to " .. tostring(a[3])) or ("Cannot reassign: " .. tostring(why)))
end

function cmds.discount(a)
    local b = findBooking(a[2])
    local amt = U.ParseMoney(a[3] or "")
    if not b or not amt then say("Usage: /sn discount <customer> <15s>") return end
    local ok, why = E():Do(b.id, "discount", amt)
    say(ok and ("Price for " .. b.cust .. " is now " .. U.FormatMoney(amt)) or ("Cannot: " .. tostring(why)))
end

function cmds.key(a, rest)
    SN.SetKey(rest ~= "" and rest or "")
end

local function listEdit(field)
    return function(a)
        local op, name = a[2], a[3]
        if not name or (op ~= "add" and op ~= "del") then say("Usage: /sn " .. (field == "managers" and "manager" or "member") .. " add|del <name>") return end
        local list, out, found = SN.db[field], {}, false
        for _, n in ipairs(list) do
            if U.lower(n) == U.lower(name) then found = true if op == "add" then out[#out + 1] = n end else out[#out + 1] = n end
        end
        if op == "add" and not found then out[#out + 1] = name end
        SN.db[field] = out
        say(field .. ": " .. (#out > 0 and table.concat(out, ", ") or "(none)"))
    end
end
cmds.manager = listEdit("managers")
cmds.member = listEdit("members")

function cmds.channel(a)
    local m = U.lower(a[2] or "")
    if m == "guild" then SN.db.channelMode = "GUILD" elseif m == "group" then SN.db.channelMode = "GROUP" else say("Usage: /sn channel group|guild") return end
    say("Network channel: " .. SN.db.channelMode)
end

function cmds.members()
    for _, m in ipairs(E():LiveMembers()) do
        say(string.format("  %s - %s - %s - shards %d - %d jobs%s", m.name, m.dest, m.status, m.shards or 0, m.load or 0,
            m.name == E().coord and "  [coordinator]" or ""))
    end
end

function cmds.debug()
    SN.debug = not SN.debug
    say("Debug " .. (SN.debug and "on" or "off") .. ". Last log lines:")
    local b = SN.DebugBuffer()
    for i = math.max(1, #b - 25), #b do print("  " .. b[i]) end
    say("Outgoing addon queue: " .. SN.Net.QueueLength())
end

function cmds.reset()
    SN.db.ledger = {}
    SN.cdb.session = nil
    for id in pairs(E().bookings) do E().bookings[id] = nil end
    SN.UI.Dirty()
    say("Local bookings and ledger cleared.")
end

function cmds.diag()
    local function yn(v) return v and "|cff55ee66OK|r" or "|cffee5555MISSING|r" end
    local version, build, _, toc = API.BuildInfo()
    say(string.format("Client %s (build %s) - put |cffffd040## Interface: %s|r in the .toc", tostring(version), tostring(build), tostring(toc)))
    say("Addon message prefix registered: " .. yn(API.RegisterPrefix(SN.Protocol.PREFIX)))
    say("SendAddonMessage: " .. yn((C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage))
    say("Group APIs (IsInRaid/GetRaidRosterInfo): " .. yn(IsInRaid and GetRaidRosterInfo))
    say("Invite API (InviteUnit): " .. yn((C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit))
    say("Convert to raid: " .. yn((C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid))
    local known, name = API.KnowsRitual()
    say(string.format("Ritual of Summoning (spell %d): %s name=%s", API.RITUAL_SPELL_ID, yn(known), tostring(name)))
    say("Soul Shards in bags (item " .. API.SOUL_SHARD_ITEM .. "): " .. API.Shards())
    say("Trade money API: " .. yn(GetTargetTradeMoney and GetPlayerTradeMoney))
    say("Trade-complete string: " .. yn(ERR_TRADE_COMPLETE))
    say("Chat lockdown guard (issecretvalue): " .. yn(issecretvalue))
    say("Settings API: " .. yn(Settings and Settings.RegisterAddOnCategory))
    local id, tname = API.TradeChannel()
    say("Trade channel: " .. (id and (tname .. " #" .. id) or "|cffee5555not joined|r"))
    say("Channel in use: " .. tostring(SN.Net.Channel() or "none (solo)"))
    say("See docs/TESTING.md section 'Phase 0 live checks' to finish verification.")
end

function cmds.raid()
    local ok, err = SN.API.ConvertToRaid()
    say(ok and "Converting the party to a raid." or ("Cannot convert: " .. tostring(err)))
end

-- Copyable error report (local window; nothing is sent to other players)
local errFrame
function cmds.errors()
    local Kit = SN.Kit
    local lines = {}
    for _, e in ipairs(SN.Errors()) do lines[#lines + 1] = e end
    lines[#lines + 1] = "--- debug log ---"
    local b = SN.DebugBuffer()
    for i = math.max(1, #b - 30), #b do lines[#lines + 1] = b[i] end
    local v, build, _, toc = API.BuildInfo()
    lines[#lines + 1] = string.format("client %s build %s interface %s addon %s", tostring(v), tostring(build), tostring(toc), tostring(SN.version))
    local text = table.concat(lines, "\n")
    if not errFrame then
        errFrame = Kit.Frame(UIParent, 520, 300, Kit.C.bg, Kit.C.purple, "SummonNetworkErrors")
        errFrame:SetPoint("CENTER")
        errFrame:SetFrameStrata("DIALOG")
        local t = Kit.Text(errFrame, 12, Kit.C.gold, "LEFT", true)
        t:SetPoint("TOPLEFT", 10, -8)
        t:SetText("Press Ctrl+C to copy, then Esc to close")
        local close = Kit.Button(errFrame, "X", 22, 20, function() errFrame:Hide() end, "danger")
        close:SetPoint("TOPRIGHT", -6, -6)
        local sf = CreateFrame("ScrollFrame", nil, errFrame)
        sf:SetPoint("TOPLEFT", 10, -32)
        sf:SetPoint("BOTTOMRIGHT", -10, 10)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
        eb:SetWidth(496)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() errFrame:Hide() end)
        sf:SetScrollChild(eb)
        errFrame.edit = eb
        table.insert(UISpecialFrames, "SummonNetworkErrors")
    end
    errFrame.edit:SetText(text)
    errFrame:Show()
    errFrame.edit:SetFocus()
    errFrame.edit:HighlightText()
end

function cmds.help()
    for _, l in ipairs(SN.L.HELP) do print(l) end
end

local function handle(msg)
    msg = U.trim(msg or "")
    if not SN.engine then say("Not ready: the addon failed to start. Look above in chat for a red 'Summon Network error' line.") return end
    local a = words(msg)
    local cmd = U.lower(a[1] or "")
    if cmd == "" then SN.UI.Toggle() return end
    local fn = cmds[cmd]
    if not fn then
        say("Unknown command '" .. cmd .. "'.")
        cmds.help()
        return
    end
    local rest = U.trim(msg:sub(#a[1] + 1))
    local ok, err = pcall(fn, a, rest)
    if not ok then say("Error: " .. tostring(err)) SN.Log("slash error: " .. tostring(err)) end
end

SLASH_SUMMONNETWORK1 = "/sn"
SLASH_SUMMONNETWORK2 = "/summonnetwork"
SLASH_SUMMONNETWORK3 = "/snet"
SlashCmdList["SUMMONNETWORK"] = handle

return S
