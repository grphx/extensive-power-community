--[[
    Extensive Power Rework - Context Menu

    Adds right-click options when clicking on facility components:
    - Uses COORDINATE-based detection (exact tile positions)
    - Each component has fixed tile locations defined in EPR_Zones
    - Multi-tile components work (clicking any tile triggers menu)

    Options:
    - View Info (shows facility status panel)
    - Repair [Component Name] (for damaged components)
    - Perform Maintenance (if online and health < 80%)
]]--

if isServer() and not isClient() then return end

print("[EPR] EPR_ContextMenu.lua loading...")

require "ISUI/ISWorldObjectContextMenu"

EPR = EPR or {}
EPR.ContextMenu = {}

local function saveIfAuthoritative()
    if EPR and EPR.IsServerContext and EPR.IsServerContext() then
        EPR.SaveData()
    end
end

-- ============================================
-- COORDINATE-BASED DETECTION
-- ============================================

-- Check if clicked coordinates match any facility component
-- Returns: facility, facilityKey, componentType (nil if clicked on terminal itself)
local function GetFacilityAtCoordinates(objX, objY)
    if not EPR.Zones or not EPR.Zones.Facilities then return nil end

    -- First check if we clicked on a component tile (tolerance 2 for easier clicking)
    local compType, facility, key = EPR.Zones.FindComponentNearTile(objX, objY, 2)
    if facility then
        return facility, key, compType
    end

    -- Check if we clicked near a facility's main terminal
    for key, facility in pairs(EPR.Zones.Facilities) do
        local dx = math.abs(facility.x - objX)
        local dy = math.abs(facility.y - objY)
        if dx <= 2 and dy <= 2 then
            return facility, key, nil  -- nil = main terminal
        end
    end

    return nil, nil, nil
end

-- ============================================
-- CONTEXT MENU HOOKS
-- ============================================

