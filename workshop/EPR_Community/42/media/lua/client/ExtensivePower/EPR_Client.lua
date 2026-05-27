--[[
    Extensive Power Rework - Client Networking Layer

    Handles client-side networking for MP synchronization:
    - Detects SP vs MP mode
    - Sends commands to server in MP
    - Receives and applies state updates from server
    - Falls back to direct calls in SP mode

    In Single Player:
    - All operations happen locally
    - State is saved/loaded via ModData

    In Multiplayer:
    - Client sends requests to server
    - Server validates and broadcasts state changes
    - Client applies received state updates
]]--

-- Only run on client
if isServer() and not isClient() then return end

local function logDebug(message)
    if EPR and EPR.IsDebugMode and EPR.IsDebugMode() then
        print(message)
    end
end

logDebug("[EPR Client] EPR_Client.lua loading...")

EPR = EPR or {}
EPR.Client = {}

-- Track if we've done initial sync
EPR.Client.syncCompleted = false

-- ============================================
-- MP DETECTION
-- ============================================

function EPR.Client.IsMultiplayer()
    -- Host/dedicated server runs with isServer() true.
    if isServer() then
        return true
    end

    -- Pure client: only treat as MP when connected to a server.
    if isClient() then
        if getServerOptions and getServerOptions() then
            return true
        end
    end

    return false
end

function EPR.Client.IsSinglePlayer()
    return not EPR.Client.IsMultiplayer()
end

-- ============================================
-- COMMAND SENDING
-- ============================================

function EPR.Client.SendCommand(command, args)
    if EPR.Client.IsSinglePlayer() then
        -- In SP, commands are handled locally
        logDebug("[EPR Client] SP mode - command '" .. command .. "' handled locally")
        return
    end

    local player = getPlayer()
    if not player then
        logDebug("[EPR Client] No player for command")
        return
    end

    sendClientCommand(player, "EPR", command, args or {})
    logDebug("[EPR Client] Sent command: " .. command)
end

-- ============================================
-- REPAIR COMMANDS
-- ============================================

function EPR.Client.RequestRepair(facilityId, componentType)
    if EPR.Client.IsSinglePlayer() then
        -- In SP, use existing repair system directly
        return nil  -- Let existing code handle it
    end

    EPR.Client.SendCommand("StartRepair", {
        facilityId = facilityId,
        componentType = componentType,
    })

    return true  -- Indicates MP handling
end

function EPR.Client.CancelRepair()
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("CancelRepair", {})
    return true
end

function EPR.Client.NotifyStageComplete(facilityId, componentType, stageName)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("CompleteStage", {
        facilityId = facilityId,
        componentType = componentType,
        stageName = stageName,
    })
end

function EPR.Client.NotifyStageProgress(facilityId, componentType, stageName, progress)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("StageProgress", {
        facilityId = facilityId,
        componentType = componentType,
        stageName = stageName,
        progress = progress,
    })
end

function EPR.Client.NotifyFacilityOnline(facilityId)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("FacilityOnline", {
        facilityId = facilityId,
    })
end

function EPR.Client.RequestConnectBuilding(x, y, z, zoneName)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("ConnectBuilding", {
        x = x,
        y = y,
        z = z or 0,
        zone = zoneName,
    })
end

function EPR.Client.RequestDisconnectBuilding(buildingKey)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("DisconnectBuilding", {
        buildingKey = buildingKey,
    })
end

function EPR.Client.RequestConnectAllBuildings(zoneName)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("ConnectAllBuildings", {
        zone = zoneName,
    })
end

function EPR.Client.RequestConnectStreetLight(x, y, z, zoneName)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("ConnectStreetLight", {
        x = x,
        y = y,
        z = z or 0,
        zone = zoneName,
    })
end

function EPR.Client.RequestDisconnectStreetLight(lightKey)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("DisconnectStreetLight", {
        lightKey = lightKey,
    })
end

function EPR.Client.RequestMaintainBuilding(buildingKey)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("MaintainBuilding", {
        buildingKey = buildingKey,
    })
