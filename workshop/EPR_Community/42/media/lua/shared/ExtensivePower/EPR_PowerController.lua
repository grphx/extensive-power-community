--[[
    Extensive Power Rework - Power Controller (B42 Per-Facility)

    Controls global power/water only via Louisville Plant.
    Each facility independently controls its assigned zones.
    If Louisville goes offline, all zones are forced offline.
]]--

local function logDebug(message)
    if EPR and EPR.IsDebugMode and EPR.IsDebugMode() then
        print(message)
    end
end

-- B42/B41 compatible sandbox option setter
local function applySandboxOption(key, value)
    if SandboxVars then
        SandboxVars[key] = value
    end
    local ok, sandbox = pcall(getSandboxOptions)
    if not ok or not sandbox then return end
    local setOk, setErr = pcall(function() sandbox:set(key, value) end)
    if not setOk then logDebug("[EPR PowerController] sandbox:set(" .. tostring(key) .. ") error: " .. tostring(setErr)) end
    if sandbox.applySettings then
        pcall(function() sandbox:applySettings() end)
    elseif sandbox.toLua then
        pcall(function() sandbox:toLua() end)
    end
end

logDebug("[EPR] EPR_PowerController.lua loading...")

EPR = EPR or {}
EPR.PowerController = {}

-- ============================================
-- CORE STATE TRACKING
-- ============================================

-- Original sandbox values (captured early)
EPR.PowerController.originalElecShutModifier = nil
EPR.PowerController.originalWaterShutModifier = nil

-- Current network status (legacy)
EPR.PowerController.powerNetworkOnline = false
EPR.PowerController.waterNetworkOnline = false
EPR.PowerController.globalOverride = false
EPR.PowerController.louisvilleOfflineSinceHours = nil
EPR.PowerController.louisvilleEverOnline = false

EPR.PowerController.initialized = false

-- Immersive Blackouts integration state
EPR.PowerController.lastIBBlackoutState = nil
EPR.PowerController.lastIBWaterState = nil

-- ============================================
-- IMMERSIVE BLACKOUTS INTEGRATION
-- ============================================

function EPR.PowerController.IsIBActive()
    return ImmersiveBlackouts ~= nil or ImmersiveBlackouts_isBlackout ~= nil
end

function EPR.PowerController.IBCompatEnabled()
    if not EPR.PowerController.IsIBActive() then return false end
    if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.IBCompatMode == false then
        return false
    end
    return true
end

function EPR.PowerController.CheckIBStateChange()
    if not EPR.PowerController.IBCompatEnabled() then return end

    local currentBlackout = ImmersiveBlackouts_isBlackout
    local currentWaterShut = ImmersiveBlackouts_isWaterShut

    local blackoutChanged = currentBlackout ~= EPR.PowerController.lastIBBlackoutState
    local waterChanged = currentWaterShut ~= EPR.PowerController.lastIBWaterState

    if blackoutChanged or waterChanged then
        EPR.PowerController.lastIBBlackoutState = currentBlackout
        EPR.PowerController.lastIBWaterState = currentWaterShut
        logDebug("[EPR PowerController] IB state changed — re-asserting per-building power")
        if EPR.Buildings then
            EPR.Buildings.simulationDirty = true
            if EPR.Buildings.ApplyAllZones then
                EPR.Buildings.ApplyAllZones()
            end
        end
    end
end

-- ============================================
-- ORIGINAL VALUE CAPTURE
-- ============================================