local function OnFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then return true end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    if not EPR.Zones or not EPR.Zones.Facilities then
        return
    end

    -- Check clicked objects for facility components
    local facility = nil
    local facilityKey = nil
    local componentType = nil
    local clickedObject = nil
    local firstObject = nil

    -- Handle both Lua table and Java ArrayList
    local function iterateObjects(objects)
        if objects.size then
            for i = 0, objects:size() - 1 do
                coroutine.yield(objects:get(i))
            end
        else
            for _, obj in ipairs(objects) do
                coroutine.yield(obj)
            end
        end
    end

    for obj in coroutine.wrap(function() iterateObjects(worldobjects) end) do
        if not firstObject then
            firstObject = obj
        end
        local objX = (obj.getX and obj:getX()) or 0
        local objY = (obj.getY and obj:getY()) or 0

        if objX > 0 and objY > 0 then
    facility, facilityKey, componentType = GetFacilityAtCoordinates(objX, objY)
    if facility and facilityKey then
        facility.key = facilityKey
    end
            if facility then
                clickedObject = obj
                if EPR.IsDebugMode() then
                    local compStr = componentType and componentType or "Terminal"
                    print("[EPR DEBUG] MATCH FOUND: " .. facility.name .. " - " .. compStr .. " at " .. objX .. "," .. objY)
                end
                break
            elseif EPR.IsDebugMode() then
                -- Log coordinates that didn't match (useful for debugging tile definitions)
                print("[EPR DEBUG] No match at coords: " .. objX .. "," .. objY)
            end
        end
    end

    if facility then
        -- Calculate distance from player
        local px = playerObj:getX()
        local py = playerObj:getY()
        local dx = facility.x - px
        local dy = facility.y - py
        local distance = math.sqrt(dx * dx + dy * dy)

        -- Get facility status
        local status = nil
        if facility.type == "power" or facility.type == "combined" then
            status = EPR.Substations and EPR.Substations[facility.id]
        elseif facility.type == "water" then
            status = EPR.WaterPlants and EPR.WaterPlants[facility.id]
        end

        -- Initialize status if needed
        if not status and EPR.Repair and EPR.Repair.GetFacilityState then
            status = EPR.Repair.GetFacilityState(facility)
        end

        local facilityStatus = status and status.status or "offline"

        -- Build menu title
        local menuTitle = facility.name
        if componentType then
            local compDef = EPR.Components[componentType]
            local compName = compDef and compDef.name or componentType
            menuTitle = menuTitle .. " - " .. compName
        end

        -- Add facility submenu
        local facilityMenu = context:addOption(menuTitle, nil, nil)
        local subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(facilityMenu, subMenu)

        -- Info option - different for components vs main terminal
        if componentType then
            -- Component-specific: show component repair panel
            subMenu:addOption(
                getText("UI_EPR_Menu_ViewComponentStatus") or "View Component Status",
                playerObj,
                EPR.ContextMenu.OnViewComponent,
                facility,
                status,
                componentType
            )
        else
            -- Main terminal: show full facility status
            subMenu:addOption(
                getText("UI_EPR_Menu_ViewFacilityStatus") or "View Facility Status",
                playerObj,
                EPR.ContextMenu.OnViewInfo,
                facility,
                status
            )
        end

        -- Component-specific repair options
        if componentType and status and status.components then
            local compState = status.components[componentType]
            if compState and (compState.status == "damaged" or compState.status == "repairing") then
                local canRepair, reason = EPR.Zones.CanRepairFacility(facility.id)

                if canRepair then
                    local meetsSkills = EPR.ContextMenu.CheckSkillRequirements(playerObj, facility)

                    if meetsSkills then
                        local repairText = compState.status == "repairing"
                            and string.format(getText("UI_EPR_Menu_ContinueRepair") or "Continue Repair (%d%%)", compState.progress or 0)
                            or getText("UI_EPR_Menu_RepairComponent") or "Repair Component"

                        subMenu:addOption(
                            repairText,
                            playerObj,
                            EPR.ContextMenu.OnRepairComponent,
                            facility,
                            status,
                            componentType
                        )
                    else
                        local option = subMenu:addOption(getText("UI_EPR_Menu_InsufficientSkills") or "Insufficient Skills", nil, nil)
                        option.notAvailable = true
                    end
                else
                    local option = subMenu:addOption(reason or "Cannot repair", nil, nil)
                    option.notAvailable = true
                end
            elseif compState and (compState.status == "functional" or compState.status == "repaired") then
                local option = subMenu:addOption(getText("UI_EPR_Menu_ComponentFunctional") or "Component Functional", nil, nil)
                option.notAvailable = true
            else
                -- compState is nil - component not in repair list for this facility
                local compDef = EPR.Components[componentType]
                local compName = compDef and compDef.name or componentType
                local option = subMenu:addOption(string.format(getText("UI_EPR_Menu_ComponentNotDamaged") or "%s - Not damaged", compName), nil, nil)
                option.notAvailable = true
            end
        -- Component exists in facility definition but status.components is empty/nil
        elseif componentType and status then
            local compDef = EPR.Components[componentType]
            local compName = compDef and compDef.name or componentType
            local option = subMenu:addOption(string.format(getText("UI_EPR_Menu_ComponentNoRepair") or "%s - No repair needed", compName), nil, nil)
            option.notAvailable = true

        -- Component detected but facility status not loaded
        elseif componentType and not status then
            local compDef = EPR.Components[componentType]
            local compName = compDef and compDef.name or componentType
            local option = subMenu:addOption(string.format(getText("UI_EPR_Menu_ComponentScanFirst") or "%s - View status to scan", compName), nil, nil)
            option.notAvailable = true

        -- Terminal-specific options (no component = main terminal)
        -- NOTE: Repairs must be done at component locations, not from the terminal
        elseif not componentType then
            if facilityStatus == "ready" or facilityStatus == "starting" then
                -- All components repaired, ready for startup!
                local meetsSkills = EPR.ContextMenu.CheckSkillRequirements(playerObj, facility)
                if meetsSkills then
                    if facilityStatus == "starting" then
                        local option = subMenu:addOption(getText("UI_EPR_Menu_StartupInProgress") or "Startup in progress...", nil, nil)
                        option.notAvailable = true
                    else
                        subMenu:addOption(
                            getText("UI_EPR_Menu_StartFacilityDefense") or "Start Facility (5 min defense!)",
                            playerObj,
                            EPR.ContextMenu.OnStartFacility,
                            facility,
                            status
                        )
                    end
                else
                    local option = subMenu:addOption(getText("UI_EPR_Menu_InsufficientSkillsStartup") or "Insufficient Skills for Startup", nil, nil)
                    option.notAvailable = true
                end

            elseif facilityStatus == "offline" or facilityStatus == "broken" or facilityStatus == "repairing" then
                local canRepair, reason = EPR.Zones.CanRepairFacility(facility.id)

                if canRepair then
                    local damagedCount = EPR.Repair and EPR.Repair.GetDamagedComponentCount and EPR.Repair.GetDamagedComponentCount(status) or 0

                    if damagedCount > 0 then
                        -- Show info about what needs repair, but don't allow repair from terminal
                        local infoText = string.format(getText("UI_EPR_Menu_ComponentsNeedRepair") or "%d component(s) need repair", damagedCount)
                        local option = subMenu:addOption(infoText, nil, nil)
                        option.notAvailable = true

                        -- Add hint to go to components
                        local hintOption = subMenu:addOption(getText("UI_EPR_Menu_GoToComponents") or "Go to each component to repair", nil, nil)
                        hintOption.notAvailable = true
                    else
                        -- All components repaired but status wasn't updated to "ready" (shouldn't happen normally)
                        local meetsSkills = EPR.ContextMenu.CheckSkillRequirements(playerObj, facility)
                        if meetsSkills then
                            subMenu:addOption(
                                getText("UI_EPR_Menu_StartFacility") or "Start Facility",
                                playerObj,
                                EPR.ContextMenu.OnStartFacility,
                                facility,
                                status
                            )
                        else
                            local option = subMenu:addOption(getText("UI_EPR_Menu_InsufficientSkills") or "Insufficient Skills", nil, nil)
                            option.notAvailable = true
                        end
                    end
                else
                    local option = subMenu:addOption(reason or "Cannot repair", nil, nil)
                    option.notAvailable = true
                end

            elseif facilityStatus == "online" then
                local health = status and status.health or 100
                if health < 80 then
                    subMenu:addOption(
                        getText("UI_EPR_Menu_Maintenance") or "Perform Maintenance",
                        playerObj,
                        EPR.ContextMenu.OnMaintenance,
                        facility,
                        status
                    )
                else
                    local option = subMenu:addOption(getText("UI_EPR_Menu_NoMaintenanceNeeded") or "No maintenance needed", nil, nil)
                    option.notAvailable = true
                end

                if EPR.IsDebugMode() then
                    subMenu:addOption(
                        "[DEBUG] Shutdown",
                        playerObj,
                        EPR.ContextMenu.OnDebugShutdown,
                        facility
                    )
                end
            end
        end

        -- Distance indicator
        local distText = string.format("Distance: %.0f tiles", distance)
        local distOption = subMenu:addOption(distText, nil, nil)
        distOption.notAvailable = true
    end

    -- ============================================
    -- EPR GRID (Building/Streetlight)
    -- ============================================

    local gridObj = clickedObject or firstObject
    if gridObj and EPR.Buildings and EPR.StreetLights then
        local square = gridObj.getSquare and gridObj:getSquare() or nil
        if not square then
            local objX = (gridObj.getX and gridObj:getX()) or 0
            local objY = (gridObj.getY and gridObj:getY()) or 0
            local objZ = (gridObj.getZ and gridObj:getZ()) or 0
            if objX > 0 and objY > 0 then
                square = getSquare(objX, objY, objZ)
            end
        end

        if square then
            local zoneName = EPR.Zones and EPR.Zones.GetZoneAt and EPR.Zones.GetZoneAt(square:getX(), square:getY()) or nil
            local building = square.getBuilding and square:getBuilding() or nil
            local isStreetLight = EPR.StreetLights.IsStreetLight and EPR.StreetLights.IsStreetLight(gridObj) or false

            if zoneName or isStreetLight or building then
                -- Populate the submenu first; the "EPR Grid" parent is only
                -- attached at the end if at least one option was added, so a
                -- building/streetlight in a zone coverage gap never shows a
                -- blank, dead submenu (Bug 2).
                local gridSub = ISContextMenu:getNew(context)

                if zoneName then
                    local zonePowered = EPR.PoweredZones and EPR.PoweredZones[zoneName] == true
                    local zoneWatered = EPR.WaterZones and EPR.WaterZones[zoneName] == true
                    local statusText = "Zone: " .. zoneName .. " [" .. (zonePowered and "PWR" or "---") .. "/" .. (zoneWatered and "H2O" or "---") .. "]"
                    local zoneOption = gridSub:addOption(statusText, nil, nil)
                    zoneOption.notAvailable = true
                end

                if building and zoneName then
                    local key = EPR.Buildings.GetBuildingKey and EPR.Buildings.GetBuildingKey(building, square) or nil
                    local connected = key and EPR.Buildings.IsBuildingConnected and EPR.Buildings.IsBuildingConnected(key)
                    local canConnect, reason = EPR.Buildings.CanConnectZone and EPR.Buildings.CanConnectZone(zoneName)
                    local meetsSkill = EPR.Buildings.PlayerHasElectricalSkill and EPR.Buildings.PlayerHasElectricalSkill(playerObj, 3)

                    if connected then
                        gridSub:addOption(
                            "Disconnect Building from EPR Grid",
                            playerObj,
                            EPR.ContextMenu.OnDisconnectBuilding,
                            key
                        )

                        local maintainOption = gridSub:addOption(
                            "Maintain EPR Connection",
                            playerObj,
                            EPR.ContextMenu.OnMaintainBuilding,
                            key
                        )
                        if not meetsSkill then
                            maintainOption.notAvailable = true
                        else
                            local missing = EPR.Buildings.GetMaintenanceMissingItems and EPR.Buildings.GetMaintenanceMissingItems(playerObj) or {}
                            if #missing > 0 then
                                maintainOption.notAvailable = true
                                maintainOption.toolTip = ISToolTip:new()
                                maintainOption.toolTip:initialise()
                                maintainOption.toolTip:setVisible(true)
                                maintainOption.toolTip.description = "Missing maintenance items"
                            end
                        end

                        if key and EPR.Buildings.GetBuildingRecord then
                            local record = EPR.Buildings.GetBuildingRecord(key)
                            if record and record.maintenanceStatus == "flicker" then
                                local flickerOption = gridSub:addOption("Maintenance overdue (flickering)", nil, nil)
                                flickerOption.notAvailable = true
                            end
                        end

                    else
                        local option = gridSub:addOption(
                            "Connect Building to EPR Grid",
                            playerObj,
                            EPR.ContextMenu.OnConnectBuilding,
                            building,
                            square,
                            zoneName
                        )
                        if not canConnect or not meetsSkill then
                            option.notAvailable = true
                            option.toolTip = ISToolTip:new()
                            option.toolTip:initialise()
                            option.toolTip:setVisible(true)
                            if not meetsSkill then
                                option.toolTip.description = "Electrical 3 required"
                            else
                                option.toolTip.description = reason or "Zone is offline"
                            end
                        end
                    end

                    local cap = EPR.Buildings.GetZoneCap and EPR.Buildings.GetZoneCap() or 0
                    if cap > 0 then
                        local count = EPR.Buildings.GetZoneCount and EPR.Buildings.GetZoneCount(zoneName) or 0
                        local capText = string.format("Connected buildings: %d / %d", count, cap)
                        local capOption = gridSub:addOption(capText, nil, nil)
                        capOption.notAvailable = true
                    end

                    local accessLevel = ""
                    pcall(function()
                        accessLevel = playerObj and playerObj:getAccessLevel() or ""
                    end)
                    local isHost = (isCoopHost and isCoopHost()) == true
                    if accessLevel ~= "" or isHost then
                        gridSub:addOption(
                            "Connect All Buildings in " .. zoneName,
                            playerObj,
                            EPR.ContextMenu.OnConnectAllBuildings,
                            zoneName
                        )
                    end
                end

                if isStreetLight and zoneName then
                    local lightKey = tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
                    local connectedLight = EPR.StreetLights.Connected and EPR.StreetLights.Connected[lightKey]
                    local canConnect = EPR.PoweredZones and EPR.PoweredZones[zoneName] == true
                    local reason = "Zone power is offline"

                    if connectedLight then
                        gridSub:addOption(
                            "Disconnect Streetlight from EPR Grid",
                            playerObj,
                            EPR.ContextMenu.OnDisconnectStreetLight,
                            lightKey
                        )
                    else
                        local option = gridSub:addOption(
                            "Connect Streetlight to EPR Grid",
                            playerObj,
                            EPR.ContextMenu.OnConnectStreetLight,
                            square,
                            zoneName
                        )
                        if not canConnect then
                            option.notAvailable = true
                            option.toolTip = ISToolTip:new()
                            option.toolTip:initialise()
                            option.toolTip:setVisible(true)
                            option.toolTip.description = reason
                        end
                    end
                end

                -- Coverage gap: the object is outside every EPR zone, so none
                -- of the blocks above added anything. Explain why instead of
                -- leaving a blank, dead submenu (Bug 2).
                if #gridSub.options == 0 and (building or isStreetLight) and not zoneName then
                    local info = gridSub:addOption("Not within any EPR power/water zone", nil, nil)
                    info.notAvailable = true
                    info.toolTip = ISToolTip:new()
                    info.toolTip:initialise()
                    info.toolTip:setVisible(true)
                    info.toolTip.description = "EPR power/water grids only cover defined zones. This location is in a coverage gap, so it cannot be connected here."
                end

                -- Only attach the parent if the submenu actually has content.
                if #gridSub.options > 0 then
                    local gridMenu = context:addOption("EPR Grid", nil, nil)
                    context:addSubMenu(gridMenu, gridSub)
                end
            end
        end
    end

    -- ============================================
    -- SPRITE GENERATORS
    -- ============================================

    if EPR.Buildings and EPR.Buildings.IsSpriteGeneratorSprite then
        local spriteObj = nil
        local spriteName = nil
        local spriteSquare = nil

        for obj in coroutine.wrap(function() iterateObjects(worldobjects) end) do
            if obj and obj.getSprite then
                local sprite = obj:getSprite()
                local name = sprite and sprite:getName()
                if EPR.Buildings.IsSpriteGeneratorSprite(name) then
                    spriteObj = obj
                    spriteName = name
                    break
                end
            end
        end

        if spriteObj and spriteName then
            spriteSquare = spriteObj.getSquare and spriteObj:getSquare() or nil
            if not spriteSquare then
                local objX = (spriteObj.getX and spriteObj:getX()) or 0
                local objY = (spriteObj.getY and spriteObj:getY()) or 0
                local objZ = (spriteObj.getZ and spriteObj:getZ()) or 0
                if objX > 0 and objY > 0 then
                    spriteSquare = getSquare(objX, objY, objZ)
                end
            end

            local menuTitle = getText("UI_EPR_SpriteGen_Menu") or "EPR Generator"
            local genMenu = context:addOption(menuTitle, nil, nil)
            local genSub = ISContextMenu:getNew(context)
            context:addSubMenu(genMenu, genSub)

            if not spriteSquare then
                local option = genSub:addOption(getText("UI_EPR_SpriteGen_NoSquare") or "No square found", nil, nil)
                option.notAvailable = true
                return
            end

            local key = EPR.Buildings.GetSpriteGeneratorKey and EPR.Buildings.GetSpriteGeneratorKey(spriteSquare:getX(), spriteSquare:getY(), spriteSquare:getZ()) or nil
            local record = key and EPR.SpriteGenerators and EPR.SpriteGenerators[key] or nil
            local building = spriteSquare.getBuilding and spriteSquare:getBuilding() or nil

            local statusText = record and (record.active and (getText("UI_EPR_SpriteGen_StatusActive") or "Status: Active") or (getText("UI_EPR_SpriteGen_StatusInactive") or "Status: Inactive")) or (getText("UI_EPR_SpriteGen_StatusNotHooked") or "Status: Not hooked")
            local statusOption = genSub:addOption(statusText, nil, nil)
            statusOption.notAvailable = true

            if not building then
                local option = genSub:addOption(getText("UI_EPR_SpriteGen_NoBuilding") or "No building found", nil, nil)
                option.notAvailable = true
                return
            end

            if not record then
                local option = genSub:addOption(
                    getText("UI_EPR_SpriteGen_Hook") or "Hook Up Generator",
                    playerObj,
                    EPR.ContextMenu.OnHookSpriteGenerator,
                    spriteSquare,
                    spriteName
                )

                local hasSkill = EPR.Buildings.PlayerHasSpriteGeneratorSkill and EPR.Buildings.PlayerHasSpriteGeneratorSkill(playerObj)
                local hasTools = EPR.Buildings.PlayerHasSpriteGeneratorTools and EPR.Buildings.PlayerHasSpriteGeneratorTools(playerObj)
                if not hasSkill or not hasTools then
                    option.notAvailable = true
                    option.toolTip = ISToolTip:new()
                    option.toolTip:initialise()
                    option.toolTip:setVisible(true)
                    if not hasSkill then
                        option.toolTip.description = getText("UI_EPR_SpriteGen_SkillRequired") or "Electrical 3 required"
                    else
                        option.toolTip.description = getText("UI_EPR_SpriteGen_ToolsRequired") or "Requires screwdriver, wrench, and pliers"
                    end
                end
            else
                local uiOption = genSub:addOption(
                    getText("UI_EPR_SpriteGen_OpenUI") or "Open Generator UI",
                    playerObj,
                    EPR.ContextMenu.OnOpenSpriteGeneratorUI,
                    record
                )

                if record.active then
                    genSub:addOption(
                        getText("UI_EPR_SpriteGen_Deactivate") or "Deactivate Generator",
                        playerObj,
                        EPR.ContextMenu.OnToggleSpriteGenerator,
                        record.key,
                        false
                    )
                else
                    genSub:addOption(
                        getText("UI_EPR_SpriteGen_Activate") or "Activate Generator",
                        playerObj,
                        EPR.ContextMenu.OnToggleSpriteGenerator,
                        record.key,
                        true
                    )
                end
            end
        end
    end
