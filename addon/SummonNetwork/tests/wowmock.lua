-- Permissive WoW API mock: lets the whole addon load and run headless for smoke tests.
local M = { clock = 1800000000, whispers = {}, addonMsgs = {}, prints = {}, invites = {}, chatBox = nil }
_G.M = M

local frames = {}
local Frame = {}
local fmeta = {}

local function newFrame(kind, name, parent)
    local f = { kind = kind, name = name, parent = parent, scripts = {}, shown = true, attrs = {}, text = "", events = {}, w = 100, h = 20 }
    setmetatable(f, fmeta)
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end

fmeta.__index = function(t, k)
    local m = Frame[k]
    if m then return m end
    return function(self, ...) return self end -- unknown methods are harmless no-ops returning self
end

function Frame.SetScript(self, ev, fn) self.scripts[ev] = fn end
function Frame.GetScript(self, ev) return self.scripts[ev] end
function Frame.Show(self) self.shown = true end
function Frame.Hide(self) self.shown = false end
function Frame.SetShown(self, v) self.shown = v and true or false end
function Frame.IsShown(self) return self.shown end
function Frame.SetText(self, t) self.text = tostring(t) end
function Frame.GetText(self) return self.text end
function Frame.HasFocus() return false end
function Frame.SetSize(self, w, h) self.w, self.h = w, h end
function Frame.SetWidth(self, w) self.w = w end
function Frame.SetHeight(self, h) self.h = h end
function Frame.GetWidth(self) return self.w end
function Frame.GetHeight(self) return self.h end
function Frame.GetSize(self) return self.w, self.h end
function Frame.GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Frame.GetCenter() return 100, 100 end
function Frame.GetEffectiveScale() return 1 end
function Frame.SetAttribute(self, k, v) self.attrs[k] = v end
function Frame.GetAttribute(self, k) return self.attrs[k] end
function Frame.RegisterEvent(self, ev) self.events[ev] = true end
function Frame.CreateFontString(self) return newFrame("FontString", nil, self) end
function Frame.CreateTexture(self) return newFrame("Texture", nil, self) end
function Frame.GetStringWidth() return 50 end
function Frame.IsMouseOver() return false end

function CreateFrame(kind, name, parent, template)
    local f = newFrame(kind, name, parent)
    f.template = template
    return f
end

UIParent = newFrame("Frame", "UIParent")
Minimap = newFrame("Frame", "Minimap")
GameTooltip = newFrame("Frame", "GameTooltip")
UISpecialFrames = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SlashCmdList = {}

function GetTime() return M.clock end
function time() return M.clock end
date = os.date
M.realprint = print
math.randomseed = nil   -- WoW: Forever does not provide it; the addon must not depend on it
function print(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    M.prints[#M.prints + 1] = table.concat(t, " ")
end

-- Player / group state, controllable by tests
M.me = "Shadowlock"
M.raid = {}          -- array of { name, rank, subgroup, zone, online }
M.inRaid = false
M.shards = 5
M.money = 100000
M.combat = false
function UnitName(u) if u == "player" then return M.me end if u == "NPC" then return M.tradePartner end end
function UnitClass() return "Warlock", "WARLOCK" end
function UnitExists() return false end
function UnitIsDeadOrGhost() return false end
function UnitAffectingCombat() return M.combat end
function InCombatLockdown() return M.combat end
function GetBuildInfo() return "1.15.7", "63000", "Jan 1 2026", 11507 end
function IsInRaid() return M.inRaid end
function IsInGroup() return M.inRaid end
function GetNumGroupMembers() return #M.raid end
function GetRaidRosterInfo(i)
    local r = M.raid[i]
    if not r then return nil end
    return r.name, r.rank or 0, r.subgroup or 1, 60, "Mage", "MAGE", r.zone or "Orgrimmar", r.online ~= false
end
function UnitIsGroupLeader() return false end
function CheckInteractDistance() return false end
function IsInGuild() return false end
function GetSpellInfo(id) if id == 698 then return "Ritual of Summoning" end end
function IsSpellKnown(id) return id == 698 end
function GetItemCount() return M.shards end
function GetMoney() return M.money end
function GetTargetTradeMoney() return M.tradeOffer or 0 end
function GetPlayerTradeMoney() return 0 end
function PlaySound() end
function GetChannelList() return 2, "Trade - Orgrimmar", false end
function ChatFrame_OpenChat(t) M.chatBox = t end
function GetAddOnMetadata() return "1.0.0" end
function SendChatMessage(msg, kind, _, to) if kind == "WHISPER" then M.whispers[#M.whispers + 1] = { to = to, msg = msg } end end
function InviteUnit(n) M.invites[#M.invites + 1] = n end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, ch) M.addonMsgs[#M.addonMsgs + 1] = { prefix = prefix, msg = msg, ch = ch } end,
}
ERR_TRADE_COMPLETE = "Trade complete."
ERR_TRADE_CANCELLED = "Trade cancelled."
ERR_BAD_PLAYER_NAME_S = "Cannot find player '%s'."
ERR_ALREADY_IN_GROUP_S = "%s is already in a group."
ERR_DECLINE_GROUP_S = "%s declines your group invitation."
ERR_GROUP_FULL = "Your party is full."

-- Fire an event at every registered frame.
function M.fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- Advance time and run OnUpdate scripts.
function M.advance(seconds, step)
    step = step or 0.25
    for _ = 1, math.floor(seconds / step) do
        M.clock = M.clock + step
        for _, f in ipairs(frames) do
            if f.scripts.OnUpdate and f.shown ~= false then f.scripts.OnUpdate(f, step) end
        end
    end
end

function M.loadAddon(dir)
    local SN = {}
    local toc = assert(io.open(dir .. "/SummonNetwork.toc"))
    for line in toc:lines() do
        line = line:gsub("\r", "")
        if not line:match("^%s*##") and line:match("%S") then
            local path = dir .. "/" .. line:gsub("\\", "/")
            local chunk = assert(loadfile(path))
            chunk("SummonNetwork", SN)
        end
    end
    toc:close()
    return SN
end

function M.say(from, text) M.fire("CHAT_MSG_WHISPER", text, from) end
return M
