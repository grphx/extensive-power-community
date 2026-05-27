--[[
    Extensive Power Rework - Main Module

    Entry point for the mod. Handles initialization, global state,
    event registration, and data persistence.

    Features:
    - City-level power restoration via substations
    - City-level water restoration via treatment plants
    - Building-level power via stationary generators
    - Building-level water via water tanks
    - Zone-based utility control
    - MP synchronization
]]--

print("[EPR] EPR_Main.lua loading...")

-- ============================================
-- GLOBAL NAMESPACE
-- ============================================

EPR = EPR or {}
EPR.VERSION = "1.0.4"
EPR.DEBUG = false  -- Default off, controlled by sandbox option

-- Helper to check debug mode from sandbox options
function EPR.IsDebugMode()
    if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.DebugMode ~= nil then
        return SandboxVars.EPR.DebugMode
    end
    -- Fallback for early UI open before SandboxVars is ready
    if getSandboxOptions then
        local ok, options = pcall(getSandboxOptions)
        if ok and options and options.getOptionByName then
            local opt = options:getOptionByName("EPR.DebugMode")
            if opt and opt.getValue then
                local value = opt:getValue()
                if value ~= nil then
                    return value == true or value == 1
                end
            end
        end
    end
    return EPR.DEBUG
end

function EPR.LogDebug(message)
    if EPR.IsDebugMode and EPR.IsDebugMode() then
        print(message)
    end
end

-- Localization helper. Uses PZ's getText() with a fallback string for untranslated keys.
-- Positional args (%1, %2, ...) are substituted manually to avoid relying on table.unpack.
local function EPR_ApplyArgs(str, args)
    local function replaceArg(n)
        local v = args[tonumber(n)]
        if v ~= nil then return tostring(v) end
    end
    str = str:gsub("%%(%d+)%$s", replaceArg)
    str = str:gsub("%%(%d+)", replaceArg)
    str = str:gsub("%%%%", "%%")
    return str
end

function EPR.GetText(key, fallback, ...)
    local args = {...}
    local t = getText and getText(key)
    local str = (t and t ~= key) and t or fallback
    if #args > 0 then
        return EPR_ApplyArgs(str, args)
    end
    return str
end

-- ============================================
-- GLOBAL STATE (Synced in MP)
-- ============================================

-- Zone power/water status: {zoneName = true/false}
EPR.PoweredZones = {}
EPR.WaterZones = {}

-- Facility status tables
-- Structure: {facilityId = {status, health, lastMaintenance, repairQuality, ...}}
EPR.Substations = {}
EPR.WaterPlants = {}
EPR.Generators = {}    -- Stationary generators
EPR.WaterTanks = {}
EPR.ConnectedBuildings = {}
EPR.ConnectedStreetLights = {}
EPR.SpriteGenerators = {}

-- Active repair operations: {playerId = {facilityId, facilityType, stage, startTime, ...}}
EPR.ActiveRepairs = {}

-- ============================================
-- CONFIGURATION
-- ============================================