end

-- ============================================
-- MENU ACTIONS
-- ============================================

function EPR.ContextMenu.OnViewInfo(playerObj, facility, status)
    if EPR.FacilityUI and EPR.FacilityUI.Open then
        EPR.FacilityUI.Open(playerObj, facility, status)
    else
        print("[EPR] FacilityUI not loaded")
    end
end

function EPR.ContextMenu.OnViewComponent(playerObj, facility, status, componentType)
    if EPR.FacilityUI and EPR.FacilityUI.OpenComponent then
        EPR.FacilityUI.OpenComponent(playerObj, facility, status, componentType)
    else
        print("[EPR] FacilityUI.OpenComponent not loaded")
    end
end

function EPR.ContextMenu.OnRepairComponent(playerObj, facility, status, componentType)
    if EPR.Repair and EPR.Repair.StartComponentRepair then
        EPR.Repair.StartComponentRepair(playerObj, facility, componentType)
    else
        print("[EPR] Repair system not loaded")
    end
end

function EPR.ContextMenu.OnBeginRepair(playerObj, facility, status)
    -- Get available component types for this facility
    local availableTypes = EPR.Zones.GetFacilityComponentTypes(facility)

    -- Start repair on first damaged component
    if status and status.components then
        for _, compType in ipairs(availableTypes) do
            local compState = status.components[compType]
            if compState and (compState.status == "damaged" or compState.status == "repairing") then
                if EPR.Repair and EPR.Repair.StartComponentRepair then
                    EPR.Repair.StartComponentRepair(playerObj, facility, compType)
                    return
                end
            end
        end
    end
    playerObj:Say("No damaged components found.")