end

function EPR.Client.RequestSetBuildingGeneratorRadius(buildingKey, radius)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("SetBuildingGeneratorRadius", {
        buildingKey = buildingKey,
        radius = radius,
    })
end

function EPR.Client.RequestHookSpriteGenerator(x, y, z)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("HookSpriteGenerator", {
        x = x,
        y = y,
        z = z or 0,
    })
end

function EPR.Client.RequestToggleSpriteGenerator(key, active)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end

    EPR.Client.SendCommand("ToggleSpriteGenerator", {
        key = key,
        active = active == true,
    })
end

function EPR.Client.RequestSpriteGeneratorRefuel(key)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end
    EPR.Client.SendCommand("SpriteGeneratorRefuel", {
        key = key,
    })
end

function EPR.Client.RequestSpriteGeneratorMaintain(key)
    if EPR.Client.IsSinglePlayer() then
        return nil
    end
    EPR.Client.SendCommand("SpriteGeneratorMaintain", {
        key = key,
    })
end

-- ============================================
-- SYNC COMMANDS
-- ============================================

function EPR.Client.RequestSync()
    if EPR.Client.IsSinglePlayer() then
        logDebug("[EPR Client] SP mode - no sync needed")
        return
    end

    EPR.Client.SendCommand("RequestSync", {})
end

-- ============================================
-- ADMIN COMMANDS
-- ============================================

function EPR.Client.AdminSetZonePower(zoneName, powered)
    if EPR.Client.IsSinglePlayer() then
        -- Direct call in SP
        if EPR.SetZonePower then
            EPR.SetZonePower(zoneName, powered)
        end
        return
    end

    EPR.Client.SendCommand("AdminSetPower", {
        zone = zoneName,
        powered = powered,
    })
end

function EPR.Client.AdminSetZoneWater(zoneName, watered)
    if EPR.Client.IsSinglePlayer() then
        -- Direct call in SP
        if EPR.SetZoneWater then
            EPR.SetZoneWater(zoneName, watered)
        end
        return
    end

    EPR.Client.SendCommand("AdminSetWater", {
        zone = zoneName,
        watered = watered,
    })
end

-- ============================================
-- SERVER COMMAND HANDLER
-- ============================================

function EPR.Client.OnServerCommand(module, command, args)
    -- Only handle EPR commands
    if module ~= "EPR" then return end

    logDebug("[EPR Client] Received server command: " .. command)

    if command == "FullSync" then
        EPR.Client.HandleFullSync(args)

    elseif command == "ZonePowerChanged" then
        EPR.Client.HandleZonePowerChanged(args)

    elseif command == "ZoneWaterChanged" then
        EPR.Client.HandleZoneWaterChanged(args)

    elseif command == "FacilityUpdate" then
        EPR.Client.HandleFacilityUpdate(args)
    elseif command == "GlobalOverrideChanged" then
        EPR.Client.HandleGlobalOverrideChanged(args)

    elseif command == "RepairStarted" then
        EPR.Client.HandleRepairStarted(args)

    elseif command == "RepairDenied" then
        EPR.Client.HandleRepairDenied(args)

    elseif command == "StageCompleted" then
        EPR.Client.HandleStageCompleted(args)

    elseif command == "BuildingUpdate" then
        EPR.Client.HandleBuildingUpdate(args)

    elseif command == "StreetLightUpdate" then
        EPR.Client.HandleStreetLightUpdate(args)

    elseif command == "BuildingDenied" then
        EPR.Client.HandleBuildingDenied(args)

    elseif command == "SpriteGeneratorUpdate" then
        EPR.Client.HandleSpriteGeneratorUpdate(args)

    elseif command == "FacilityStartupFlicker" then
        EPR.Client.HandleFacilityStartupFlicker(args)

    else
        logDebug("[EPR Client] Unknown server command: " .. command)
    end
end

-- ============================================
-- SYNC HANDLERS
-- ============================================

