--[[
    ====================================================================
    GuardianFREE - Client Side
    ====================================================================
    Modern executor detection system
]]

-- Global variables
local detectionFlags = 0
local isDetected = false
local lastFrameTime = GetGameTimer()

-- Statistics
local DetectionStats = {
    inputDesync = 0,
    cameraAnomaly = 0,
    threadInjection = 0,
    cursorOverlay = 0,
    totalFlags = 0
}

-- ========================================
-- MODULE 1: INPUT DESYNCHRONIZATION
-- ========================================
local InputMonitor = {
    trackedControls = {
        {control = 24, lastState = false},
        {control = 25, lastState = false},
        {control = 32, lastState = false},
        {control = 33, lastState = false},
        {control = 34, lastState = false},
        {control = 35, lastState = false},
    },
    stateChangeCount = 0,
    lastResetTime = 0
}

local function CheckInputDesync()
    local currentTime = GetGameTimer()

    for _, ctrl in ipairs(InputMonitor.trackedControls) do
        local currentState = IsControlPressed(0, ctrl.control)
        if currentState ~= ctrl.lastState then
            InputMonitor.stateChangeCount = InputMonitor.stateChangeCount + 1
        end
        ctrl.lastState = currentState
    end

    -- Detection
    if InputMonitor.stateChangeCount > (50 / Config.IED.sensitivity) then
        DetectionStats.inputDesync = DetectionStats.inputDesync + 1
        RaiseDetectionFlag("Input Desynchronization detected", 2)
    end

    -- Reset every 5 seconds
    if currentTime - InputMonitor.lastResetTime > 5000 then
        InputMonitor.stateChangeCount = 0
        InputMonitor.lastResetTime = currentTime
    end
end

-- ========================================
-- MODULE 2: CAMERA ANOMALIES
-- ========================================
local CameraMonitor = {
    positions = {},
    maxPositions = 10,
    suspiciousJumps = 0
}