end

function EPR.ContextMenu.OnStartFacility(playerObj, facility, status)
    if EPR.Repair and EPR.Repair.StartFacilityStartup then
        EPR.Repair.StartFacilityStartup(playerObj, facility, status)
    end
end

function EPR.ContextMenu.OnConnectBuilding(playerObj, building, square, zoneName)
    if not building or not square or not zoneName then return end

    local meetsSkill = EPR.Buildings.PlayerHasElectricalSkill and EPR.Buildings.PlayerHasElectricalSkill(playerObj, 3)
    if not meetsSkill then
        playerObj:Say("Electrical skill 3 required")
        return
    end

    local ok, reason = EPR.Buildings.CanConnectZone(zoneName)
    if not ok then
        playerObj:Say(reason or "Zone is offline")
        return
    end

    if EPR_BuildingConnectAction then
        ISTimedActionQueue.add(EPR_BuildingConnectAction:new(playerObj, square, zoneName))
    else
        EPR.ContextMenu.PerformConnectBuilding(playerObj, square, zoneName)
    end
end

function EPR.ContextMenu.PerformConnectBuilding(playerObj, square, zoneName)
    if not square or not zoneName then return end

    local building = square.getBuilding and square:getBuilding() or nil
    if not building then
        playerObj:Say("No building found")
        return
    end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestConnectBuilding(square:getX(), square:getY(), square:getZ(), zoneName)
        return
    end

    local key, err = EPR.Buildings.ConnectBuilding(building, square, zoneName)
    if not key then
        playerObj:Say(err or "Unable to connect building")
        return
    end
    saveIfAuthoritative()