function EPR.Client.HandleFullSync(args)
    if not args then return end

    logDebug("[EPR Client] ====== Applying full state sync ======")

    -- Apply powered zones
    if args.PoweredZones then
        EPR.PoweredZones = args.PoweredZones
        local poweredCount = 0
        for zone, powered in pairs(EPR.PoweredZones) do
            if powered then
                poweredCount = poweredCount + 1
                logDebug("[EPR Client]   Powered zone: " .. zone)
            end
        end
        logDebug("[EPR Client] Total powered zones: " .. poweredCount)
    end

    -- Apply watered zones
    if args.WaterZones then
        EPR.WaterZones = args.WaterZones
    end

    -- Apply substations
    if args.Substations then
        EPR.Substations = args.Substations
        for id, state in pairs(EPR.Substations) do
            logDebug("[EPR Client]   Substation " .. id .. ": " .. tostring(state.status))
        end
    end

    -- Apply water plants
    if args.WaterPlants then
        EPR.WaterPlants = args.WaterPlants
        for id, state in pairs(EPR.WaterPlants) do
            logDebug("[EPR Client]   WaterPlant " .. id .. ": " .. tostring(state.status))
        end
    end

    -- Apply generators/water tanks
    if args.Generators then
        EPR.Generators = args.Generators
    end
    if args.WaterTanks then
        EPR.WaterTanks = args.WaterTanks
    end

    -- Apply active repairs
    if args.ActiveRepairs then
        EPR.ActiveRepairs = args.ActiveRepairs
    end

    if args.ConnectedBuildings then
        EPR.ConnectedBuildings = args.ConnectedBuildings
    end

    if args.ConnectedStreetLights then
        EPR.ConnectedStreetLights = args.ConnectedStreetLights
    end

    if args.SpriteGenerators then
        EPR.SpriteGenerators = args.SpriteGenerators
    end

    if args.PowerController and EPR.PowerController then
        if args.PowerController.globalOverride ~= nil then
            EPR.PowerController.globalOverride = args.PowerController.globalOverride == true
        end
        if args.PowerController.louisvilleEverOnline ~= nil then
            EPR.PowerController.louisvilleEverOnline = args.PowerController.louisvilleEverOnline == true
        end
    end

    EPR.Client.syncCompleted = true
    logDebug("[EPR Client] ====== Full sync complete ======")

    -- Update power controller state based on synced data
    if EPR.PowerController and EPR.PowerController.UpdateNetworks then
        logDebug("[EPR Client] Updating network status after sync...")
        EPR.PowerController.UpdateNetworks()
    end

    -- Trigger UI refresh if panel is open
    if EPR.FacilityUI and EPR.FacilityUI.RefreshIfOpen then
        EPR.FacilityUI.RefreshIfOpen()
    end

    if EPR.Buildings and EPR.Buildings.OnLoaded then
        EPR.Buildings.OnLoaded()
    end
    if EPR.Buildings and EPR.Buildings.ApplyAllSpriteGenerators then
        EPR.Buildings.ApplyAllSpriteGenerators()
    end
end

function EPR.Client.HandleGlobalOverrideChanged(args)
    if not args or args.enabled == nil then return end
    if EPR.PowerController then
        EPR.PowerController.globalOverride = args.enabled == true
        logDebug("[EPR Client] Global override changed: " .. tostring(EPR.PowerController.globalOverride))
    end
end

function EPR.Client.HandleZonePowerChanged(args)
    if not args or not args.zone then return end

    local zoneName = args.zone
    local powered = args.powered == true

    EPR.PoweredZones = EPR.PoweredZones or {}
    EPR.PoweredZones[zoneName] = powered

    logDebug("[EPR Client] Zone power changed: " .. zoneName .. " = " .. tostring(powered))

    if EPR.Buildings and EPR.Buildings.ApplyZonePower then
        EPR.Buildings.ApplyZonePower(zoneName, powered)
    end

    -- Trigger event for UI updates
    if EPR.Events and EPR.Events.OnZonePowerChanged then
        EPR.Events.OnZonePowerChanged(zoneName, powered)
    end
end

