--[[
    Extensive Power Rework - Server Command Handler

    Handles all server-side processing for MP synchronization:
    - Validates repair requests from clients
    - Broadcasts state changes to all players
    - Manages authoritative game state
    - Processes admin commands

    Commands handled:
    - StartRepair: Client requests to start repairing a component
    - CancelRepair: Client cancels active repair
    - CompleteStage: Notify server that a stage was completed
    - RequestSync: Client requests full state synchronization
    - AdminSetPower: Admin toggles zone power (debug/admin only)
]]--

-- Only run on server
if isClient() and not isServer() then return end

local function logDebug(message)
    if EPR and EPR.IsDebugMode and EPR.IsDebugMode() then
        print(message)
    end
end

-- Rate limit table for zombie noise: facilityId -> last noise timestamp (ms)
local lastNoiseTime = {}

local function attractZombies(x, y, z, radius)
    if not (SandboxVars and SandboxVars.EPR and SandboxVars.EPR.ZombieAttractionEnabled) then return end
    local mult = (SandboxVars.EPR.ZombieAttractionMultiplier) or 1.0
    local r = math.floor(radius * mult)
    if r <= 0 then return end
    local sq = getSquare(x, y, z)
    if not sq then return end
    local ok, err = pcall(function() sq:addNoise(r) end)
    if not ok then logDebug("[EPR] attractZombies pcall error: " .. tostring(err)) end
end

logDebug("[EPR Server] EPR_Server.lua loading...")

EPR = EPR or {}
EPR.Server = {}
EPR.Server.loaded = false

function EPR.Server.EnsureLoaded()
    if EPR.Server.loaded then
        return
    end

    if not ModData or not ModData.get then
        return
    end

    if EPR.LoadData then
        EPR.LoadData()
    end

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

    EPR.Server.loaded = true
end

-- Track active repairs per player
EPR.Server.ActiveRepairs = {}

-- ============================================
-- CLIENT COMMAND HANDLER
-- ============================================

function EPR.Server.OnClientCommand(module, command, player, args)
    -- Only handle EPR commands
    if module ~= "EPR" then return end

    local playerName = player:getUsername()
    logDebug("[EPR Server] Received command '" .. command .. "' from " .. playerName)

    if command == "RequestSync" then
        EPR.Server.HandleRequestSync(player)

    elseif command == "StartRepair" then
        EPR.Server.HandleStartRepair(player, args)

    elseif command == "CancelRepair" then
        EPR.Server.HandleCancelRepair(player, args)

    elseif command == "CompleteStage" then
        EPR.Server.HandleCompleteStage(player, args)
    elseif command == "StageProgress" then
        EPR.Server.HandleStageProgress(player, args)

    elseif command == "FacilityOnline" then
        EPR.Server.HandleFacilityOnline(player, args)

    elseif command == "UpdateFacilityState" then
        EPR.Server.HandleUpdateFacilityState(player, args)

    elseif command == "AdminSetPower" then
        EPR.Server.HandleAdminSetPower(player, args)

    elseif command == "AdminSetWater" then
        EPR.Server.HandleAdminSetWater(player, args)

    elseif command == "ConnectBuilding" then
        EPR.Server.HandleConnectBuilding(player, args)

    elseif command == "DisconnectBuilding" then
        EPR.Server.HandleDisconnectBuilding(player, args)

    elseif command == "ConnectAllBuildings" then
        EPR.Server.HandleConnectAllBuildings(player, args)

    elseif command == "ConnectStreetLight" then
        EPR.Server.HandleConnectStreetLight(player, args)

    elseif command == "DisconnectStreetLight" then
        EPR.Server.HandleDisconnectStreetLight(player, args)

    elseif command == "MaintainBuilding" then
        EPR.Server.HandleMaintainBuilding(player, args)

    elseif command == "SetBuildingGeneratorRadius" then
        EPR.Server.HandleSetBuildingGeneratorRadius(player, args)
    elseif command == "HookSpriteGenerator" then
        EPR.Server.HandleHookSpriteGenerator(player, args)
    elseif command == "ToggleSpriteGenerator" then
        EPR.Server.HandleToggleSpriteGenerator(player, args)
    elseif command == "SpriteGeneratorRefuel" then
        EPR.Server.HandleSpriteGeneratorRefuel(player, args)
    elseif command == "SpriteGeneratorMaintain" then
        EPR.Server.HandleSpriteGeneratorMaintain(player, args)

    -- Debug commands (require debug mode)
    elseif command == "DebugRepairAll" then
        EPR.Server.HandleDebugRepairAll(player, args)

    elseif command == "DebugActivate" then
        EPR.Server.HandleDebugActivate(player, args)

    elseif command == "DebugDeactivate" then
        EPR.Server.HandleDebugDeactivate(player, args)

    else
        logDebug("[EPR Server] Unknown command: " .. command)
    end
end

-- ============================================
-- SYNC HANDLERS
-- ============================================

function EPR.Server.HandleRequestSync(player)
    EPR.Server.EnsureLoaded()
    logDebug("[EPR Server] Sending full state sync to " .. player:getUsername())

    local state = {
        PoweredZones = EPR.PoweredZones or {},
        WaterZones = EPR.WaterZones or {},
        Substations = EPR.Substations or {},
        WaterPlants = EPR.WaterPlants or {},
        Generators = EPR.Generators or {},
        WaterTanks = EPR.WaterTanks or {},
        SpriteGenerators = EPR.SpriteGenerators or {},
        ActiveRepairs = EPR.ActiveRepairs or EPR.Server.ActiveRepairs or {},
        ConnectedBuildings = EPR.ConnectedBuildings or (EPR.Buildings and EPR.Buildings.Connected) or {},
        ConnectedStreetLights = EPR.ConnectedStreetLights or (EPR.StreetLights and EPR.StreetLights.Connected) or {},
        PowerController = {
            globalOverride = EPR.PowerController and EPR.PowerController.globalOverride or false,
            louisvilleEverOnline = EPR.PowerController and EPR.PowerController.louisvilleEverOnline or false,
        },
    }

    sendServerCommand(player, "EPR", "FullSync", state)