end

function EPR.ContextMenu.OnDisconnectBuilding(playerObj, buildingKey)
    if not buildingKey then return end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestDisconnectBuilding(buildingKey)
        return
    end

    local removed = EPR.Buildings.DisconnectBuilding(buildingKey)
    if removed then
        saveIfAuthoritative()
    end
end

function EPR.ContextMenu.OnConnectAllBuildings(playerObj, zoneName)
    if not zoneName then return end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestConnectAllBuildings(zoneName)
        return
    end

    local count, err = EPR.Buildings.ConnectAllInZone(zoneName)
    if count > 0 then
        saveIfAuthoritative()
    elseif err then
        playerObj:Say(err)
    end
end

function EPR.ContextMenu.OnConnectStreetLight(playerObj, square, zoneName)
    if not square or not zoneName then return end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestConnectStreetLight(square:getX(), square:getY(), square:getZ(), zoneName)
        return
    end

    local powered = EPR.PoweredZones and EPR.PoweredZones[zoneName] == true
    if not powered then
        playerObj:Say("Zone power is offline")
        return
    end

    local key, err = EPR.StreetLights.Connect(square, zoneName)
    if not key then
        playerObj:Say(err or "Unable to connect light")
        return
    end
    saveIfAuthoritative()
end

function EPR.ContextMenu.OnDisconnectStreetLight(playerObj, lightKey)
    if not lightKey then return end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestDisconnectStreetLight(lightKey)
        return
    end

    local removed = EPR.StreetLights.Disconnect(lightKey)
    if removed then
        saveIfAuthoritative()
    end