function EPR.PowerController.CaptureOriginalValues()
    if EPR.PowerController.originalElecShutModifier ~= nil then
        return -- Already captured
    end

    local saved = ModData and ModData.get and ModData.get("EPR_GlobalData")
    if saved then
        -- Guard against reloading EPR's own override values (45000 / INT_MAX) as the
        -- "original". This happens when EPR saved while its override was already active.
        if saved.originalElecShut ~= nil
                and saved.originalElecShut ~= 45000
                and saved.originalElecShut ~= 2147483647 then
            EPR.PowerController.originalElecShutModifier = saved.originalElecShut
        end
        if saved.originalWaterShut ~= nil
                and saved.originalWaterShut ~= 2147483647 then
            EPR.PowerController.originalWaterShutModifier = saved.originalWaterShut
        end
    end

    if SandboxVars then
        if EPR.PowerController.originalElecShutModifier == nil then
            local sv = SandboxVars.ElecShutModifier
            -- Only use the live value if it isn't already one of EPR's override sentinels
            if sv ~= 45000 and sv ~= 2147483647 then
                EPR.PowerController.originalElecShutModifier = sv
            end
        end
        if EPR.PowerController.originalWaterShutModifier == nil then
            local sv = SandboxVars.WaterShutModifier
            if sv ~= 2147483647 then
                EPR.PowerController.originalWaterShutModifier = sv
            end
        end
        logDebug("[EPR PowerController] Captured original values:")
        logDebug("  ElecShutModifier: " .. tostring(EPR.PowerController.originalElecShutModifier))
        logDebug("  WaterShutModifier: " .. tostring(EPR.PowerController.originalWaterShutModifier))
    end

    -- Store in ModData for persistence (SERVER ONLY in MP)
    if EPR.PowerController.IsServerContext and EPR.PowerController.IsServerContext() then
        local modData = ModData.getOrCreate("EPR_PowerController")
        if modData then
            if EPR.PowerController.originalElecShutModifier then
                modData.originalElecShut = EPR.PowerController.originalElecShutModifier
            end
            if EPR.PowerController.originalWaterShutModifier then
                modData.originalWaterShut = EPR.PowerController.originalWaterShutModifier
            end
            logDebug("[EPR PowerController] Stored original values in GlobalModData")
        end
    else
        logDebug("[EPR PowerController] MP Client - skipping GlobalModData write")
    end
end

-- ============================================
-- GLOBAL POWER/WATER CONTROL
-- ============================================

function EPR.PowerController.EnableGlobalPower()
    if EPR.PowerController.powerNetworkOnline then
        return -- Already enabled
    end

    if EPR.PowerController.originalElecShutModifier == nil then
        EPR.PowerController.CaptureOriginalValues()
    end

    -- Set ElecShutModifier to max (power "never" shuts off)
    -- Skip if IB compat is active — IB owns the global modifier
    if not EPR.PowerController.IBCompatEnabled() then
        applySandboxOption("ElecShutModifier", 2147483647)
    end
    logDebug("[EPR PowerController] POWER NETWORK ONLINE - Global power enabled")

    EPR.PowerController.powerNetworkOnline = true
end

function EPR.PowerController.IsServerContext()
    if isServer() then
        return true
    end
    if not isClient() then
        return true
    end
    if getServerOptions and getServerOptions() then
        return false
    end
    return true
end

local function loadPersistentState()
    if not ModData or not ModData.getOrCreate then return end
    local modData = ModData.getOrCreate("EPR_PowerController")
    if modData and modData.louisvilleEverOnline ~= nil then
        EPR.PowerController.louisvilleEverOnline = modData.louisvilleEverOnline == true
    end
end

local function saveLouisvilleEverOnline()
    if not EPR.PowerController.IsServerContext() then return end
    if not ModData or not ModData.getOrCreate then return end
    local modData = ModData.getOrCreate("EPR_PowerController")
    if modData then
        modData.louisvilleEverOnline = EPR.PowerController.louisvilleEverOnline == true
    end
end

function EPR.PowerController.DisableGlobalPower()
    if not EPR.PowerController.powerNetworkOnline then
        return -- Already disabled
    end

    local originalValue = EPR.PowerController.originalElecShutModifier or -1
    if not EPR.PowerController.IBCompatEnabled() then
        applySandboxOption("ElecShutModifier", originalValue)
    end
    logDebug("[EPR PowerController] POWER NETWORK OFFLINE - Global power disabled")

    EPR.PowerController.powerNetworkOnline = false
end

function EPR.PowerController.EnableGlobalWater()
    if EPR.PowerController.waterNetworkOnline then
        return
    end

    if EPR.PowerController.originalWaterShutModifier == nil then
        EPR.PowerController.CaptureOriginalValues()
    end

    if not EPR.PowerController.IBCompatEnabled() then
        applySandboxOption("WaterShutModifier", 2147483647)
    end
    logDebug("[EPR PowerController] WATER NETWORK ONLINE - Global water enabled")

    EPR.PowerController.waterNetworkOnline = true
end

function EPR.PowerController.DisableGlobalWater()
    if not EPR.PowerController.waterNetworkOnline then
        return
    end

    local originalValue = EPR.PowerController.originalWaterShutModifier or -1
    if not EPR.PowerController.IBCompatEnabled() then
        applySandboxOption("WaterShutModifier", originalValue)
    end
    logDebug("[EPR PowerController] WATER NETWORK OFFLINE - Global water disabled")

    EPR.PowerController.waterNetworkOnline = false
end