end

function EPR.Server.BroadcastState()
    local players = getOnlinePlayers()
    if not players then return end

    local state = {
        PoweredZones = EPR.PoweredZones or {},
        WaterZones = EPR.WaterZones or {},
        Substations = EPR.Substations or {},
        WaterPlants = EPR.WaterPlants or {},
        Generators = EPR.Generators or {},
        WaterTanks = EPR.WaterTanks or {},
        SpriteGenerators = EPR.SpriteGenerators or {},
        ActiveRepairs = EPR.ActiveRepairs or EPR.Server.ActiveRepairs or {},
        ConnectedBuildings = EPR.ConnectedBuildings or (EPR.Buildings and EPR.Buildings.Connected) or {},
        ConnectedStreetLights = EPR.ConnectedStreetLights or (EPR.StreetLights and EPR.StreetLights.Connected) or {},
        PowerController = {
            globalOverride = EPR.PowerController and EPR.PowerController.globalOverride or false,
            louisvilleEverOnline = EPR.PowerController and EPR.PowerController.louisvilleEverOnline or false,
        },
    }

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "FullSync", state)
        end
    end

    logDebug("[EPR Server] Broadcast state to " .. players:size() .. " players")
end

function EPR.Server.BroadcastZonePowerChange(zoneName, powered)
    local players = getOnlinePlayers()
    if not players then return end

    local args = {
        zone = zoneName,
        powered = powered,
    }

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "ZonePowerChanged", args)
        end
    end
end

function EPR.Server.BroadcastZoneWaterChange(zoneName, watered)
    local players = getOnlinePlayers()
    if not players then return end

    local args = {
        zone = zoneName,
        watered = watered,
    }

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "ZoneWaterChanged", args)
        end
    end
end

function EPR.Server.BroadcastFacilityUpdate(facilityId, facilityType, state)
    local players = getOnlinePlayers()
    if not players then return end

    local args = {
        facilityId = facilityId,
        facilityType = facilityType,
        state = state,
    }

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "FacilityUpdate", args)
        end
    end
end

-- ============================================
-- REPAIR HANDLERS
-- ============================================

function EPR.Server.HandleStartRepair(player, args)
    if not args or not args.facilityId or not args.componentType then
        print("[EPR Server] Invalid StartRepair args")
        return
    end

    local playerName = player:getUsername()
    local facilityId = args.facilityId
    local componentType = args.componentType

    -- Check if player is already repairing a DIFFERENT component.
    -- Allow re-requesting the same facility/component: each repair stage is a
    -- separate manual action, so continuing to the next stage on the same
    -- component must not be blocked by the lock acquired on the first stage.
    local existing = EPR.Server.ActiveRepairs[playerName]
    if existing and (existing.facilityId ~= facilityId or existing.componentType ~= componentType) then
        sendServerCommand(player, "EPR", "RepairDenied", {
            reason = "Already repairing another component"
        })
        return
    end

    -- Get facility
    local facility = EPR.Zones and EPR.Zones.GetFacility(facilityId)
    if not facility then
        sendServerCommand(player, "EPR", "RepairDenied", {
            reason = "Facility not found"
        })
        return
    end

    -- Check prerequisite
    local canRepair, reason = EPR.Zones.CanRepairFacility(facilityId)
    if not canRepair then
        sendServerCommand(player, "EPR", "RepairDenied", {
            reason = reason
        })
        return
    end

    -- Get facility state
    local state = nil
    if facility.type == "power" or facility.type == "combined" then
        state = EPR.Substations[facilityId]
    elseif facility.type == "water" then
        state = EPR.WaterPlants[facilityId]
    end

    if not state then
        sendServerCommand(player, "EPR", "RepairDenied", {
            reason = "Facility state not found"
        })
        return
    end

    -- Check component exists and is damaged
    local compState = state.components and state.components[componentType]
    if not compState then
        sendServerCommand(player, "EPR", "RepairDenied", {
            reason = "Component not found"
        })
        return
    end

    if compState.status == "functional" or compState.status == "repaired" then
        sendServerCommand(player, "EPR", "RepairDenied", {
            reason = "Component already functional"
        })
        return
    end

    -- Record active repair
    EPR.Server.ActiveRepairs[playerName] = {
        facilityId = facilityId,
        componentType = componentType,
        startTime = getTimestampMs(),
    }
    EPR.ActiveRepairs = EPR.ActiveRepairs or {}
    EPR.ActiveRepairs[playerName] = EPR.Server.ActiveRepairs[playerName]

    -- Update component status
    compState.status = "repairing"
    state.status = "repairing"

    -- Save and broadcast
    EPR.SaveData()
    EPR.Server.BroadcastFacilityUpdate(facilityId, facility.type, state)

    -- Confirm to client
    sendServerCommand(player, "EPR", "RepairStarted", {
        facilityId = facilityId,
        componentType = componentType,
    })

    logDebug("[EPR Server] " .. playerName .. " started repairing " .. componentType .. " at " .. facility.name)
end

function EPR.Server.HandleCancelRepair(player, args)
    local playerName = player:getUsername()

    local activeRepair = EPR.Server.ActiveRepairs[playerName]
    if not activeRepair then
        return
    end

    -- Clear active repair
    EPR.Server.ActiveRepairs[playerName] = nil
    if EPR.ActiveRepairs then
        EPR.ActiveRepairs[playerName] = nil
    end

    logDebug("[EPR Server] " .. playerName .. " cancelled repair")
end

function EPR.Server.BroadcastGlobalOverrideChange(enabled)
    local players = getOnlinePlayers()
    if not players then return end

    local args = {
        enabled = enabled == true,
    }

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "GlobalOverrideChanged", args)
        end
    end
end

function EPR.Server.BroadcastFacilityStartupFlicker(facilityId)
    local players = getOnlinePlayers()
    if not players then return end
    local args = { facilityId = facilityId }
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "FacilityStartupFlicker", args)
        end
    end
end

