-- Locale/enUS.lua: all user-facing strings. Customer whispers are configurable (see Config.lua).
local _, SN = ...
SN = SN or {}
SN.L = {
    TITLE = "SUMMON NETWORK",
    SUBTITLE = "multi-city summoning",
    NO_CUSTOMERS = "No customers in the queue. Post an ad and wait for |cff9be85ainv <city>|r whispers.",
    NO_TEAM = "No Warlocks",
    ALERT_INVITE = "Invite %s (%s) - click Invite in the queue.",
    ALERT_PORTAL = "Click %s's Ritual of Summoning portal! (%s)",
    ALERT_PAY = "%s arrived - trade %s to collect payment.",
    ALERT_PAID = "Payment received from %s: %s",
    ALERT_SHORT = "%s offered only %s of %s - not marked paid.",
    ALERT_NEEDRAID = "Group is full. Convert to a raid (leader) before inviting more customers.",
    HELP = {
        "|cff9be85aSummon Network|r commands:",
        "  /sn  - open/close the dashboard      /sn compact - toggle compact mode",
        "  /sn status | queue | stats | diag | errors (copyable error report)",
        "  /sn available | busy | offline",
        "  /sn city <key>            set the destination you stand in",
        "  /sn price <key> <30s>     set a destination price",
        "  /sn alias <key> add|del <word>",
        "  /sn dest add <key> <Name> [zone] | dest del <key> | dest on|off <key>",
        "  /sn ad                    prepare the Trade-chat ad (you press Enter)",
        "  /sn paid|free|cancel|noshow|requeue|invite <customer>",
        "  /sn assign <customer> <warlock>    /sn discount <customer> <30s>",
        "  /sn key <phrase>          shared network key   /sn manager add|del <name>",
        "  /sn member add|del <name> allow-list           /sn channel group|guild",
        "  /sn raid                  convert your party to a raid (leader)",
        "  /sn reset                 clear local session data",
    },
}
