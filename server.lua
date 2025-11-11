--[[
    ====================================================================
    GuardianFREE - Server Side
    ====================================================================
]]

-- Loading config
Config = Config or {}

-- Global variables
local detectedPlayers = {}
local playerDetectionCount = {}

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================
local function GetPlayerIdentifiers(source)
    local identifiers = {
        steam = "",
        license = "",
        discord = "",
        ip = ""
    }

    for k, v in pairs(GetPlayerIdentifiers(source)) do
        if string.sub(v, 1, string.len("steam:")) == "steam:" then
            identifiers.steam = v
        elseif string.sub(v, 1, string.len("license:")) == "license:" then
            identifiers.license = v
        elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
            identifiers.discord = v
        elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
            identifiers.ip = v
        end
    end

    return identifiers
end

local function IsPlayerWhitelisted(source)
    if not Config.Whitelist.enabled then
        return false
    end

    local identifiers = GetPlayerIdentifiers(source)

    for _, whitelistedId in ipairs(Config.Whitelist.identifiers) do
        if identifiers.steam == whitelistedId or
           identifiers.license == whitelistedId or
           identifiers.discord == whitelistedId then
            return true
        end
    end

    return false
end

local function Log(message)
    if Config.Debug then
        print("^3[GuardianFREE]^0 " .. message)
    end
end

-- ========================================
-- DISCORD WEBHOOK
-- ========================================
local function SendToDiscord(title, message, color, source, detectionData)
    if not Config.Webhook.enabled or Config.Webhook.url == "" then
        return
    end

    local identifiers = GetPlayerIdentifiers(source)
    local playerName = GetPlayerName(source)

    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["color"] = color or Config.Webhook.color,
            ["footer"] = {
                ["text"] = Config.Webhook.botName .. " • " .. os.date("%d/%m/%Y %H:%M:%S"),
            },
            ["fields"] = {
                {
                    ["name"] = "👤 Player",
                    ["value"] = playerName .. " [ID: " .. source .. "]",
                    ["inline"] = true
                }
            }
        }
    }

    -- Add identifiers
    if Config.Webhook.includeIdentifiers then
        table.insert(embed[1].fields, {
            ["name"] = "🔑 Steam",
            ["value"] = identifiers.steam ~= "" and identifiers.steam or "N/A",
            ["inline"] = true
        })
        table.insert(embed[1].fields, {
            ["name"] = "🔑 License",
            ["value"] = identifiers.license ~= "" and identifiers.license or "N/A",
            ["inline"] = true
        })
    end

    -- Add coordinates
    if Config.Webhook.includeCoords and detectionData and detectionData.playerCoords then
        local coords = detectionData.playerCoords
        table.insert(embed[1].fields, {
            ["name"] = "📍 Coordinates",
            ["value"] = string.format("X: %.2f, Y: %.2f, Z: %.2f", coords.x, coords.y, coords.z),
            ["inline"] = false
        })
    end

    -- Add detection stats
    if Config.Webhook.includeStats and detectionData and detectionData.stats then
        local stats = detectionData.stats
        local statsText = string.format(
            "```\nInput Desync: %d\nCamera Anomaly: %d\nThread Injection: %d\nCursor Overlay: %d\nTotal Flags: %d```",
            stats.inputDesync or 0,
            stats.cameraAnomaly or 0,
            stats.threadInjection or 0,
            stats.cursorOverlay or 0,
            detectionData.flags or 0
        )
        table.insert(embed[1].fields, {
            ["name"] = "📊 Detection Statistics",
            ["value"] = statsText,
            ["inline"] = false
        })
    end

    PerformHttpRequest(Config.Webhook.url, function(err, text, headers)
    end, 'POST', json.encode({
        username = Config.Webhook.botName,
        embeds = embed
    }), {
        ['Content-Type'] = 'application/json'
    })
end

-- ========================================
-- DETECTION MANAGEMENT
-- ========================================
RegisterServerEvent('guardian:detection')
AddEventHandler('guardian:detection', function(reason, detectionData)
    local source = source
    local playerName = GetPlayerName(source)

    -- Whitelist check
    if IsPlayerWhitelisted(source) then
        Log("Player " .. playerName .. " is whitelisted, skipping ban")
        return
    end

    -- Check if already detected
    if detectedPlayers[source] then
        return
    end

    detectedPlayers[source] = true

    -- Logs
    Log("^1EXECUTOR DETECTED^0")
    Log("Player: " .. playerName .. " [" .. source .. "]")
    Log("Reason: " .. reason)

    if detectionData and detectionData.flags then
        Log("Detection Flags: " .. detectionData.flags)
    end

    -- Webhook
    if Config.Actions.webhook then
        SendToDiscord(
            "🚨 Executor Detected",
            "**Reason:** " .. reason,
            15158332,  -- Red
            source,
            detectionData
        )
    end

    -- Screenshot (requires screenshot-basic)
    if Config.Actions.screenshot then
        exports['screenshot-basic']:requestClientScreenshot(source, {
            fileName = 'guardian_' .. source .. '_' .. os.time() .. '.jpg'
        }, function(err, data)
            -- Screenshot saved
        end)
    end

    -- Actions
    Wait(1000)  -- Wait for logs to be sent

    if Config.Actions.ban then
        -- Ban via txAdmin if available
        if GetResourceState('txAdmin') == 'started' then
            TriggerEvent('txAdmin:events:scheduleBan', {
                author = Config.ResourceName,
                target = source,
                reason = Config.Messages.banReason,
                duration = 0,  -- Permanent
            })
        else
            -- Manual ban
            DropPlayer(source, Config.Messages.banMessage)
        end
    elseif Config.Actions.kick then
        DropPlayer(source, Config.Messages.kickMessage)
    end
end)

-- ========================================
-- ADMIN COMMANDS
-- ========================================
RegisterCommand('guardianstats', function(source, args, rawCommand)
    if source ~= 0 then  -- Console only
        return
    end

    print("^2========== GuardianFREE Statistics ==========^0")
    print("^3Detected Players This Session: " .. #detectedPlayers .. "^0")
    print("^2============================================^0")
end, true)

RegisterCommand('guardianreset', function(source, args, rawCommand)
    if source ~= 0 then
        return
    end

    detectedPlayers = {}
    playerDetectionCount = {}
    print("^2[GuardianFREE] Statistics reset!^0")
end, true)

-- ========================================
-- EVENTS
-- ========================================
AddEventHandler('playerDropped', function(reason)
    local source = source
    if detectedPlayers[source] then
        detectedPlayers[source] = nil
    end
    if playerDetectionCount[source] then
        playerDetectionCount[source] = nil
    end
end)

-- ========================================
-- STARTUP
-- ========================================
Citizen.CreateThread(function()
    Wait(1000)
    print("^2========================================^0")
    print("^2     GuardianFREE Anticheat v1.0^0")
    print("^2========================================^0")
    print("^3IED Detection: " .. (Config.IED.enabled and "^2ENABLED^0" or "^1DISABLED^0"))
    print("^3Webhook: " .. (Config.Webhook.enabled and Config.Webhook.url ~= "" and "^2ENABLED^0" or "^1DISABLED^0"))
    print("^3Ban System: " .. (Config.Actions.ban and "^2ENABLED^0" or "^1DISABLED^0"))
    print("^2========================================^0")
end)