function EPR.PowerController.EnableGlobalOverride()
    if EPR.PowerController.globalOverride then
        return
    end

    if EPR.PowerController.originalElecShutModifier == nil or EPR.PowerController.originalWaterShutModifier == nil then
        EPR.PowerController.CaptureOriginalValues()
    end

    if EPR.PowerController.IsServerContext() and not EPR.PowerController.IBCompatEnabled() then
        applySandboxOption("ElecShutModifier", 45000)
        applySandboxOption("WaterShutModifier", 2147483647)
    end

    EPR.PowerController.globalOverride = true
    logDebug("[EPR PowerController] Global override enabled")

    if EPR.Buildings then
        EPR.Buildings.simulationDirty = true
        if EPR.Buildings.ApplySimulationForAllZones then
            EPR.Buildings.ApplySimulationForAllZones()
        end
    end
end

-- Power outage is "active" (EPR should be managing the grid) exactly when the
-- vanilla grid is down. Delegating to EPR.Zones.IsPowerShutoff keeps this in
-- lockstep with the predicate that gates repairs (EPR.Zones.CanRepairFacility),
-- so "you were allowed to repair it" always implies "it will turn on" — the
-- invariant that the previous day-only math broke for "X months later" starts.
function EPR.PowerController.IsPowerOutageActive()
    if EPR.Zones and EPR.Zones.IsPowerShutoff then
        local ok, off = pcall(EPR.Zones.IsPowerShutoff)
        if ok then
            return off == true
        end
    end

    -- Defensive fallback only if EPR.Zones isn't available yet (should not
    -- happen at runtime — both are shared modules).
    local shutoffDay = EPR.PowerController.originalElecShutModifier
    if shutoffDay == nil and SandboxVars then
        shutoffDay = SandboxVars.ElecShutModifier
    end
    if type(shutoffDay) == "string" then
        shutoffDay = tonumber(shutoffDay)
    end
    if shutoffDay == nil then return false end
    if shutoffDay == -1 then return true end
    if shutoffDay > 3650 then return false end
    local gameTime = getGameTime()
    if not gameTime then return false end
    local currentDay = math.floor(gameTime:getWorldAgeDaysSinceBegin())
    return shutoffDay >= 0 and currentDay >= shutoffDay
end

function EPR.PowerController.DisableGlobalOverride()
    if not EPR.PowerController.globalOverride then
        return
    end

    local originalElec = EPR.PowerController.originalElecShutModifier or -1
    local originalWater = EPR.PowerController.originalWaterShutModifier or -1

    if EPR.PowerController.IsServerContext() then
        applySandboxOption("ElecShutModifier", originalElec)
        applySandboxOption("WaterShutModifier", originalWater)
    end

    EPR.PowerController.globalOverride = false
    logDebug("[EPR PowerController] Global override disabled")
end

function EPR.PowerController.UpdateGlobalOverride()
    local effectiveOnline = EPR.PowerController.IsLouisvilleEffectivelyOnline and EPR.PowerController.IsLouisvilleEffectivelyOnline()
    local requirePrereq = true
    local louisvilleEnabled = true
    if SandboxVars and SandboxVars.EPR then
        if SandboxVars.EPR.RequirePrerequisite ~= nil then
            requirePrereq = SandboxVars.EPR.RequirePrerequisite
        end
        if SandboxVars.EPR.LouisvillePlantEnabled ~= nil then
            louisvilleEnabled = SandboxVars.EPR.LouisvillePlantEnabled
        end
    end
    if (not requirePrereq) or (not louisvilleEnabled) then
        effectiveOnline = EPR.PowerController.IsAnyFacilityOnline and EPR.PowerController.IsAnyFacilityOnline()
    end
    local powerShutoff = EPR.PowerController.IsPowerOutageActive()
    local spriteActive = EPR.PowerController.IsAnySpriteGeneratorActive and EPR.PowerController.IsAnySpriteGeneratorActive()
    if (effectiveOnline or spriteActive) and powerShutoff then
        EPR.PowerController.EnableGlobalOverride()
        -- Re-derive zone power/water from current facility states now that the
        -- override is asserted. Without this, the load/restart path (and the SP
        -- repair path, which runs UpdateZoneStatus *before* the override flips)
        -- leaves every zone stuck offline even though facilities are online —
        -- the root cause of "repaired everything but still no power/water".
        if EPR.Zones and EPR.Zones.UpdateZoneStatus then
            EPR.Zones.UpdateZoneStatus()
        end
    else
        EPR.PowerController.DisableGlobalOverride()
        if EPR.PowerController.originalElecShutModifier == nil or EPR.PowerController.originalWaterShutModifier == nil then
            EPR.PowerController.CaptureOriginalValues()
        end
        if SandboxVars then
            if SandboxVars.ElecShutModifier == 45000 and EPR.PowerController.originalElecShutModifier == 45000 then
                applySandboxOption("ElecShutModifier", -1)
            end
            if SandboxVars.WaterShutModifier == 2147483647 and EPR.PowerController.originalWaterShutModifier == 2147483647 then
                applySandboxOption("WaterShutModifier", -1)
            end
        end
        if EPR.Zones and EPR.Zones.UpdateZoneStatus then
            EPR.Zones.UpdateZoneStatus()
        end
    end