function EPR.Client.HandleZoneWaterChanged(args)
    if not args or not args.zone then return end

    local zoneName = args.zone
    local watered = args.watered == true

    EPR.WaterZones = EPR.WaterZones or {}
    EPR.WaterZones[zoneName] = watered

    logDebug("[EPR Client] Zone water changed: " .. zoneName .. " = " .. tostring(watered))

    if EPR.Buildings and EPR.Buildings.ApplyZoneWater then
        EPR.Buildings.ApplyZoneWater(zoneName, watered)
    end

    -- Trigger event for UI updates
    if EPR.Events and EPR.Events.OnZoneWaterChanged then
        EPR.Events.OnZoneWaterChanged(zoneName, watered)
    end
end

function EPR.Client.HandleFacilityUpdate(args)
    if not args or not args.facilityId or not args.state then return end

    local facilityId = args.facilityId
    local facilityType = args.facilityType
    local state = args.state

    if facilityType == "power" or facilityType == "combined" then
        EPR.Substations = EPR.Substations or {}
        EPR.Substations[facilityId] = state
    end

    if facilityType == "water" or facilityType == "combined" then
        EPR.WaterPlants = EPR.WaterPlants or {}
        EPR.WaterPlants[facilityId] = state
    end

    logDebug("[EPR Client] Facility updated: " .. facilityId)

    -- Trigger UI refresh if panel is open
    if EPR.FacilityUI and EPR.FacilityUI.RefreshIfOpen then
        EPR.FacilityUI.RefreshIfOpen()
    end
end

-- ============================================
-- REPAIR RESPONSE HANDLERS
-- ============================================

function EPR.Client.HandleRepairStarted(args)
    if not args then return end

    logDebug("[EPR Client] Repair started: " .. tostring(args.componentType))

    if args.facilityId and args.componentType and EPR.Repair and EPR.Repair.StartComponentRepair then
        local facility = EPR.Zones and EPR.Zones.GetFacility and EPR.Zones.GetFacility(args.facilityId)
        local player = getPlayer()
        if facility and player then
            local ok = EPR.Repair.StartComponentRepair(player, facility, args.componentType, true)
            if not ok and EPR.Client.CancelRepair then
                EPR.Client.CancelRepair()
            end
        end
    end
    if EPR.Repair then EPR.Repair.PendingRepair = nil end
end

function EPR.Client.HandleRepairDenied(args)
    if not args then return end

    local reason = args.reason or "Repair denied"
    logDebug("[EPR Client] Repair denied: " .. reason)

    -- Notify player
    local player = getPlayer()
    if player then
        player:Say(reason)
    end

    -- Cancel any pending action
    -- The timed action should check validity and stop if needed
    if EPR.Repair then EPR.Repair.PendingRepair = nil end
end

function EPR.Client.HandleStageCompleted(args)
    if not args then return end

    logDebug("[EPR Client] Stage completed: " .. tostring(args.stageName))

    -- State should be updated via FacilityUpdate
    -- This is just a confirmation
end

function EPR.Client.HandleBuildingUpdate(args)
    if not args or not args.buildingKey then return end

    local isMp = false
    if EPR.Client and type(EPR.Client.IsMultiplayer) == "function" then
        isMp = EPR.Client.IsMultiplayer()
    end
    if isMp then
        local zonesEmpty = true
        if EPR.PoweredZones and type(EPR.PoweredZones) == "table" then
            for _ in pairs(EPR.PoweredZones) do
                zonesEmpty = false
                break
            end
        end
        if zonesEmpty and EPR.WaterZones and type(EPR.WaterZones) == "table" then
            for _ in pairs(EPR.WaterZones) do
                zonesEmpty = false
                break
            end
        end
        if zonesEmpty and type(EPR.Client.RequestSync) == "function" then
            EPR.Client.RequestSync()
        end
    end

    EPR.ConnectedBuildings = EPR.ConnectedBuildings or {}
    if args.removed then
        EPR.ConnectedBuildings[args.buildingKey] = nil
    elseif args.record then
        EPR.ConnectedBuildings[args.buildingKey] = args.record
    end

    if EPR.Buildings then
        EPR.Buildings.Connected = EPR.ConnectedBuildings
        if EPR.Buildings.RebuildZoneCounts then
            EPR.Buildings.RebuildZoneCounts()
        end
        if args.record and EPR.Buildings.ApplyBuildingRecord then
            EPR.Buildings.ApplyBuildingRecord(args.record)
        end
        local zonesReady = false
        if EPR.PoweredZones and type(EPR.PoweredZones) == "table" then
            for _ in pairs(EPR.PoweredZones) do
                zonesReady = true
                break
            end
        end
        if not zonesReady and EPR.WaterZones and type(EPR.WaterZones) == "table" then
            for _ in pairs(EPR.WaterZones) do
                zonesReady = true
                break
            end
        end
        if zonesReady and EPR.Buildings.ApplyAllZones then
            EPR.Buildings.ApplyAllZones()
        end
    end