end

function EPR.ContextMenu.OnMaintainBuilding(playerObj, buildingKey)
    if not buildingKey then return end

    if not EPR.Buildings.PlayerHasElectricalSkill(playerObj, 3) then
        playerObj:Say("Electrical skill 3 required")
        return
    end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestMaintainBuilding(buildingKey)
        return
    end

    local ok = EPR.Buildings.CanMaintain(playerObj)
    if not ok then
        playerObj:Say("Missing maintenance items")
        return
    end

    if not EPR.Buildings.ConsumeMaintenanceItems(playerObj) then
        playerObj:Say("Unable to consume items")
        return
    end

    local record = EPR.Buildings.GetBuildingRecord(buildingKey)
    if record then
        record.lastMaintenanceHours = getGameTime() and getGameTime():getWorldAgeHours() or 0
        record.maintenanceStatus = "ok"
        EPR.Buildings.ApplyBuildingRecord(record)
        saveIfAuthoritative()
    end
end

function EPR.ContextMenu.OnSetGeneratorRadius(playerObj, buildingKey, radius)
    if not buildingKey or not radius then return end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestSetBuildingGeneratorRadius(buildingKey, radius)
        return
    end

    local ok = EPR.Buildings.SetGeneratorRadius(buildingKey, radius)
    if ok then
        saveIfAuthoritative()
    end