function EPR.Server.HandleUpdateFacilityState(player, args)
    if not args or not args.facilityId or not args.state then
        print("[EPR Server] Invalid UpdateFacilityState args")
        return
    end

    local accessLevel = ""
    pcall(function()
        accessLevel = player and player:getAccessLevel() or ""
    end)
    local isHost = (isCoopHost and isCoopHost()) == true
    if accessLevel == "" and not isHost then
        print("[EPR Server] UpdateFacilityState rejected - host/admin only")
        return
    end

    local facilityId = args.facilityId
    local state = args.state
    local facility = EPR.Zones and EPR.Zones.GetFacility and EPR.Zones.GetFacility(facilityId)
    local facilityType = (facility and facility.type) or args.facilityType
    local previousState = nil
    if facilityType == "power" or facilityType == "combined" then
        previousState = EPR.Substations and EPR.Substations[facilityId]
    elseif facilityType == "water" then
        previousState = EPR.WaterPlants and EPR.WaterPlants[facilityId]
    end

    if not facilityType then
        print("[EPR Server] UpdateFacilityState missing facility type for " .. tostring(facilityId))
        return
    end

    if state.discovered == nil then
        state.discovered = true
    end

    if facilityType == "power" or facilityType == "combined" then
        EPR.Substations[facilityId] = state
    end
    if facilityType == "water" or facilityType == "combined" then
        EPR.WaterPlants[facilityId] = state
    end

    if facilityType == "power" or facilityType == "combined" then
        local prevStatus = previousState and previousState.status
        local nextStatus = state and state.status
        if prevStatus ~= nextStatus then
            if nextStatus == "online" and EPR.PowerController and EPR.PowerController.OnFacilityOnline then
                EPR.PowerController.OnFacilityOnline(facilityId)
            elseif prevStatus == "online" and EPR.PowerController and EPR.PowerController.OnFacilityOffline then
                EPR.PowerController.OnFacilityOffline(facilityId)
            end
        end
    end

    EPR.SaveData()
    EPR.Server.BroadcastFacilityUpdate(facilityId, facilityType, state)
end

function EPR.Server.HandleCompleteStage(player, args)
    if not args or not args.facilityId or not args.componentType or not args.stageName then
        print("[EPR Server] Invalid CompleteStage args")
        return
    end

    local playerName = player:getUsername()
    local facilityId = args.facilityId
    local componentType = args.componentType
    local stageName = args.stageName

    -- Verify player was repairing this
    local activeRepair = EPR.Server.ActiveRepairs[playerName]
    if not activeRepair or activeRepair.facilityId ~= facilityId or activeRepair.componentType ~= componentType then
        print("[EPR Server] CompleteStage mismatch for " .. playerName)
        return
    end

    -- Get facility and state
    local facility = EPR.Zones and EPR.Zones.GetFacility(facilityId)
    if not facility then return end

    local state = nil
    if facility.type == "power" or facility.type == "combined" then
        state = EPR.Substations[facilityId]
    elseif facility.type == "water" then
        state = EPR.WaterPlants[facilityId]
    end

    if not state or not state.components then return end

    local compState = state.components[componentType]
    if not compState then return end

    -- Mark stage complete
    if not compState.stagesCompleted then
        compState.stagesCompleted = {}
    end
    compState.stagesCompleted[stageName] = true
    compState.stageProgress = 0

    -- Determine next stage
    local stageOrder = {"Assessment", "PartReplacement", "Calibration", "Startup"}
    local nextStage = nil
    for _, stage in ipairs(stageOrder) do
        if not compState.stagesCompleted[stage] then
            nextStage = stage
            break
        end
    end

    -- A stage's timed action has finished; no action is running for this player
    -- right now. Release the per-player lock so the next manual stage click (or
    -- a different component) can re-acquire it cleanly. Without this, the lock
    -- acquired on the first stage blocks every subsequent stage/component
    -- ("already repairing another part") until a server restart.
    EPR.Server.ActiveRepairs[playerName] = nil
    if EPR.ActiveRepairs then
        EPR.ActiveRepairs[playerName] = nil
    end

    if nextStage then
        compState.currentStage = nextStage
    else
        -- Component fully repaired
        compState.status = "repaired"
        compState.currentStage = nil

        -- Check if all components are now repaired
        local allRepaired = true
        if state.components then
            for _, cs in pairs(state.components) do
                if cs.status ~= "functional" and cs.status ~= "repaired" then
                    allRepaired = false
                    break
                end
            end
        end

        -- If all components are repaired, set facility to "ready" state
        if allRepaired then
            state.status = "ready"
            print("[EPR Server] All components repaired - facility " .. facilityId .. " is now READY for startup")
        end
    end

    -- Save and broadcast
    EPR.SaveData()
    EPR.Server.BroadcastFacilityUpdate(facilityId, facility.type, state)

    -- Notify client
    sendServerCommand(player, "EPR", "StageCompleted", {
        facilityId = facilityId,
        componentType = componentType,
        stageName = stageName,
        nextStage = nextStage,
    })

    print("[EPR Server] " .. playerName .. " completed " .. stageName .. " on " .. componentType)
end

function EPR.Server.HandleStageProgress(player, args)
    if not args or not args.facilityId or not args.componentType or not args.stageName then
        return
    end

    local playerName = player:getUsername()
    local activeRepair = EPR.Server.ActiveRepairs[playerName]
    if not activeRepair or activeRepair.facilityId ~= args.facilityId or activeRepair.componentType ~= args.componentType then
        return
    end

    local facility = EPR.Zones and EPR.Zones.GetFacility(args.facilityId)
    if not facility then return end

    local state = nil
    if facility.type == "power" or facility.type == "combined" then
        state = EPR.Substations[args.facilityId]
    elseif facility.type == "water" then
        state = EPR.WaterPlants[args.facilityId]
    end
    if not state or not state.components then return end

    local compState = state.components[args.componentType]
    if not compState then return end

    local progress = tonumber(args.progress) or 0
    progress = math.max(0, math.min(100, progress))

    compState.status = "repairing"
    compState.currentStage = args.stageName
    compState.stageProgress = math.max(compState.stageProgress or 0, progress)
    state.status = "repairing"

    -- Attract zombies during repair work, rate-limited to once per minute per facility
    local now = getTimestampMs()
    if now - (lastNoiseTime[args.facilityId] or 0) >= 60000 then
        lastNoiseTime[args.facilityId] = now
        local radius = (SandboxVars and SandboxVars.EPR and SandboxVars.EPR.RepairNoiseRadius) or EPR.Config.RepairNoiseRadius
        attractZombies(facility.x or 0, facility.y or 0, facility.z or 0, radius)
    end

    EPR.Server.BroadcastFacilityUpdate(args.facilityId, facility.type, state)