end

function EPR.PowerController.IsLouisvilleEffectivelyOnline()
    local louisville = EPR.Substations and EPR.Substations["louisville_plant"]
    local online = louisville and louisville.status == "online"
    if online then
        EPR.PowerController.louisvilleOfflineSinceHours = nil
        if not EPR.PowerController.louisvilleEverOnline then
            EPR.PowerController.louisvilleEverOnline = true
            saveLouisvilleEverOnline()
        end
        return true
    end

    if not EPR.PowerController.louisvilleEverOnline then
        EPR.PowerController.louisvilleOfflineSinceHours = nil
        return false
    end

    local delayHours = (EPR.Config and EPR.Config.LouisvilleOfflineDelayHours) or 0
    if delayHours <= 0 then
        EPR.PowerController.louisvilleOfflineSinceHours = nil
        return false
    end

    local gt = getGameTime and getGameTime()
    local now = gt and gt:getWorldAgeHours() or nil
    if not now then
        EPR.PowerController.louisvilleOfflineSinceHours = nil
        return false
    end

    if not EPR.PowerController.louisvilleOfflineSinceHours then
        EPR.PowerController.louisvilleOfflineSinceHours = now
        return true
    end

    if (now - EPR.PowerController.louisvilleOfflineSinceHours) < delayHours then
        return true
    end

    EPR.PowerController.louisvilleOfflineSinceHours = nil
    return false
end

function EPR.PowerController.IsAnyFacilityOnline()
    if EPR.Substations then
        for _, state in pairs(EPR.Substations) do
            if state and state.status == "online" then
                return true
            end
        end
    end
    if EPR.WaterPlants then
        for _, state in pairs(EPR.WaterPlants) do
            if state and state.status == "online" then
                return true
            end
        end
    end
    return false
end

function EPR.PowerController.IsAnySpriteGeneratorActive()
    if not EPR.SpriteGenerators then return false end
    for _, record in pairs(EPR.SpriteGenerators) do
        if record and EPR.Buildings and EPR.Buildings.IsSpriteGeneratorActive then
            if EPR.Buildings.IsSpriteGeneratorActive(record) then
                return true
            end
        elseif record and record.active == true then
            return true
        end
    end
    return false
end

-- ============================================
-- NETWORK STATUS CHECKING
-- ============================================

-- Check if all facilities in a network are online
function EPR.PowerController.CheckNetworkStatus(networkName)
    return false
end

-- Update both networks based on facility statuses
function EPR.PowerController.UpdateNetworks()
    if EPR.PowerController.IsServerContext and not EPR.PowerController.IsServerContext() then
        return
    end

    local prevOverride = EPR.PowerController.globalOverride
    EPR.PowerController.UpdateGlobalOverride()
    EPR.PowerController.powerNetworkOnline = false
    EPR.PowerController.waterNetworkOnline = false

    if prevOverride ~= EPR.PowerController.globalOverride then
        if EPR.Server and EPR.Server.BroadcastGlobalOverrideChange then
            EPR.Server.BroadcastGlobalOverrideChange(EPR.PowerController.globalOverride)
        end
    end
end

-- ============================================
-- FACILITY STATUS HANDLERS
-- ============================================

-- Called when any facility comes online
function EPR.PowerController.OnFacilityOnline(facilityId)
    logDebug("[EPR PowerController] Facility online: " .. tostring(facilityId))
    if facilityId == "louisville_plant" then
        EPR.PowerController.louisvilleEverOnline = true
        EPR.PowerController.louisvilleOfflineSinceHours = nil
        saveLouisvilleEverOnline()
    end
    EPR.PowerController.UpdateNetworks()
end

-- Called when any facility goes offline
function EPR.PowerController.OnFacilityOffline(facilityId)
    logDebug("[EPR PowerController] Facility offline: " .. tostring(facilityId))
    EPR.PowerController.UpdateNetworks()
end