local function CheckCameraAnomalies()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local currentTime = GetGameTimer()

    table.insert(CameraMonitor.positions, {
        coords = camCoords,
        rotation = camRot,
        time = currentTime
    })

    if #CameraMonitor.positions > CameraMonitor.maxPositions then
        table.remove(CameraMonitor.positions, 1)
    end

    if #CameraMonitor.positions >= 3 then
        local pos1 = CameraMonitor.positions[#CameraMonitor.positions - 2]
        local pos2 = CameraMonitor.positions[#CameraMonitor.positions - 1]
        local pos3 = CameraMonitor.positions[#CameraMonitor.positions]

        local dist1 = #(pos1.coords - pos2.coords)
        local dist2 = #(pos2.coords - pos3.coords)
        local timeDiff = pos3.time - pos1.time

        -- Camera teleportation
        if (dist1 > (500.0 / Config.IED.sensitivity) or dist2 > (500.0 / Config.IED.sensitivity)) and timeDiff < 100 then
            CameraMonitor.suspiciousJumps = CameraMonitor.suspiciousJumps + 1

            if CameraMonitor.suspiciousJumps > 3 then
                DetectionStats.cameraAnomaly = DetectionStats.cameraAnomaly + 1
                RaiseDetectionFlag("Camera teleportation detected", 3)
                CameraMonitor.suspiciousJumps = 0
            end
        end

        -- Instant rotation
        local rotDiff = math.abs(pos2.rotation.z - pos3.rotation.z)
        if rotDiff > (45.0 / Config.IED.sensitivity) and timeDiff < 50 then
            DetectionStats.cameraAnomaly = DetectionStats.cameraAnomaly + 1
            RaiseDetectionFlag("Instant rotation detected", 2)
        end
    end
end

-- ========================================
-- MODULE 3: THREAD INJECTION
-- ========================================
local ThreadMonitor = {
    frameTimings = {},
    maxTimings = 20,
    averageFrameTime = 0,
    spikes = 0
}

local function CheckThreadInjection()
    local currentTime = GetGameTimer()
    local frameTime = currentTime - lastFrameTime
    lastFrameTime = currentTime

    table.insert(ThreadMonitor.frameTimings, frameTime)

    if #ThreadMonitor.frameTimings > ThreadMonitor.maxTimings then
        table.remove(ThreadMonitor.frameTimings, 1)
    end

    -- Calculate average
    local sum = 0
    for _, timing in ipairs(ThreadMonitor.frameTimings) do
        sum = sum + timing
    end
    ThreadMonitor.averageFrameTime = sum / #ThreadMonitor.frameTimings

    -- Spike detection
    if frameTime > (ThreadMonitor.averageFrameTime * (3 / Config.IED.sensitivity)) and frameTime > 100 then
        ThreadMonitor.spikes = ThreadMonitor.spikes + 1

        if ThreadMonitor.spikes > 5 then
            DetectionStats.threadInjection = DetectionStats.threadInjection + 1
            RaiseDetectionFlag("Thread injection pattern detected", 2)
            ThreadMonitor.spikes = 0
        end
    end
end

-- ========================================
-- MODULE 4: CURSOR OVERLAY
-- ========================================
local CursorMonitor = {
    lastPosition = {x = 0, y = 0},
    lastCamCoords = vector3(0, 0, 0),
    movementWithoutNUI = 0,
    suspiciousControls = {45, 178, 121, 322, 288, 10, 11, 207, 208}
}

local function CheckCursorOverlay()
    local x, y = GetNuiCursorPosition()
    local camCoords = GetGameplayCamCoord()

    local cursorMoved = (x ~= CursorMonitor.lastPosition.x or y ~= CursorMonitor.lastPosition.y)
    local cameraStatic = (#(camCoords - CursorMonitor.lastCamCoords) < 0.1)

    if cursorMoved and cameraStatic then
        if not IsNuiFocused() and not IsPauseMenuActive() then
            for _, control in ipairs(CursorMonitor.suspiciousControls) do
                if IsControlPressed(0, control) then
                    CursorMonitor.movementWithoutNUI = CursorMonitor.movementWithoutNUI + 1

                    if CursorMonitor.movementWithoutNUI > (15 / Config.IED.sensitivity) then
                        DetectionStats.cursorOverlay = DetectionStats.cursorOverlay + 1
                        RaiseDetectionFlag("Executor overlay detected", 3)
                        CursorMonitor.movementWithoutNUI = 0
                    end
                    break
                end
            end
        else
            CursorMonitor.movementWithoutNUI = 0
        end
    end

    CursorMonitor.lastPosition = {x = x, y = y}
    CursorMonitor.lastCamCoords = camCoords
end

-- ========================================
-- DETECTION SYSTEM
-- ========================================
function RaiseDetectionFlag(reason, severity)
    severity = severity or 1
    detectionFlags = detectionFlags + severity
    DetectionStats.totalFlags = DetectionStats.totalFlags + 1

    if Config.Debug then
        print(("^3[GuardianFREE] Flag #%d: %s^0"):format(detectionFlags, reason))
    end

    if detectionFlags >= Config.IED.detectionThreshold then
        if not isDetected then
            isDetected = true
            TriggerDetection(reason)
        end
    end
end

function TriggerDetection(reason)
    local coords = GetEntityCoords(PlayerPedId())

    local detectionData = {
        reason = reason,
        flags = detectionFlags,
        stats = DetectionStats,
        timestamp = GetGameTimer(),
        playerCoords = {x = coords.x, y = coords.y, z = coords.z}
    }

    if Config.Debug then
        print("^1[GuardianFREE] EXECUTOR DETECTED!^0")
        print("^1Reason: " .. reason .. "^0")
    end

    TriggerServerEvent('guardian:detection', reason, detectionData)
end

-- ========================================
-- INITIALIZATION
-- ========================================
CreateThread(function()
    Wait(2000)

    if not Config.IED.enabled then
        return
    end

    print("^2[GuardianFREE] Protection active^0")

    -- Main thread
    CreateThread(function()
        while Config.IED.enabled do
            if not isDetected then
                CheckThreadInjection()
                CheckCameraAnomalies()
            end
            Wait(Config.IED.checkInterval)
        end
    end)

    -- Input thread
    CreateThread(function()
        while Config.IED.enabled do
            if not isDetected then
                CheckInputDesync()
                CheckCursorOverlay()
            end
            Wait(Config.IED.inputCheckInterval)
        end
    end)
end)

-- ========================================
-- DEBUG COMMANDS
-- ========================================
if Config.Debug then
    RegisterCommand('gstats', function()
        print("^2========== GuardianFREE Stats ==========^0")
        print(("Input Desync: ^3%d^0"):format(DetectionStats.inputDesync))
        print(("Camera Anomaly: ^3%d^0"):format(DetectionStats.cameraAnomaly))
        print(("Thread Injection: ^3%d^0"):format(DetectionStats.threadInjection))
        print(("Cursor Overlay: ^3%d^0"):format(DetectionStats.cursorOverlay))
        print(("^1Total Flags: %d/%d^0"):format(detectionFlags, Config.IED.detectionThreshold))
        print("^2========================================^0")
    end, false)
end