end

function EPR.Server.HandleFacilityOnline(player, args)
    if not args or not args.facilityId then
        print("[EPR Server] Invalid FacilityOnline args")
        return
    end

    local facilityId = args.facilityId

    -- Get facility
    local facility = EPR.Zones and EPR.Zones.GetFacility(facilityId)
    if not facility then return end

    -- Get state
    local state = nil
    if facility.type == "power" or facility.type == "combined" then
        state = EPR.Substations[facilityId]
    elseif facility.type == "water" then
        state = EPR.WaterPlants[facilityId]
    end

    if not state then return end

    -- Check facility is in "ready" state (all components repaired, waiting for startup)
    if state.status ~= "ready" and state.status ~= "starting" then
        -- Fallback: check all components repaired
        local allRepaired = true
        if state.components then
            for _, compState in pairs(state.components) do
                if compState.status ~= "functional" and compState.status ~= "repaired" then
                    allRepaired = false
                    break
                end
            end
        end

        if not allRepaired then
            print("[EPR Server] Cannot bring online - not all components repaired")
            return
        end
    end

    -- Bring online
    state.status = "online"
    state.health = 100
    local _gto = getGameTime and getGameTime()
    state.lastMaintenance = _gto and _gto:getWorldAgeHours() or 0

    if EPR.PowerController and EPR.PowerController.OnFacilityOnline then
        EPR.PowerController.OnFacilityOnline(facilityId)
    end

    -- Trigger IB flicker on all clients as a cosmetic startup effect
    EPR.Server.BroadcastFacilityStartupFlicker(facilityId)

    -- Startup is very loud — attract zombies in a wide radius
    local startupRadius = (SandboxVars and SandboxVars.EPR and SandboxVars.EPR.StartupNoiseRadius) or EPR.Config.StartupNoiseRadius
    attractZombies(facility.x or 0, facility.y or 0, facility.z or 0, startupRadius)

    -- Activate zones
    if facility.powersZones then
        for _, zoneName in ipairs(facility.powersZones) do
            EPR.PoweredZones[zoneName] = true
            if EPR.Buildings and EPR.Buildings.ApplyZonePower then
                EPR.Buildings.ApplyZonePower(zoneName, true)
            end
            EPR.Server.BroadcastZonePowerChange(zoneName, true)
        end
    end

    if facility.watersZones then
        for _, zoneName in ipairs(facility.watersZones) do
            EPR.WaterZones[zoneName] = true
            if EPR.Buildings and EPR.Buildings.ApplyZoneWater then
                EPR.Buildings.ApplyZoneWater(zoneName, true)
            end
            EPR.Server.BroadcastZoneWaterChange(zoneName, true)
        end
    end

    -- Update zone status
    if EPR.Zones and EPR.Zones.UpdateZoneStatus then
        EPR.Zones.UpdateZoneStatus()
    end

    -- Save and broadcast
    EPR.SaveData()
    EPR.Server.BroadcastFacilityUpdate(facilityId, facility.type, state)

    logDebug("[EPR Server] Facility online: " .. facility.name)
end

-- ============================================
-- ADMIN HANDLERS
-- ============================================

function EPR.Server.HandleAdminSetPower(player, args)
    -- Check if player is admin
    if not player:getAccessLevel() or player:getAccessLevel() == "" then
        print("[EPR Server] Non-admin tried to set power: " .. player:getUsername())
        return
    end

    if not args or not args.zone then return end

    local zoneName = args.zone
    local powered = args.powered == true

    EPR.PoweredZones[zoneName] = powered
    if EPR.Buildings and EPR.Buildings.ApplyZonePower then
        EPR.Buildings.ApplyZonePower(zoneName, powered)
    end

    if EPR.Zones and EPR.Zones.UpdateZoneStatus then
        EPR.Zones.UpdateZoneStatus()
    end

    EPR.SaveData()
    EPR.Server.BroadcastZonePowerChange(zoneName, powered)

    logDebug("[EPR Server] Admin " .. player:getUsername() .. " set " .. zoneName .. " power to " .. tostring(powered))
end

function EPR.Server.HandleAdminSetWater(player, args)
    -- Check if player is admin
    if not player:getAccessLevel() or player:getAccessLevel() == "" then
        print("[EPR Server] Non-admin tried to set water: " .. player:getUsername())
        return
    end

    if not args or not args.zone then return end

    local zoneName = args.zone
    local watered = args.watered == true

    EPR.WaterZones[zoneName] = watered
    if EPR.Buildings and EPR.Buildings.ApplyZoneWater then
        EPR.Buildings.ApplyZoneWater(zoneName, watered)
    end

    if EPR.Zones and EPR.Zones.UpdateZoneStatus then
        EPR.Zones.UpdateZoneStatus()
    end

    EPR.SaveData()
    EPR.Server.BroadcastZoneWaterChange(zoneName, watered)

    logDebug("[EPR Server] Admin " .. player:getUsername() .. " set " .. zoneName .. " water to " .. tostring(watered))
end

-- ============================================
-- BUILDING GRID HANDLERS
-- ============================================

function EPR.Server.SendBuildingUpdate(buildingKey, record, removed)
    local players = getOnlinePlayers()
    if not players then return end

    local args = {
        buildingKey = buildingKey,
        record = record,
        removed = removed == true,
    }

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "BuildingUpdate", args)
        end
    end
end