end

function EPR.Client.HandleStreetLightUpdate(args)
    if not args or not args.lightKey then return end

    EPR.ConnectedStreetLights = EPR.ConnectedStreetLights or {}
    if args.removed then
        if EPR.StreetLights then
            EPR.StreetLights.Disconnect(args.lightKey)
        end
        EPR.ConnectedStreetLights[args.lightKey] = nil
        if EPR.StreetLights then
            EPR.StreetLights.Connected = EPR.ConnectedStreetLights
        end
        return
    end

    if args.record then
        EPR.ConnectedStreetLights[args.lightKey] = args.record
        if EPR.StreetLights then
            EPR.StreetLights.Connected = EPR.ConnectedStreetLights
            EPR.StreetLights.ApplyRecord(args.record)
        end
    end
end

function EPR.Client.HandleSpriteGeneratorUpdate(args)
    if not args or not args.key then return end

    EPR.SpriteGenerators = EPR.SpriteGenerators or {}
    if args.removed then
        EPR.SpriteGenerators[args.key] = nil
        return
    end

    if args.record then
        EPR.SpriteGenerators[args.key] = args.record
        if EPR.Buildings and EPR.Buildings.ApplySpriteGeneratorRecord then
            EPR.Buildings.ApplySpriteGeneratorRecord(args.record)
        end
    end

    if EPR.SpriteGeneratorUI and EPR.SpriteGeneratorUI.RefreshIfOpen then
        EPR.SpriteGeneratorUI.RefreshIfOpen()
    end
end

function EPR.Client.HandleBuildingDenied(args)
    local reason = args and args.reason or "Action denied"
    local player = getPlayer()
    if player then
        player:Say(reason)
    end
    logDebug("[EPR Client] Building action denied: " .. tostring(reason))
end

function EPR.Client.HandleFacilityStartupFlicker(args)
    -- Trigger Immersive Blackouts flicker effect if IB is loaded
    if ImmersiveBlackouts and ImmersiveBlackouts.StartFlicker then
        pcall(function() ImmersiveBlackouts.StartFlicker(0, true, false) end)
    end
end

-- ============================================
-- INITIALIZATION
-- ============================================

function EPR.Client.OnGameStart()
    logDebug("[EPR Client] Game started")

    -- Request initial sync in MP
    if EPR.Client.IsMultiplayer() then
        -- Small delay to ensure server is ready
        EPR.Client.RequestSync()
    end
end

function EPR.Client.OnConnected()
    logDebug("[EPR Client] Connected to server")

    -- Request sync on (re)connect
    EPR.Client.RequestSync()
end

-- ============================================
-- EVENT REGISTRATION
-- ============================================

if Events then
    Events.OnServerCommand.Add(EPR.Client.OnServerCommand)
    Events.OnGameStart.Add(EPR.Client.OnGameStart)
    Events.OnConnected.Add(EPR.Client.OnConnected)

    logDebug("[EPR Client] Client events registered")
else
    print("[EPR Client] ERROR: Events not available!")
end

logDebug("[EPR Client] EPR_Client.lua loaded successfully")