-- ============================================
-- HELPER FUNCTIONS (for UI/other systems)
-- ============================================

function EPR.PowerController.IsPowerNetworkOnline()
    return false
end

function EPR.PowerController.IsWaterNetworkOnline()
    return false
end

-- Get facilities that are preventing a network from being online
function EPR.PowerController.GetOfflineFacilitiesInNetwork(networkName)
    return {}
end

-- ============================================
-- INITIALIZATION
-- ============================================

function EPR.PowerController.Initialize()
    logDebug("[EPR PowerController] ====== Initializing per-facility power system ======")
    logDebug("[EPR PowerController] isServer: " .. tostring(isServer()) .. ", isClient: " .. tostring(isClient()))

    loadPersistentState()

    -- Capture original values
    EPR.PowerController.CaptureOriginalValues()

    -- Snapshot IB state so we can detect changes later
    EPR.PowerController.lastIBBlackoutState = ImmersiveBlackouts_isBlackout
    EPR.PowerController.lastIBWaterState = ImmersiveBlackouts_isWaterShut
    if EPR.PowerController.IsIBActive() then
        logDebug("[EPR PowerController] Immersive Blackouts detected — IB compat mode: " .. tostring(EPR.PowerController.IBCompatEnabled()))
    end

    -- Debug: Show current facility states before network check
    logDebug("[EPR PowerController] Current facility states:")
    if EPR.Substations then
        for id, state in pairs(EPR.Substations) do
            logDebug("[EPR PowerController]   Substation " .. id .. ": " .. tostring(state.status))
        end
    else
        logDebug("[EPR PowerController]   No substations loaded!")
    end
    if EPR.WaterPlants then
        for id, state in pairs(EPR.WaterPlants) do
            logDebug("[EPR PowerController]   WaterPlant " .. id .. ": " .. tostring(state.status))
        end
    else
        logDebug("[EPR PowerController]   No water plants loaded!")
    end

    -- Check network status based on saved facility states
    EPR.PowerController.UpdateNetworks()

    EPR.PowerController.initialized = true

    logDebug("[EPR PowerController] ====== Initialization complete ======")
    logDebug("[EPR PowerController] Global override: " .. tostring(EPR.PowerController.globalOverride))
end

-- ============================================
-- DEBUG
-- ============================================

function EPR.PowerController.DebugStatus()
    print("[EPR DEBUG] ========== PowerController Status ==========")
    print("  Initialized: " .. tostring(EPR.PowerController.initialized))
    print("")
    print("  Global override: " .. tostring(EPR.PowerController.globalOverride))
    print("  Original ElecShutModifier: " .. tostring(EPR.PowerController.originalElecShutModifier))
    print("  Original WaterShutModifier: " .. tostring(EPR.PowerController.originalWaterShutModifier))
    print("  Current ElecShutModifier: " .. tostring(SandboxVars and SandboxVars.ElecShutModifier))
    print("  Current WaterShutModifier: " .. tostring(SandboxVars and SandboxVars.WaterShutModifier))
    print("")
    print("[EPR DEBUG] === Network Status ===")
    print("  Per-facility mode (no networks)")

    -- Test actual power
    local player = getPlayer()
    if player then
        local px, py = math.floor(player:getX()), math.floor(player:getY())
        local square = getSquare(px, py, 0)
        if square then
            print("")
            print("[EPR DEBUG] === Power Test at Player ===")
            print("  Location: " .. px .. ", " .. py)
            print("  haveElectricity: " .. tostring(square:haveElectricity()))
        end
    end

    print("[EPR DEBUG] =============================================")
end

-- Global shortcut
EPRDebug = EPR.PowerController.DebugStatus

-- ============================================
-- EVENT REGISTRATION
-- ============================================

local function OnInitGlobalModData()
    logDebug("[EPR PowerController] OnInitGlobalModData - Capturing original values")
    EPR.PowerController.CaptureOriginalValues()
end

local function OnGameStart()
    logDebug("[EPR PowerController] OnGameStart - Initializing")
    EPR.PowerController.Initialize()
end

if Events then
    if Events.OnInitGlobalModData then
        Events.OnInitGlobalModData.Add(OnInitGlobalModData)
        logDebug("[EPR PowerController] Registered for OnInitGlobalModData")
    end

    if Events.OnGameStart then
        Events.OnGameStart.Add(OnGameStart)
        logDebug("[EPR PowerController] Registered for OnGameStart")
    end
else
    print("[EPR PowerController] WARNING: Events not available!")
end

logDebug("[EPR] EPR_PowerController.lua loaded successfully")