EPR.Config = {
    -- Skill requirements (base values, modified by sandbox options)
    SubstationSkills = {
        Electrical = 7,
        Mechanics = 5,
        MetalWelding = 4,
    },
    WaterPlantSkills = {
        Electrical = 4,
        Mechanics = 7,
        MetalWelding = 5,
    },

    -- Repair stages (active work time in minutes)
    -- These are BASE times at minimum skill level
    RepairStages = {
        Assessment = {
            baseTime = 30,          -- 30 minutes
            description = "Inspecting damaged components",
            skillWeight = 0.3,      -- 30% skill reduction possible
        },
        PartReplacement = {
            baseTime = 360,         -- 6 hours (360 minutes)
            description = "Installing replacement parts",
            skillWeight = 0.5,      -- 50% skill reduction possible
        },
        Calibration = {
            baseTime = 90,          -- 1.5 hours
            description = "Calibrating systems",
            skillWeight = 0.4,      -- 40% skill reduction possible
        },
        Startup = {
            baseTime = 5,           -- 5 minutes (fixed, no skill reduction)
            description = "Starting up - DEFEND!",
            skillWeight = 0,        -- No reduction - always 5 min defense
            attractsZombies = true,
        },
    },

    -- Stage order
    RepairStageOrder = {"Assessment", "PartReplacement", "Calibration", "Startup"},

    -- Degradation (after facility is online)
    BaseDegradationPerDay = 1.0,  -- 1% health loss per day
    BreakdownThreshold = 50,      -- Health below 50% can trigger breakdown

    -- Noise
    RepairNoiseRadius = 100,      -- Tiles during repair work
    StartupNoiseRadius = 150,     -- Tiles during startup phase
    NormalOperationNoise = 20,    -- Minimal noise when running normally

    -- Zone connection caps (0 = unlimited)
    ZoneBuildingCapSP = 0,
    ZoneBuildingCapMP = 100,
    StreetLightRadius = 8,

    -- Building maintenance
    BuildingMaintenanceDays = 14,
    BuildingFlickerHours = 24,
    BuildingMaintenanceItems = {
        { item = "Base.ElectronicsScrap", count = 2 },
        { item = "Base.ElectricWire", count = 1 },
        { item = "Base.LightBulb", count = 1 },
    },

    -- Generator range presets (best-effort; engine may ignore)
    GeneratorRangeSmall = 15,
    GeneratorRangeMedium = 35,
    GeneratorRangeMax = 65,

    -- Building connect action time (minutes)
    BuildingConnectTimeMinutes = 5,

    -- Fridge spoil simulation for offline zones/buildings
    FridgeSpoilIntervalMinutes = 60,
    FridgeSpoilMultiplier = 1.0,
    FridgeSweepRadius = 12,
    FridgeContainerTypes = { "fridge", "freezer" },

    -- Louisville fallback delay before full shutdown (hours)
    LouisvilleOfflineDelayHours = 12,
}

-- ============================================
-- INITIALIZATION
-- ============================================

function EPR.OnGameStart()
    if EPR.initialized then return end
    EPR.initialized = true
    print("[EPR] OnGameStart triggered")

    -- Load persisted data
    EPR.LoadData()

    -- Initialize zones if not loaded
    if EPR.Zones and EPR.Zones.InitializeZones then
        EPR.Zones.InitializeZones()
    end

    if EPR.RepairState and EPR.RepairState.EnsureAllFacilities then
        EPR.RepairState.EnsureAllFacilities()
    end

    if EPR.Buildings and EPR.Buildings.OnLoaded then
        EPR.Buildings.OnLoaded()
    end

    -- Initialize power/water hooks for actual electricity/water restoration
    if EPR.PowerController and EPR.PowerController.Initialize then
        EPR.PowerController.Initialize()
    end

    print("[EPR] Initialization complete. Version: " .. EPR.VERSION)
    if EPR.IsDebugMode() then
        EPR.PrintStatus()
    end
end

function EPR.OnGameBoot()
    print("[EPR] OnGameBoot - Pre-initialization")
end

function EPR.OnInitGlobalModData()
    -- Ensure server/host loads persisted state even if OnGameStart doesn't fire
    if not EPR.IsServerContext() then return end
    if EPR.initialized then return end
    EPR.initialized = true

    EPR.LoadData()

    if EPR.Zones and EPR.Zones.InitializeZones then
        EPR.Zones.InitializeZones()
    end

    if EPR.RepairState and EPR.RepairState.EnsureAllFacilities then
        EPR.RepairState.EnsureAllFacilities()
    end

    if EPR.Buildings and EPR.Buildings.OnLoaded then
        EPR.Buildings.OnLoaded()
    end

    if EPR.PowerController and EPR.PowerController.Initialize then
        EPR.PowerController.Initialize()
    end
end

-- ============================================
-- DATA PERSISTENCE
-- ============================================

