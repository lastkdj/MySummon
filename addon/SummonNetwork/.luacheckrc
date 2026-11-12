std = "lua51"
max_line_length = false
exclude_files = { "tests/*" }
ignore = { "212", "213", "311", "431", "432" }  -- unused args/loop vars, shadowing (WoW addon idiom)
globals = {
  "SummonNetworkDB", "SummonNetworkCharDB", "SlashCmdList", "SLASH_SUMMONNETWORK1", "SLASH_SUMMONNETWORK2", "SLASH_SUMMONNETWORK3", "SLASH_SUMNET1", "UISpecialFrames",
}
read_globals = {
  "geterrorhandler", "seterrorhandler", "GetAddOnInfo", "IsAddOnLoaded", "CreateFrame", "UIParent", "Minimap", "GameTooltip", "GetTime", "time", "date", "UnitName", "UnitClass", "UnitExists",
  "UnitIsConnected", "UnitIsDeadOrGhost", "UnitAffectingCombat", "InCombatLockdown", "GetBuildInfo", "IsInRaid", "IsInGroup",
  "GetNumGroupMembers", "GetNumRaidMembers", "GetNumPartyMembers", "GetRaidRosterInfo", "UnitIsGroupLeader", "UnitIsPartyLeader",
  "CheckInteractDistance", "IsInGuild", "GetSpellInfo", "IsSpellKnown", "IsPlayerSpell", "IsUsableSpell", "GetItemCount",
  "GetMoney", "GetTargetTradeMoney", "GetPlayerTradeMoney", "PlaySound", "GetChannelList", "ChatFrame_OpenChat",
  "GetAddOnMetadata", "SendChatMessage", "InviteUnit", "ConvertToRaid", "UninviteUnit", "SendAddonMessage", "RegisterAddonMessagePrefix",
  "ChatFontNormal", "GameFontHighlightSmall", "issecretvalue", "C_SpellBook", "C_Item", "C_ChatInfo", "C_PartyInfo", "C_Spell", "C_AddOns", "Settings", "STANDARD_TEXT_FONT", "GetCursorPosition", "TradeFrameRecipientNameText",
  "ERR_TRADE_COMPLETE", "ERR_TRADE_CANCELLED", "ERR_BAD_PLAYER_NAME_S", "ERR_ALREADY_IN_GROUP_S", "ERR_DECLINE_GROUP_S", "ERR_GROUP_FULL",
}