local function sendStreetLightUpdate(lightKey, record, removed)
    local players = getOnlinePlayers()
    if not players then return end

    local args = {
        lightKey = lightKey,
        record = record,
        removed = removed == true,
    }

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "StreetLightUpdate", args)
        end
    end
end

local function sendSpriteGeneratorUpdate(genKey, record, removed)
    local players = getOnlinePlayers()
    if not players then return end

    local args = {
        key = genKey,
        record = record,
        removed = removed == true,
    }

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            sendServerCommand(player, "EPR", "SpriteGeneratorUpdate", args)
        end
    end
end

function EPR.Server.SendSpriteGeneratorUpdate(genKey, record, removed)
    sendSpriteGeneratorUpdate(genKey, record, removed)
end

local function findSpriteGeneratorObject(square)
    if not square or not square.getObjects then return nil end
    local objects = square:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getSprite then
            local sprite = obj:getSprite()
            local name = sprite and sprite:getName()
            if EPR.Buildings and EPR.Buildings.IsSpriteGeneratorSprite and EPR.Buildings.IsSpriteGeneratorSprite(name) then
                return obj, name
            end
        end
    end
    return nil, nil
end

function EPR.Server.HandleConnectBuilding(player, args)
    if not args or args.x == nil or args.y == nil then
        return
    end

    if not EPR.Buildings.PlayerHasElectricalSkill(player, 3) then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Electrical skill 3 required" })
        return
    end

    local square = getSquare(args.x, args.y, args.z or 0)
    local building = square and square:getBuilding()
    if not building then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "No building found" })
        return
    end

    local zoneName = args.zone or (EPR.Zones and EPR.Zones.GetZoneAt and EPR.Zones.GetZoneAt(args.x, args.y))
    local ok, reason = EPR.Buildings.CanConnectZone(zoneName)
    if not ok then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = reason or "Zone is offline" })
        return
    end

    local key, err = EPR.Buildings.ConnectBuilding(building, square, zoneName)
    if not key then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = err or "Unable to connect" })
        return
    end

    EPR.SaveData()
    EPR.Server.SendBuildingUpdate(key, EPR.Buildings.GetBuildingRecord(key), false)
end

function EPR.Server.HandleDisconnectBuilding(player, args)
    if not args or not args.buildingKey then return end

    local removed = EPR.Buildings.DisconnectBuilding(args.buildingKey)
    if removed then
        EPR.SaveData()
        EPR.Server.SendBuildingUpdate(args.buildingKey, nil, true)
    end
end

function EPR.Server.HandleConnectAllBuildings(player, args)
    if not args or not args.zone then return end

    local accessLevel = ""
    pcall(function()
        accessLevel = player and player:getAccessLevel() or ""
    end)
    local isHost = (isCoopHost and isCoopHost()) == true
    if accessLevel == "" and not isHost then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Admin only" })
        return
    end

    local zoneName = args.zone
    local ok, reason = EPR.Buildings.CanConnectZone(zoneName)
    if not ok then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = reason or "Zone is offline" })
        return
    end

    local zoneDef = EPR.Zones and EPR.Zones.Definitions and EPR.Zones.Definitions[zoneName]
    if not zoneDef or not zoneDef.bounds then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Zone not found" })
        return
    end

    local meta = getWorld() and getWorld():getMetaGrid()
    if not meta or not meta.getBuildings then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Building list unavailable" })
        return
    end

    local buildings = meta:getBuildings()
    if not buildings then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Building list empty" })
        return
    end

    local cap = (EPR.Config and EPR.Config.ZoneBuildingCapMP) or 0
    local connected = 0

    for i = 0, buildings:size() - 1 do
        local b = buildings:get(i)
        local def = b and b.getDef and b:getDef()
        if def and def.getX and def.getY and def.getW and def.getH then
            local bx = def:getX() + math.floor(def:getW() / 2)
            local by = def:getY() + math.floor(def:getH() / 2)
            if bx >= zoneDef.bounds[1] and bx <= zoneDef.bounds[3] and by >= zoneDef.bounds[2] and by <= zoneDef.bounds[4] then
                if cap > 0 and EPR.Buildings.GetZoneCount(zoneName) >= cap then
                    break
                end
                local square = getSquare(bx, by, 0)
                if square then
                    local key = EPR.Buildings.GetBuildingKey(b, square)
                    if key and not EPR.Buildings.IsBuildingConnected(key) then
                        local newKey = EPR.Buildings.ConnectBuilding(b, square, zoneName)
                        if newKey then
                            connected = connected + 1
                        end
                    end
                end
            end
        end
    end

    if connected > 0 then
        EPR.SaveData()
        -- Broadcast full sync to avoid flooding updates
        EPR.Server.BroadcastState()
    end
end

function EPR.Server.HandleConnectStreetLight(player, args)
    if not args or args.x == nil or args.y == nil then return end

    local zoneName = args.zone or (EPR.Zones and EPR.Zones.GetZoneAt and EPR.Zones.GetZoneAt(args.x, args.y))
    if not zoneName or not (EPR.PoweredZones and EPR.PoweredZones[zoneName] == true) then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Zone power is offline" })
        return
    end

    local square = getSquare(args.x, args.y, args.z or 0)
    if not square then return end
    local key, err = EPR.StreetLights.Connect(square, zoneName)
    if not key then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = err or "Unable to connect light" })
        return
    end

    EPR.SaveData()
    sendStreetLightUpdate(key, EPR.StreetLights.Connected[key], false)
end

function EPR.Server.HandleDisconnectStreetLight(player, args)
    if not args or not args.lightKey then return end

    local removed = EPR.StreetLights.Disconnect(args.lightKey)
    if removed then
        EPR.SaveData()
        sendStreetLightUpdate(args.lightKey, nil, true)
    end
end