-- Helper to check if we're on the server (authoritative for data)
function EPR.IsServerContext()
    -- In SP: isServer() = false, isClient() = true, but we ARE authoritative
    -- In MP Server: isServer() = true
    -- In MP Client: isClient() = true, isServer() = false
    local server = isServer()
    local client = isClient()

    -- Dedicated server: isServer=true, isClient=false
    -- MP client: isServer=false, isClient=true
    -- SP: isServer=false, isClient=true (but we're authoritative)
    -- Host (listen server): isServer=true, isClient=true

    if server then
        return true  -- Dedicated server or host
    end

    if client and not server then
        -- Could be SP or MP client
        -- B42 exposes isMultiplayer() as the cleanest check
        if isMultiplayer and isMultiplayer() then
            return false  -- MP client, not authoritative
        end
        -- Fallback: getServerOptions() exists and returns something in MP
        if getServerOptions then
            local ok, opts = pcall(getServerOptions)
            if ok and opts then return false end
        end
        return true  -- Single player, we're authoritative
    end

    return true  -- Default to authoritative (SP fallback)
end

function EPR.SaveData()
    -- CRITICAL: Only SERVER saves data in MP
    if not EPR.IsServerContext() then
        EPR.LogDebug("[EPR] SaveData skipped - not server context")
        return
    end

    if not ModData then
        print("[EPR] Warning: ModData not available for saving")
        return
    end

    local gmd = ModData.getOrCreate("EPR_GridData")
    if not gmd then return end

    gmd.PoweredZones = EPR.PoweredZones
    gmd.WaterZones = EPR.WaterZones
    gmd.Substations = EPR.Substations
    gmd.WaterPlants = EPR.WaterPlants
    gmd.Generators = EPR.Generators
    gmd.WaterTanks = EPR.WaterTanks
    gmd.ActiveRepairs = EPR.ActiveRepairs or (EPR.Server and EPR.Server.ActiveRepairs) or {}
    gmd.ConnectedBuildings = EPR.ConnectedBuildings or {}
    gmd.ConnectedStreetLights = EPR.ConnectedStreetLights or {}
    gmd.SpriteGenerators = EPR.SpriteGenerators or {}
    gmd.PowerController = {
        originalElecShut = EPR.PowerController and EPR.PowerController.originalElecShutModifier or nil,
        originalWaterShut = EPR.PowerController and EPR.PowerController.originalWaterShutModifier or nil,
        powerNetworkOnline = EPR.PowerController and EPR.PowerController.powerNetworkOnline or false,
        waterNetworkOnline = EPR.PowerController and EPR.PowerController.waterNetworkOnline or false,
    }
    gmd.LastSavedWorldHours = getGameTime() and getGameTime():getWorldAgeHours() or nil
    gmd.VERSION = EPR.VERSION

    EPR.LogDebug("[EPR] Data saved to GlobalModData")

    -- Debug: Log facility statuses
    if EPR.IsDebugMode() then
        for id, state in pairs(EPR.Substations) do
            print("[EPR]   Substation " .. id .. ": " .. tostring(state.status))
        end
        for id, state in pairs(EPR.WaterPlants) do
            print("[EPR]   WaterPlant " .. id .. ": " .. tostring(state.status))
        end
    end
end

function EPR.LoadData()
    -- CRITICAL: Only SERVER loads data in MP
    -- Clients receive state via sync from server
    if not EPR.IsServerContext() then
        EPR.LogDebug("[EPR] LoadData skipped - not server context (will receive from server sync)")
        return
    end

    if not ModData then
        print("[EPR] Warning: ModData not available for loading")
        return
    end

    -- Try loading new EPR data first, then fall back to old EGO data for migration
    local gmd = ModData.get("EPR_GridData")

    -- Migration: Check for old EGO data
    if not gmd then
        gmd = ModData.get("EGO_GridData")
        if gmd then
            EPR.LogDebug("[EPR] Migrating data from EGO_GridData to EPR_GridData...")
        end
    end

    if gmd then
        EPR.PoweredZones = gmd.PoweredZones or {}
        EPR.WaterZones = gmd.WaterZones or {}
        EPR.Substations = gmd.Substations or {}
        EPR.WaterPlants = gmd.WaterPlants or {}
        EPR.Generators = gmd.Generators or {}
        EPR.WaterTanks = gmd.WaterTanks or {}
        -- Active repairs are transient per session; the authoritative lock is
        -- EPR.Server.ActiveRepairs (reset on server start). Never restore stale
        -- locks from the save or a crash/interrupt leaves repairs permanently
        -- blocked ("already repairing another part") — see Bug 1.
        EPR.ActiveRepairs = {}
        EPR.ConnectedBuildings = gmd.ConnectedBuildings or {}
        EPR.ConnectedStreetLights = gmd.ConnectedStreetLights or {}
        EPR.SpriteGenerators = gmd.SpriteGenerators or {}

        if gmd.PowerController and EPR.PowerController then
            if gmd.PowerController.originalElecShut ~= nil then
                EPR.PowerController.originalElecShutModifier = gmd.PowerController.originalElecShut
            end
            if gmd.PowerController.originalWaterShut ~= nil then
                EPR.PowerController.originalWaterShutModifier = gmd.PowerController.originalWaterShut
            end
            if gmd.PowerController.powerNetworkOnline ~= nil then
                EPR.PowerController.powerNetworkOnline = gmd.PowerController.powerNetworkOnline
            end
            if gmd.PowerController.waterNetworkOnline ~= nil then
                EPR.PowerController.waterNetworkOnline = gmd.PowerController.waterNetworkOnline
            end
        end

        local savedVer = tostring(gmd.VERSION or "unknown")
        EPR.LogDebug("[EPR] Data loaded from GlobalModData (version: " .. savedVer .. ")")
        if gmd.VERSION and gmd.VERSION ~= EPR.VERSION then
            print("[EPR] WARNING: Saved data version " .. savedVer .. " differs from mod version " .. EPR.VERSION .. ". State may need migration.")
        end

        -- Debug: Log loaded facility statuses
        local substationCount = 0
        for id, state in pairs(EPR.Substations) do
            substationCount = substationCount + 1
            print("[EPR]   Loaded Substation " .. id .. ": " .. tostring(state.status))
        end
        local plantCount = 0
        for id, state in pairs(EPR.WaterPlants) do
            plantCount = plantCount + 1
            print("[EPR]   Loaded WaterPlant " .. id .. ": " .. tostring(state.status))
        end
        EPR.LogDebug("[EPR] Total: " .. substationCount .. " substations, " .. plantCount .. " water plants")

        -- Re-save under new key if migrated
        if ModData.get("EGO_GridData") and not ModData.get("EPR_GridData") then
            EPR.SaveData()
            EPR.LogDebug("[EPR] Data migration complete")
        end
    else
        EPR.LogDebug("[EPR] No saved data found, starting fresh")
        EPR.PoweredZones = {}
        EPR.WaterZones = {}
        EPR.Substations = {}
        EPR.WaterPlants = {}
        EPR.Generators = {}
        EPR.WaterTanks = {}
        EPR.ActiveRepairs = {}
        EPR.ConnectedBuildings = {}
        EPR.ConnectedStreetLights = {}
        EPR.SpriteGenerators = {}
    end
end

-- ============================================
-- TICK HANDLERS
-- ============================================

local tickCounter = 0
local TICK_INTERVAL = 60  -- Process every 60 ticks (~1 second)

function EPR.OnTick()
    if EPR.IsServerContext and not EPR.IsServerContext() then
        return
    end
    tickCounter = tickCounter + 1
    if tickCounter < TICK_INTERVAL then return end
    tickCounter = 0

    -- Update active repairs
    EPR.UpdateActiveRepairs()
end

function EPR.OnTenMinutes()
    if not EPR.IsServerContext() then return end
    -- Check if Immersive Blackouts changed state since last tick
    if EPR.PowerController and EPR.PowerController.CheckIBStateChange then
        EPR.PowerController.CheckIBStateChange()
    end
    if EPR.PowerController and EPR.PowerController.UpdateNetworks then
        EPR.PowerController.UpdateNetworks()
    end

    -- Force a full-world sweep every 10 minutes to correct buildings in
    -- newly loaded chunks that received vanilla power (ElecShutModifier=45000
    -- gives power to every chunk as it loads — we must re-cut offline zones).
    if EPR.Buildings and EPR.Buildings.ApplySimulationForAllZones then
        EPR.Buildings.simulationDirty = true
        EPR.Buildings.ApplySimulationForAllZones()
    end

    -- Check generator fuel consumption
    local hasGenerators = false
    if EPR.Generators then
        for _ in pairs(EPR.Generators) do
            hasGenerators = true
            break
        end
    end
    if hasGenerators then
        EPR.UpdateGeneratorFuel()
    end

    if EPR.Buildings and EPR.Buildings.UpdateMaintenance then
        EPR.Buildings.UpdateMaintenance()
    end

    -- Save data periodically
    EPR.SaveData()
end

function EPR.OnEveryHour()
    if EPR.Maintenance and EPR.Maintenance.UpdateAll then
        EPR.Maintenance.UpdateAll()
    end

    if not EPR.IsServerContext or not EPR.IsServerContext() then return end

    if EPR.Buildings and EPR.Buildings.UpdateSpriteGeneratorRuntime then
        EPR.Buildings.UpdateSpriteGeneratorRuntime()
    end
end

function EPR.OnEveryDay()
    if not EPR.IsServerContext() then return end
    -- Check for random breakdowns
    if EPR.Maintenance and EPR.Maintenance.CheckBreakdowns then
        EPR.Maintenance.CheckBreakdowns()
    end
end

-- ============================================
-- REPAIR SYSTEM
-- ============================================

function EPR.UpdateActiveRepairs()
    -- Check if we have any active repairs
    if not EPR.ActiveRepairs then return end

    local hasRepairs = false
    for _ in pairs(EPR.ActiveRepairs) do
        hasRepairs = true
        break
    end
    if not hasRepairs then return end

    -- Get current time safely
    local gameTime = getGameTime and getGameTime()
    if not gameTime then return end

    local currentHour = gameTime:getWorldAgeHours()

    for playerId, repair in pairs(EPR.ActiveRepairs) do
        -- Check if repair stage is complete
        if repair and repair.stageEndTime and currentHour >= repair.stageEndTime then
            EPR.AdvanceRepairStage(playerId, repair)
        end
    end
end

function EPR.AdvanceRepairStage(playerId, repair)
    -- Placeholder - will be implemented in EPR_Substations.lua / EPR_WaterTreatment.lua
    if EPR.IsDebugMode() then
        print("[EPR] Advancing repair stage for player: " .. tostring(playerId))
    end
end

-- ============================================
-- GENERATOR FUEL
-- ============================================

function EPR.UpdateGeneratorFuel()
    -- Placeholder - will be implemented in EPR_Generators.lua
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

function EPR.IsZonePowered(zoneName)
    return EPR.PoweredZones[zoneName] == true
end

function EPR.IsZoneWatered(zoneName)
    return EPR.WaterZones[zoneName] == true
end

function EPR.SetZonePower(zoneName, powered)
    local wasPowered = EPR.PoweredZones[zoneName]
    EPR.PoweredZones[zoneName] = powered

    if wasPowered ~= powered then
        print("[EPR] Zone '" .. zoneName .. "' power changed: " .. tostring(powered))
        EPR.SaveData()

        if EPR.Buildings and EPR.Buildings.ApplyZonePower then
            EPR.Buildings.ApplyZonePower(zoneName, powered)
        end

        -- Trigger event for UI updates
        if EPR.Events and EPR.Events.OnZonePowerChanged then
            EPR.Events.OnZonePowerChanged(zoneName, powered)
        end
    end
end

function EPR.SetZoneWater(zoneName, watered)
    local wasWatered = EPR.WaterZones[zoneName]
    EPR.WaterZones[zoneName] = watered

    if wasWatered ~= watered then
        print("[EPR] Zone '" .. zoneName .. "' water changed: " .. tostring(watered))
        EPR.SaveData()

        if EPR.Buildings and EPR.Buildings.ApplyZoneWater then
            EPR.Buildings.ApplyZoneWater(zoneName, watered)
        end

        -- Trigger event for UI updates
        if EPR.Events and EPR.Events.OnZoneWaterChanged then
            EPR.Events.OnZoneWaterChanged(zoneName, watered)
        end
    end
end

-- Get player's current zone
function EPR.GetPlayerZone(player)
    if not player then return nil end

    local x = player:getX()
    local y = player:getY()

    if EPR.Zones and EPR.Zones.GetZoneAt then
        return EPR.Zones.GetZoneAt(x, y)
    end

    return nil
end

-- Check if player has required skills
function EPR.PlayerMeetsSkillRequirements(player, requirements)
    if not player or not requirements then return false end

    for skill, level in pairs(requirements) do
        local perk = Perks[skill]
        if perk then
            local playerLevel = player:getPerkLevel(perk)
            if playerLevel < level then
                return false, skill, level, playerLevel
            end
        end
    end

    return true
end

-- ============================================
-- DEBUG
-- ============================================

function EPR.PrintStatus()
    print("[EPR] === Current Status ===")

    local poweredCount = 0
    for zone, powered in pairs(EPR.PoweredZones) do
        if powered then poweredCount = poweredCount + 1 end
    end
    print("[EPR] Powered zones: " .. poweredCount)

    local wateredCount = 0
    for zone, watered in pairs(EPR.WaterZones) do
        if watered then wateredCount = wateredCount + 1 end
    end
    print("[EPR] Watered zones: " .. wateredCount)

    local substationCount = 0
    for _ in pairs(EPR.Substations) do substationCount = substationCount + 1 end
    print("[EPR] Substations: " .. substationCount)

    local plantCount = 0
    for _ in pairs(EPR.WaterPlants) do plantCount = plantCount + 1 end
    print("[EPR] Water plants: " .. plantCount)

    print("[EPR] =========================")
end

-- Debug command to toggle zone power (for testing)
function EPR.DebugToggleZonePower(zoneName)
    local current = EPR.PoweredZones[zoneName] or false
    EPR.SetZonePower(zoneName, not current)
    print("[EPR DEBUG] Toggled " .. zoneName .. " power to: " .. tostring(not current))
end

-- Debug command to toggle zone water (for testing)
function EPR.DebugToggleZoneWater(zoneName)
    local current = EPR.WaterZones[zoneName] or false
    EPR.SetZoneWater(zoneName, not current)
    print("[EPR DEBUG] Toggled " .. zoneName .. " water to: " .. tostring(not current))
end

-- ============================================
-- EVENT REGISTRATION
-- ============================================

print("[EPR] Registering events...")

if Events then
    Events.OnGameBoot.Add(EPR.OnGameBoot)
    Events.OnInitGlobalModData.Add(EPR.OnInitGlobalModData)
    Events.OnGameStart.Add(EPR.OnGameStart)
    Events.OnTick.Add(EPR.OnTick)
    Events.EveryTenMinutes.Add(EPR.OnTenMinutes)
    Events.EveryHours.Add(EPR.OnEveryHour)
    Events.EveryDays.Add(EPR.OnEveryDay)

    print("[EPR] Events registered successfully")
else
    print("[EPR] ERROR: Events table not available!")
end

print("[EPR] EPR_Main.lua loaded successfully")