end

function EPR.ContextMenu.OnHookSpriteGenerator(playerObj, square, spriteName)
    if not playerObj or not square or not spriteName then return end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestHookSpriteGenerator(square:getX(), square:getY(), square:getZ())
        return
    end

    local record, err = EPR.Buildings.HookSpriteGenerator(square, spriteName)
    if not record then
        playerObj:Say(err or "Unable to hook generator")
        return
    end

    saveIfAuthoritative()
end

function EPR.ContextMenu.OnToggleSpriteGenerator(playerObj, genKey, active)
    if not playerObj or not genKey then return end

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestToggleSpriteGenerator(genKey, active)
        return
    end

    local record, err = EPR.Buildings.ToggleSpriteGenerator(genKey, active)
    if not record then
        playerObj:Say(err or "Unable to toggle generator")
        return
    end

    saveIfAuthoritative()
end

function EPR.ContextMenu.OnOpenSpriteGeneratorUI(playerObj, record)
    if not record then return end
    if EPR.SpriteGeneratorUI and EPR.SpriteGeneratorUI.Open then
        EPR.SpriteGeneratorUI.Open(playerObj, record)
    end
end

function EPR.ContextMenu.OnSpriteGeneratorRefuel(playerObj, genKey)
    if not playerObj or not genKey then return end
    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestSpriteGeneratorRefuel(genKey)
        return
    end
    local record = EPR.SpriteGenerators and EPR.SpriteGenerators[genKey]
    if not record then return end
    local ok, reason = EPR.Buildings.SimulateSpriteGeneratorRefuel(playerObj, record)
    if not ok then
        playerObj:Say(reason or "Unable to refuel")
        return
    end
    EPR.Buildings.ApplySpriteGeneratorRecord(record)
    saveIfAuthoritative()