function EPR.Server.HandleMaintainBuilding(player, args)
    if not args or not args.buildingKey then return end

    if not EPR.Buildings.PlayerHasElectricalSkill(player, 3) then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Electrical skill 3 required" })
        return
    end

    local record = EPR.Buildings.GetBuildingRecord(args.buildingKey)
    if not record then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Building not connected" })
        return
    end

    local ok = EPR.Buildings.CanMaintain(player)
    if not ok then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Missing maintenance items" })
        return
    end

    if not EPR.Buildings.ConsumeMaintenanceItems(player) then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Unable to consume items" })
        return
    end

    record.lastMaintenanceHours = getGameTime() and getGameTime():getWorldAgeHours() or 0
    record.maintenanceStatus = "ok"
    EPR.Buildings.ApplyBuildingRecord(record)
    EPR.SaveData()
    EPR.Server.SendBuildingUpdate(args.buildingKey, record, false)
end

function EPR.Server.HandleSetBuildingGeneratorRadius(player, args)
    if not args or not args.buildingKey or not args.radius then return end

    local record = EPR.Buildings.GetBuildingRecord(args.buildingKey)
    if not record then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Building not connected" })
        return
    end

    local ok = EPR.Buildings.SetGeneratorRadius(args.buildingKey, args.radius)
    if ok then
        EPR.SaveData()
        EPR.Server.SendBuildingUpdate(args.buildingKey, record, false)
    end
end

function EPR.Server.HandleHookSpriteGenerator(player, args)
    if not args or args.x == nil or args.y == nil then return end

    if not (EPR.Buildings and EPR.Buildings.PlayerHasSpriteGeneratorSkill and EPR.Buildings.PlayerHasSpriteGeneratorSkill(player)) then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Electrical skill 3 required" })
        return
    end
    if not (EPR.Buildings and EPR.Buildings.PlayerHasSpriteGeneratorTools and EPR.Buildings.PlayerHasSpriteGeneratorTools(player)) then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "Missing required tools" })
        return
    end

    local square = getSquare(args.x, args.y, args.z or 0)
    if not square then return end

    local obj, spriteName = findSpriteGeneratorObject(square)
    if not obj or not spriteName then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = "No generator sprite found" })
        return
    end

    local record, err = EPR.Buildings.HookSpriteGenerator(square, spriteName)
    if not record then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = err or "Unable to hook generator" })
        return
    end

    EPR.SaveData()
    sendSpriteGeneratorUpdate(record.key, record, false)
end

function EPR.Server.HandleToggleSpriteGenerator(player, args)
    if not args or not args.key then return end

    local record, err = EPR.Buildings.ToggleSpriteGenerator(args.key, args.active == true)
    if not record then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = err or "Unable to toggle generator" })
        return
    end

    EPR.SaveData()
    sendSpriteGeneratorUpdate(record.key, record, false)
end

local function findPetrolItem(player)
    if not player or not player.getInventory then return nil end
    local inv = player:getInventory()
    if not inv or not inv.getAllEvalRecurse then return nil end
    local items = inv:getAllEvalRecurse(function(item)
        local fc = item and item.getFluidContainer and item:getFluidContainer() or nil
        if not fc or not fc.contains then return false end
        return fc:contains(Fluid.Petrol) and fc:getAmount() > 0
    end)
    if not items or items:isEmpty() then return nil end
    return items:get(0)
end

function EPR.Server.HandleSpriteGeneratorRefuel(player, args)
    if not args or not args.key then return end
    local record = EPR.SpriteGenerators and EPR.SpriteGenerators[args.key]
    if not record then return end
    local ok, reason = EPR.Buildings.SimulateSpriteGeneratorRefuel(player, record)
    if not ok then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = reason or "Unable to refuel" })
        return
    end
    EPR.Buildings.ApplySpriteGeneratorRecord(record)
    EPR.SaveData()
    sendSpriteGeneratorUpdate(record.key, record, false)
end

function EPR.Server.HandleSpriteGeneratorMaintain(player, args)
    if not args or not args.key then return end
    local record = EPR.SpriteGenerators and EPR.SpriteGenerators[args.key]
    if not record then return end
    local ok, reason = EPR.Buildings.SimulateSpriteGeneratorMaintain(player, record)
    if not ok then
        sendServerCommand(player, "EPR", "BuildingDenied", { reason = reason or "Unable to maintain" })
        return
    end
    EPR.Buildings.ApplySpriteGeneratorRecord(record)
    EPR.SaveData()
    sendSpriteGeneratorUpdate(record.key, record, false)
end

-- ============================================
-- MAINTENANCE & DEGRADATION
-- ============================================

EPR.Maintenance = EPR.Maintenance or {}

function EPR.Maintenance.UpdateAll()
    if not EPR.IsServerContext or not EPR.IsServerContext() then return end
    local rate = (SandboxVars and SandboxVars.EPR and SandboxVars.EPR.DegradationRate) or 1.0
    -- Per-hour loss derived from BaseDegradationPerDay config value
    local hourlyLoss = (EPR.Config.BaseDegradationPerDay / 24) * rate

    local changed = false
    for id, state in pairs(EPR.Substations or {}) do
        if state.status == "online" then
            state.health = math.max(0, (state.health or 100) - hourlyLoss)
            changed = true
            logDebug("[EPR Maint] Substation " .. id .. " health: " .. string.format("%.1f", state.health))
        end
    end
    for id, state in pairs(EPR.WaterPlants or {}) do
        if state.status == "online" then
            state.health = math.max(0, (state.health or 100) - hourlyLoss)
            changed = true
            logDebug("[EPR Maint] WaterPlant " .. id .. " health: " .. string.format("%.1f", state.health))
        end
    end
    if changed then EPR.SaveData() end
end

function EPR.Maintenance.CheckBreakdowns()
    if not EPR.IsServerContext or not EPR.IsServerContext() then return end
    if not (SandboxVars and SandboxVars.EPR and SandboxVars.EPR.RandomBreakdownEnabled) then return end

    local threshold = EPR.Config.BreakdownThreshold

    for id, state in pairs(EPR.Substations or {}) do
        if state.status == "online" and (state.health or 100) < threshold then
            local chance = (threshold - (state.health or 0)) / threshold * 20
            if ZombRand(100) < chance then
                print("[EPR Maint] Random breakdown triggered for substation: " .. id)
                EPR.Maintenance.TriggerBreakdown(id, state, "power")
            end
        end
    end
    for id, state in pairs(EPR.WaterPlants or {}) do
        if state.status == "online" and (state.health or 100) < threshold then
            local chance = (threshold - (state.health or 0)) / threshold * 20
            if ZombRand(100) < chance then
                print("[EPR Maint] Random breakdown triggered for water plant: " .. id)
                EPR.Maintenance.TriggerBreakdown(id, state, "water")
            end
        end
    end
