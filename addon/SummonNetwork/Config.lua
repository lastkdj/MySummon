-- Config.lua: defaults, SavedVariables migration.
--   SummonNetworkDB      account-wide: network settings, destinations, ledger
--   SummonNetworkCharDB  per character: UI state, this Warlock's city/status, session snapshot
local _, SN = ...
SN = SN or {}
local U = SN.Util
local C = {}
SN.Config = C

C.DB_VERSION = 1

C.DEFAULT_DESTS = {
    { key = "ogr", name = "Orgrimmar", zone = "Orgrimmar", price = 3000, enabled = true,
      aliases = { "org", "orgri", "orgrimmar", "og" } },
    { key = "uc", name = "Undercity", zone = "Undercity", price = 3000, enabled = true,
      aliases = { "undercity", "under", "undead" } },
    { key = "tb", name = "Thunder Bluff", zone = "Thunder Bluff", price = 3000, enabled = true,
      aliases = { "thunder", "thunderbluff", "bluff" } },
}

C.DEFAULT_MSGS = {
    registered = "Summon Network: {dest} summon requested. Price: {price}. Please accept your group invitation.",
    assigned = "Your {dest} summoner is {owner}. You are #{pos} in the queue. Please accept the summon and trade {pricelong} to {owner} when you arrive.",
    ready = "Your {dest} summon is ready! Please accept the summon.",
    arrived = "Welcome! Please trade {pricelong} to {owner} to complete your {dest} summon. Thank you!",
    paid = "Payment received. Thank you for using Summon Network!",
    ended = "Summon Network: your {dest} request has ended. Whisper \"inv {key}\" if you still need a summon.",
    help = "Summon Network: whisper \"inv <city>\" - {list}",
    unavailable = "Summon Network: sorry, {dest} summons are unavailable right now. Available: {list}",
    already = "Summon Network: you are already registered for {dest}. Summoner: {owner}. Queue position #{pos}.",
}

C.ACCOUNT = {
    version = C.DB_VERSION,
    key = "",                 -- shared network key (all Warlocks must use the same phrase)
    managers = {},            -- ordered list; first live manager coordinates the network
    members = {},             -- optional allow-list of Warlock names (empty = any keyed sender)
    dests = nil,              -- filled from DEFAULT_DESTS on first run
    msgs = nil,               -- filled from DEFAULT_MSGS on first run
    requireShards = true,
    autoInvite = false,       -- see docs/API-NOTES.md: may be blocked; default is a one-click Invite button
    whisperCustomers = true,
    sound = true,
    channelMode = "GROUP",    -- GROUP (party/raid) or GUILD
    ackTimeout = 15, inviteTimeout = 180, disconnectTimeout = 180, arrivalTimeout = 240, castTimeout = 90,
    adPrefix = "WTS SUMMONS", adSuffix = "Fast service!", adCooldown = 60,
    minimap = { angle = 200, hide = false },
    ledger = {},
    ledgerCap = 2000,
}

C.CHAR = {
    dest = "ogr",
    status = "available",
    compact = false,
    ui = { scale = 1.0, point = "CENTER", x = 0, y = 0, cpoint = "CENTER", cx = 0, cy = -200, tab = "queue" },
    session = nil,
}

function C.Init()
    SummonNetworkDB = SummonNetworkDB or {}
    SummonNetworkCharDB = SummonNetworkCharDB or {}
    local db, cdb = SummonNetworkDB, SummonNetworkCharDB
    U.fill(db, C.ACCOUNT)
    U.fill(cdb, C.CHAR)
    if not db.dests or #db.dests == 0 then db.dests = U.copy(C.DEFAULT_DESTS) end
    if not db.msgs then db.msgs = {} end
    U.fill(db.msgs, C.DEFAULT_MSGS)
    db.version = C.DB_VERSION
    return db, cdb
end

return C