end

function EPR.ContextMenu.OnSpriteGeneratorMaintain(playerObj, genKey)
    if not playerObj or not genKey then return end
    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        EPR.Client.RequestSpriteGeneratorMaintain(genKey)
        return
    end
    local record = EPR.SpriteGenerators and EPR.SpriteGenerators[genKey]
    if not record then return end
    local ok, reason = EPR.Buildings.SimulateSpriteGeneratorMaintain(playerObj, record)
    if not ok then
        playerObj:Say(reason or "Unable to maintain")
        return
    end
    EPR.Buildings.ApplySpriteGeneratorRecord(record)
    saveIfAuthoritative()
end

function EPR.ContextMenu.OnMaintenance(playerObj, facility, status)
    if EPR.Repair and EPR.Repair.StartMaintenance then
        EPR.Repair.StartMaintenance(playerObj, facility)
    end
end

function EPR.ContextMenu.OnDebugShutdown(playerObj, facility)
    local status = EPR.Substations[facility.id] or EPR.WaterPlants[facility.id]
    if status then
        status.status = "offline"
        status.health = 0
        EPR.Zones.UpdateZoneStatus()
        print("[EPR DEBUG] Shutdown: " .. facility.name)
    end
end

-- ============================================
-- SKILL CHECKING
-- ============================================

function EPR.ContextMenu.CheckSkillRequirements(playerObj, facility)
    local requirements = nil

    if facility.type == "power" or facility.type == "combined" then
        requirements = EPR.Config and EPR.Config.SubstationSkills
    elseif facility.type == "water" then
        requirements = EPR.Config and EPR.Config.WaterPlantSkills
    end

    if not requirements then
        return true
    end

    local difficultyMod = facility.repairDifficulty or 1.0

    for skill, baseLevel in pairs(requirements) do
        local reqLevel = math.ceil(baseLevel * difficultyMod)
        local perk = Perks[skill]

        if perk then
            local playerLevel = playerObj:getPerkLevel(perk)
            if playerLevel < reqLevel then
                return false, skill, reqLevel, playerLevel
            end
        end
    end

    return true
end

-- ============================================
-- EVENT REGISTRATION
-- ============================================

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)

print("[EPR] EPR_ContextMenu.lua loaded successfully")