end

function EPR.Maintenance.TriggerBreakdown(facilityId, state, facilityType)
    print("[EPR Maint] BREAKDOWN: " .. facilityId)
    state.status = "offline"
    state.health = 0

    -- Reset all components back to damaged
    if state.components then
        for _, compState in pairs(state.components) do
            if compState.status == "functional" or compState.status == "repaired" then
                compState.status = "damaged"
                compState.stagesCompleted = {}
                compState.currentStage = "Assessment"
                compState.stageProgress = 0
            end
        end
    end

    local facility = EPR.Zones and EPR.Zones.GetFacility and EPR.Zones.GetFacility(facilityId)
    if not facility then
        EPR.SaveData()
        return
    end

    if facility.powersZones then
        for _, zoneName in ipairs(facility.powersZones) do
            EPR.PoweredZones[zoneName] = false
            if EPR.Buildings and EPR.Buildings.ApplyZonePower then
                EPR.Buildings.ApplyZonePower(zoneName, false)
            end
            EPR.Server.BroadcastZonePowerChange(zoneName, false)
        end
    end

    if facility.watersZones then
        for _, zoneName in ipairs(facility.watersZones) do
            EPR.WaterZones[zoneName] = false
            if EPR.Buildings and EPR.Buildings.ApplyZoneWater then
                EPR.Buildings.ApplyZoneWater(zoneName, false)
            end
            EPR.Server.BroadcastZoneWaterChange(zoneName, false)
        end
    end

    if EPR.PowerController and EPR.PowerController.OnFacilityOffline then
        EPR.PowerController.OnFacilityOffline(facilityId)
    end

    if EPR.Zones and EPR.Zones.UpdateZoneStatus then
        EPR.Zones.UpdateZoneStatus()
    end

    EPR.SaveData()
    EPR.Server.BroadcastFacilityUpdate(facilityId, facilityType, state)
end

-- ============================================
-- DEBUG HANDLERS (Require debug mode enabled)
-- ============================================

function EPR.Server.HandleDebugRepairAll(player, args)
    -- Check debug mode is enabled
    if not EPR.IsDebugMode or not EPR.IsDebugMode() then
        print("[EPR Server] Debug command rejected - debug mode not enabled")
        return
    end

    if not args or not args.facilityId then return end

    local facilityId = args.facilityId
    print("[EPR Server] DEBUG: Repairing all components for " .. facilityId)

    -- Get facility
    local facility = EPR.Zones and EPR.Zones.GetFacility(facilityId)
    if not facility then
        print("[EPR Server] Facility not found: " .. facilityId)
        return
    end

    -- Get state
    local state = nil
    if facility.type == "power" or facility.type == "combined" then
        state = EPR.Substations[facilityId]
    elseif facility.type == "water" then
        state = EPR.WaterPlants[facilityId]
    end

    if not state then
        print("[EPR Server] No state for facility: " .. facilityId)
        return
    end

    -- Repair all components
    if state.components then
        for compType, compState in pairs(state.components) do
            compState.status = "repaired"
            compState.progress = 100
            compState.currentStage = nil
            compState.stageProgress = nil
            compState.stagesCompleted = { Assessment = true, PartReplacement = true, Calibration = true, Startup = true }
        end
    end

    state.status = "ready"
    state.health = 100

    -- Save and broadcast
    EPR.SaveData()
    EPR.Server.BroadcastFacilityUpdate(facilityId, facility.type, state)

    print("[EPR Server] DEBUG: All components repaired for " .. facilityId)
end

function EPR.Server.HandleDebugActivate(player, args)
    -- Check debug mode is enabled
    if not EPR.IsDebugMode or not EPR.IsDebugMode() then
        print("[EPR Server] Debug command rejected - debug mode not enabled")
        return
    end

    if not args or not args.facilityId then return end

    local facilityId = args.facilityId
    print("[EPR Server] DEBUG: Activating facility " .. facilityId)

    -- First repair all
    EPR.Server.HandleDebugRepairAll(player, args)

    -- Get facility
    local facility = EPR.Zones and EPR.Zones.GetFacility(facilityId)
    if not facility then return end

    -- Get state
    local state = nil
    if facility.type == "power" or facility.type == "combined" then
        state = EPR.Substations[facilityId]
    elseif facility.type == "water" then
        state = EPR.WaterPlants[facilityId]
    end

    if not state then return end

    -- Activate
    state.status = "online"
    state.health = 100
    local _gtd = getGameTime and getGameTime()
    state.lastMaintenance = _gtd and _gtd:getWorldAgeHours() or 0

    -- Activate zones
    if facility.powersZones then
        for _, zoneName in ipairs(facility.powersZones) do
            EPR.PoweredZones[zoneName] = true
            EPR.Server.BroadcastZonePowerChange(zoneName, true)
        end
    end

    if facility.watersZones then
        for _, zoneName in ipairs(facility.watersZones) do
            EPR.WaterZones[zoneName] = true
            EPR.Server.BroadcastZoneWaterChange(zoneName, true)
        end
    end

    -- Update networks
    if EPR.PowerController and EPR.PowerController.UpdateNetworks then
        EPR.PowerController.UpdateNetworks()
    end

    -- Save and broadcast
    EPR.SaveData()
    EPR.Server.BroadcastFacilityUpdate(facilityId, facility.type, state)

    print("[EPR Server] DEBUG: Facility " .. facilityId .. " activated!")
end

