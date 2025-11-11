--[[
    ====================================================================
    GuardianFREE - Configuration
    ====================================================================
    Free anticheat with modern executor detection
]]

Config = {}

-- ========================================
-- GENERAL CONFIGURATION
-- ========================================
Config.Enabled = true                    -- Enable/disable anticheat
Config.Debug = false                     -- Debug mode (shows logs)
Config.ResourceName = "GuardianFREE"     -- Resource name

-- ========================================
-- DETECTION IED (Injector/Executor Detection)
-- ========================================
Config.IED = {
    enabled = true,                      -- Enable executor detection
    sensitivity = 3,                     -- Sensitivity (1 = low, 5 = high)
    detectionThreshold = 3,              -- Number of flags before ban

    -- Check intervals (ms)
    checkInterval = 100,
    inputCheckInterval = 50,
    threadCheckInterval = 200,
}

-- ========================================
-- DETECTION ACTIONS
-- ========================================
Config.Actions = {
    ban = true,                          -- Ban the player
    kick = false,                        -- Kick the player (if ban = false)
    screenshot = false,                  -- Take a screenshot
    log = true,                          -- Log to console
    webhook = true,                      -- Send to Discord webhook
}

-- ========================================
-- DISCORD WEBHOOK
-- ========================================
Config.Webhook = {
    enabled = true,
    url = "",  -- PUT YOUR WEBHOOK HERE

    -- Customization
    botName = "GuardianFREE",
    color = 15158332,  -- Red
    avatar = "https://i.imgur.com/YourAvatar.png",

    -- Information to include
    includeCoords = true,
    includeStats = true,
    includeIdentifiers = true,
}

-- ========================================
-- MESSAGES
-- ========================================
Config.Messages = {
    kickMessage = "🛡️ GuardianFREE: Executor detected",
    banMessage = "🛡️ GuardianFREE: Banned for executor usage",
    banReason = "GuardianFREE: Executor/Injector detected",
}

-- ========================================
-- WHITELIST ADMINS (won't be banned)
-- ========================================
Config.Whitelist = {
    enabled = true,
    identifiers = {
        "steam:110000XXXXXXXX",  -- Example
        "license:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        -- Add your admins here
    }
}

return Config