function EPR.Server.HandleDebugDeactivate(player, args)
    -- Check debug mode is enabled
    if not EPR.IsDebugMode or not EPR.IsDebugMode() then
        print("[EPR Server] Debug command rejected - debug mode not enabled")
        return
    end

    if not args or not args.facilityId then return end

    local facilityId = args.facilityId
    print("[EPR Server] DEBUG: Deactivating facility " .. facilityId)

    -- Get facility
    local facility = EPR.Zones and EPR.Zones.GetFacility(facilityId)
    if not facility then return end

    -- Get state
    local state = nil
    if facility.type == "power" or facility.type == "combined" then
        state = EPR.Substations[facilityId]
    elseif facility.type == "water" then
        state = EPR.WaterPlants[facilityId]
    end

    if not state then return end

    -- Deactivate
    state.status = "offline"
    state.health = 0

    -- Reset all components
    if state.components then
        for compType, compState in pairs(state.components) do
            compState.status = "damaged"
            compState.progress = 0
            compState.stagesCompleted = {}
            compState.currentStage = "Assessment"
            compState.stageProgress = 0
        end
    end

    -- Deactivate zones
    if facility.powersZones then
        for _, zoneName in ipairs(facility.powersZones) do
            EPR.PoweredZones[zoneName] = false
            if EPR.Buildings and EPR.Buildings.ApplyZonePower then
                EPR.Buildings.ApplyZonePower(zoneName, false)
            end
            EPR.Server.BroadcastZonePowerChange(zoneName, false)
        end
    end

    if facility.watersZones then
        for _, zoneName in ipairs(facility.watersZones) do
            EPR.WaterZones[zoneName] = false
            if EPR.Buildings and EPR.Buildings.ApplyZoneWater then
                EPR.Buildings.ApplyZoneWater(zoneName, false)
            end
            EPR.Server.BroadcastZoneWaterChange(zoneName, false)
        end
    end

    -- Update networks
    if EPR.PowerController and EPR.PowerController.UpdateNetworks then
        EPR.PowerController.UpdateNetworks()
    end

    -- Save and broadcast
    EPR.SaveData()
    EPR.Server.BroadcastFacilityUpdate(facilityId, facility.type, state)

    logDebug("[EPR Server] DEBUG: Facility " .. facilityId .. " deactivated!")
end

-- ============================================
-- PERIODIC STATE BROADCAST
-- ============================================

local broadcastTicker = 0
local BROADCAST_INTERVAL = 600  -- Every 10 seconds (600 ticks at 60/s)

function EPR.Server.OnTick()
    broadcastTicker = broadcastTicker + 1

    if broadcastTicker >= BROADCAST_INTERVAL then
        broadcastTicker = 0
        -- Periodic sync to catch any missed updates
        -- Only broadcast if there are online players
        local players = getOnlinePlayers()
        if players and players:size() > 0 then
            -- Don't spam full syncs, just a heartbeat
            -- Full sync on player join is handled via RequestSync
        end
    end
end

-- ============================================
-- PLAYER CONNECT/DISCONNECT
-- ============================================

function EPR.Server.OnPlayerConnect(player)
    EPR.Server.EnsureLoaded()
    logDebug("[EPR Server] Player connected: " .. player:getUsername())

    -- Send initial state sync after short delay to ensure client is ready
    -- Schedule sync after 2 seconds (60 ticks)
    local playerRef = player
    local tickCount = 0
    local syncHandler
    syncHandler = function()
        tickCount = tickCount + 1
        if tickCount >= 60 then  -- ~2 seconds delay
            Events.OnTick.Remove(syncHandler)
            if playerRef and playerRef:isAlive() then
                logDebug("[EPR Server] Sending initial sync to " .. playerRef:getUsername())
                EPR.Server.HandleRequestSync(playerRef)
            end
        end
    end
    Events.OnTick.Add(syncHandler)
end

function EPR.Server.OnPlayerDisconnect(player)
    local playerName = player:getUsername()
    logDebug("[EPR Server] Player disconnected: " .. playerName)

    -- Clear any active repairs for this player
    if EPR.Server.ActiveRepairs[playerName] then
        EPR.Server.ActiveRepairs[playerName] = nil
        if EPR.ActiveRepairs then
            EPR.ActiveRepairs[playerName] = nil
        end
        logDebug("[EPR Server] Cleared active repair for " .. playerName)
    end

    -- CRITICAL: Save data immediately on player disconnect
    -- This ensures state is persisted even if this is the last player
    if EPR.SaveData then
        logDebug("[EPR Server] Saving data on player disconnect...")
        EPR.SaveData()
    end

    -- Check if this was the last player
    local players = getOnlinePlayers()
    local remainingCount = players and players:size() or 0
    -- Note: The disconnecting player might still be in the list, so check for <= 1
    if remainingCount <= 1 then
        logDebug("[EPR Server] Last player disconnecting - ensuring data is saved!")
        -- Double-save to be sure
        if EPR.SaveData then
            EPR.SaveData()
        end
    end
end

-- ============================================
-- EVENT REGISTRATION
-- ============================================

if Events then
    if Events.OnInitGlobalModData then
        Events.OnInitGlobalModData.Add(function()
            EPR.Server.loaded = false
            EPR.Server.EnsureLoaded()
        end)
    end

    Events.OnClientCommand.Add(EPR.Server.OnClientCommand)
    Events.OnTick.Add(EPR.Server.OnTick)

    if Events.OnPlayerConnect then
        Events.OnPlayerConnect.Add(EPR.Server.OnPlayerConnect)
    elseif Events.OnClientConnect then
        Events.OnClientConnect.Add(EPR.Server.OnPlayerConnect)
    elseif Events.OnConnected then
        Events.OnConnected.Add(EPR.Server.OnPlayerConnect)
    end

    if Events.OnPlayerDisconnect then
        Events.OnPlayerDisconnect.Add(EPR.Server.OnPlayerDisconnect)
    elseif Events.OnClientDisconnect then
        Events.OnClientDisconnect.Add(EPR.Server.OnPlayerDisconnect)
    elseif Events.OnDisconnect then
        Events.OnDisconnect.Add(EPR.Server.OnPlayerDisconnect)
    end

    logDebug("[EPR Server] Server events registered")
else
    print("[EPR Server] ERROR: Events not available!")
end

logDebug("[EPR Server] EPR_Server.lua loaded successfully")
