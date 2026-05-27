--[[
    Extensive Power Rework - Building/Streetlight Grid

    Enables zone-gated building connections and streetlight activation.
    Server authoritative; clients mirror state for visuals.
]]--

print("[EPR] EPR_BuildingGrid.lua loading...")

EPR = EPR or {}
EPR.Buildings = EPR.Buildings or {}
EPR.StreetLights = EPR.StreetLights or {}

EPR.Buildings.Connected = EPR.ConnectedBuildings or {}
EPR.Buildings.ZoneCounts = EPR.Buildings.ZoneCounts or {}
EPR.Buildings.simulationDirty = false
EPR.StreetLights.Connected = EPR.ConnectedStreetLights or {}
EPR.StreetLights.ActiveSources = EPR.StreetLights.ActiveSources or {}
EPR.Buildings.ActiveGenerators = EPR.Buildings.ActiveGenerators or {}
EPR.Buildings.GeneratorSpawnSupported = false
EPR.SpriteGenerators = EPR.SpriteGenerators or {}

-- Third-party power mods register a callback here to prevent EPR from blocking
-- squares/buildings they are powering. callback(square) → true = allow power.
EPR.Buildings.PowerOverrideChecks = EPR.Buildings.PowerOverrideChecks or {}

function EPR.Buildings.RegisterPowerOverride(name, callback)
    EPR.Buildings.PowerOverrideChecks[name] = callback
end

local function CheckPowerOverrides(square)
    for _, fn in pairs(EPR.Buildings.PowerOverrideChecks) do
        if fn(square) then return true end
    end
    return false
end
local findEPRSpriteGeneratorOnSquare

local spriteGeneratorSprites = {
    ["industry_02_52"] = true,
    ["industry_02_53"] = true,
    ["industry_02_67"] = true,
    ["industry_02_71"] = true,
}

for i = 160, 183 do
    spriteGeneratorSprites["industry_02_" .. tostring(i)] = true
end

local function isMultiplayer()
    local server = isServer()
    local client = isClient()

    if server and not client then
        return true
    end
    if client and not server then
        if getServerOptions and getServerOptions() then
            return true
        end
        return false
    end
    if server and client then
        return getServerOptions and getServerOptions() ~= nil
    end
    return false
end

local function getZoneCap()
    if EPR.Config then
        if isMultiplayer() then
            return EPR.Config.ZoneBuildingCapMP or 0
        end
        return EPR.Config.ZoneBuildingCapSP or 0
    end
    return 0
end

function EPR.Buildings.GetZoneCap()
    return getZoneCap()
end

local function getBuildingKey(building, square)
    if building and building.getID then
        local id = building:getID()
        if id ~= nil then
            return tostring(id)
        end
    end
    if square then
        return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
    end
    return nil
end

local function getBuildingId(building)
    if building and building.getID then
        local id = building:getID()
        if id ~= nil then
            return tostring(id)
        end
    end
    return nil
end

local function getBuildingBoundsKey(building)
    local def = building and building.getDef and building:getDef()
    if not def then return nil end
    if def.getX and def.getY and def.getW and def.getH then
        return tostring(def:getX()) .. "," .. tostring(def:getY()) .. "," .. tostring(def:getW()) .. "," .. tostring(def:getH())
    end
    return nil
end

function EPR.Buildings.GetBuildingKey(building, square)
    return getBuildingKey(building, square)
end

local function getSpriteGeneratorKey(x, y, z)
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z or 0)
end

function EPR.Buildings.GetSpriteGeneratorKey(x, y, z)
    return getSpriteGeneratorKey(x, y, z)
end

function EPR.Buildings.IsSpriteGeneratorSprite(spriteName)
    if not spriteName then return false end
    return spriteGeneratorSprites[string.lower(tostring(spriteName))] == true
end

function EPR.Buildings.GetSpriteGeneratorRecord(key)
    return key and EPR.SpriteGenerators and EPR.SpriteGenerators[key] or nil
end

function EPR.Buildings.GetSpriteGeneratorRecordByBuildingKey(buildingKey)
    if not buildingKey or not EPR.SpriteGenerators then return nil end
    for _, record in pairs(EPR.SpriteGenerators) do
        if record and record.buildingKey == buildingKey then
            return record
        end
    end
    return nil
end

function EPR.Buildings.GetSpriteGeneratorFuel(record)
    if not record then return 0 end
    if record.fuel == nil then
        record.fuel = 100
    end
    return record.fuel
end

function EPR.Buildings.GetSpriteGeneratorCondition(record)
    if not record then return 0 end
    if record.condition == nil then
        record.condition = 100
    end
    return record.condition
end

local function isSpriteGeneratorActiveValue(value)
    return value == true or value == "true" or value == 1
end

function EPR.Buildings.IsSpriteGeneratorActive(record)
    if not record then return false end
    return isSpriteGeneratorActiveValue(record.active)
end

local function isRecordBuildingMatch(record, building)
    if not record or not building then return false end
    local square = getSquare(record.x, record.y, record.z)
    if not square or not square.getBuilding then return false end
    local genBuilding = square:getBuilding()
    return genBuilding ~= nil and genBuilding == building
end

local function isRecordInsideBuilding(record, building)
    if not record or not building then return false end
    local def = building.getDef and building:getDef() or nil
    if not def or not def.getX or not def.getY or not def.getW or not def.getH then
        return false
    end
    local x1, y1 = def:getX(), def:getY()
    local x2, y2 = x1 + def:getW() - 1, y1 + def:getH() - 1
    return record.x >= x1 and record.x <= x2 and record.y >= y1 and record.y <= y2
end

function EPR.Buildings.IsBuildingPoweredBySpriteGenerator(buildingKey, building)
    if not EPR.SpriteGenerators then return false end
    local buildingId = getBuildingId(building)
    local boundsKey = getBuildingBoundsKey(building)
    for _, record in pairs(EPR.SpriteGenerators) do
        if record and EPR.Buildings.IsSpriteGeneratorActive(record) then
            if isRecordBuildingMatch(record, building) then
                return true
            end
            if isRecordInsideBuilding(record, building) then
                return true
            end
            if buildingId and record.buildingId == buildingId then
                return true
            end
            if boundsKey and record.buildingBoundsKey == boundsKey then
                return true
            end
            if buildingKey and record.buildingKey == buildingKey then
                return true
            end
        end
    end
    return false
end

function EPR.Buildings.FindSpriteGeneratorObject(record)
    if not record then return nil end
    local square = nil
    if record.genX then
        square = getSquare(record.genX, record.genY, record.genZ or 0)
    end
    if not square then
        square = getSquare(record.x, record.y, record.z)
    end
    if not square then return nil end
    return findEPRSpriteGeneratorOnSquare(square)
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

function EPR.Buildings.SimulateSpriteGeneratorRefuel(player, record)
    if not record then return false, "No generator" end
    if EPR.Buildings.SpriteGeneratorsUseVirtualOnly and not EPR.Buildings.SpriteGeneratorsUseVirtualOnly() then
        return false, "Virtual mode disabled"
    end
    if EPR.IsServerContext and not EPR.IsServerContext() then
        return false, "Server only"
    end

    local item = findPetrolItem(player)
    if not item then return false, "No petrol" end
    local fc = item:getFluidContainer()
    if not fc then return false, "No fuel container" end

    local fuel = EPR.Buildings.GetSpriteGeneratorFuel(record)
    local maxFuel = 100
    local add = math.min(fc:getAmount(), maxFuel - fuel)
    if add <= 0 then return false, "Fuel full" end

    fc:adjustAmount(fc:getAmount() - add)
    if item.syncItemFields then
        item:syncItemFields()
    end
    record.fuel = fuel + add
    return true
end

function EPR.Buildings.SimulateSpriteGeneratorMaintain(player, record)
    if not record then return false, "No generator" end
    if EPR.Buildings.SpriteGeneratorsUseVirtualOnly and not EPR.Buildings.SpriteGeneratorsUseVirtualOnly() then
        return false, "Virtual mode disabled"
    end
    if EPR.IsServerContext and not EPR.IsServerContext() then
        return false, "Server only"
    end
    if record.active then
        return false, "Deactivate first"
    end
    local condition = EPR.Buildings.GetSpriteGeneratorCondition(record)
    if condition >= 100 then
        return false, "No maintenance needed"
    end
    if not player or not player.getInventory then return false, "No inventory" end
    local inv = player:getInventory()
    if not inv:containsTypeRecurse("ElectronicsScrap") then
        return false, "Need electronics scrap"
    end

    local scrap = inv:getFirstTypeRecurse("ElectronicsScrap")
    if not scrap then return false, "Need electronics scrap" end
    player:removeFromHands(scrap)
    inv:Remove(scrap)
    if sendRemoveItemFromContainer then
        sendRemoveItemFromContainer(inv, scrap)
    end

    local perk = Perks and Perks.Electricity
    local skill = (perk and player:getPerkLevel(perk)) or 0
    local add = 4 + math.floor(skill / 2)
    record.condition = math.min(100, condition + add)
    if addXp and perk then
        addXp(player, perk, 5)
    end
    return true
end

local function getZoneForSquare(x, y)
    if EPR.Zones and EPR.Zones.GetZoneAt then
        local zoneName = EPR.Zones.GetZoneAt(x, y)
        return zoneName
    end
    return nil
end

local buildingElecApi = nil  -- nil=unchecked, "setHasElectricity", "setElectricity", or false=unavailable

local function setBuildingPower(building, powered)
    if not building then return end
    if buildingElecApi == nil then
        if type(building.setHasElectricity) == "function" then
            buildingElecApi = "setHasElectricity"
        elseif type(building.setElectricity) == "function" then
            buildingElecApi = "setElectricity"
        else
            buildingElecApi = false
            if EPR.LogDebug then EPR.LogDebug("[EPR] Building electricity API not found") end
        end
    end
    if buildingElecApi == "setHasElectricity" then
        local ok, err = pcall(function() building:setHasElectricity(powered) end)
        if not ok and EPR.LogDebug then EPR.LogDebug("[EPR] setHasElectricity error: " .. tostring(err)) end
    elseif buildingElecApi == "setElectricity" then
        local ok, err = pcall(function() building:setElectricity(powered) end)
        if not ok and EPR.LogDebug then EPR.LogDebug("[EPR] setElectricity error: " .. tostring(err)) end
    end
    if building.setAllLightsActive then
        local _ok, _err = pcall(function() building:setAllLightsActive(powered) end)
        if not _ok and EPR.LogDebug then EPR.LogDebug("[EPR] setAllLightsActive error: " .. tostring(_err)) end
    end
end

local buildingWaterApi = nil

local function setBuildingWater(building, watered)
    if not building then return end
    if buildingWaterApi == nil then
        buildingWaterApi = type(building.setHasWater) == "function" and "setHasWater" or false
        if not buildingWaterApi and EPR.LogDebug then EPR.LogDebug("[EPR] Building water API not found") end
    end
    if buildingWaterApi == "setHasWater" then
        local ok, err = pcall(function() building:setHasWater(watered) end)
        if not ok and EPR.LogDebug then EPR.LogDebug("[EPR] setHasWater error: " .. tostring(err)) end
    end
end

local function findExteriorSquareForBuilding(building, fallbackSquare)
    if fallbackSquare and fallbackSquare.isOutside and fallbackSquare:isOutside() then
        return fallbackSquare
    end
    local def = building and building.getDef and building:getDef()
    if not def or not def.getX or not def.getY or not def.getW or not def.getH then
        return nil
    end
    local x1 = def:getX()
    local y1 = def:getY()
    local x2 = x1 + def:getW() - 1
    local y2 = y1 + def:getH() - 1

    for x = x1, x2 do
        local sq1 = getSquare(x, y1, 0)
        if sq1 and sq1.isOutside and sq1:isOutside() then return sq1 end
        local sq2 = getSquare(x, y2, 0)
        if sq2 and sq2.isOutside and sq2:isOutside() then return sq2 end
    end
    for y = y1, y2 do
        local sq1 = getSquare(x1, y, 0)
        if sq1 and sq1.isOutside and sq1:isOutside() then return sq1 end
        local sq2 = getSquare(x2, y, 0)
        if sq2 and sq2.isOutside and sq2:isOutside() then return sq2 end
    end
    return nil
end

local function lightKeyFromSquare(square)
    if not square then return nil end
    return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
end

local function addLightSource(square, radius)
    if not square or not IsoLightSource or not getCell then return nil end
    local r = radius or (EPR.Config and EPR.Config.StreetLightRadius) or 8
    local ok, light = pcall(function()
        return IsoLightSource.new(square:getX(), square:getY(), square:getZ(), 0.9, 0.9, 0.7, r)
    end)
    if not ok or not light then
        if EPR.LogDebug then EPR.LogDebug("[EPR] IsoLightSource.new failed: " .. tostring(light)) end
        return nil
    end
    if light.setActive then
        light:setActive(true)
    end
    local cell = getCell()
    if cell then
        if cell.addLamppost then
            cell:addLamppost(light)
        elseif cell.addLightSource then
            cell:addLightSource(light)
        end
    end
    return light
end

local function removeLightSource(light)
    if not light or not getCell then return end
    local cell = getCell()
    if cell then
        if cell.removeLamppost then
            cell:removeLamppost(light)
        elseif cell.removeLightSource then
            cell:removeLightSource(light)
        end
    end
end

local function findGeneratorOnSquare(square)
    if not square or not square.getObjects then return nil end
    local objects = square:getObjects()
    if not objects then return nil end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            if instanceof and instanceof(obj, "IsoGenerator") then
                return obj
            end
            if obj.getObjectName and obj:getObjectName() == "Generator" then
                return obj
            end
        end
    end
    return nil
end

local function isEPRSpriteGenerator(gen)
    if not gen or not gen.getModData then return false end
    local md = gen:getModData()
    return md and md.EPR_SpriteGenerator == true
end

findEPRSpriteGeneratorOnSquare = function(square)
    if not square or not square.getObjects then return nil end
    local objects = square:getObjects()
    if not objects then return nil end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and instanceof and instanceof(obj, "IsoGenerator") then
            if isEPRSpriteGenerator(obj) then
                return obj
            end
        end
    end
    return nil
end

local function addGeneratorToSquare(square, forceSpawn)
    if not square or not IsoGenerator or not IsoGenerator.new then return nil end
    if not forceSpawn and EPR.Buildings.GeneratorSpawnSupported == false then
        return nil
    end

    local cell = getCell and getCell()
    local item = instanceItem and instanceItem("Base.Generator")
    if not cell or not item then
        EPR.Buildings.GeneratorSpawnSupported = false
        return nil
    end

    local ok, gen = pcall(function() return IsoGenerator.new(item, cell, square) end)
    if not ok or not gen then
        EPR.Buildings.GeneratorSpawnSupported = false
        return nil
    end

    EPR.Buildings.GeneratorSpawnSupported = true
    if gen.getModData then
        gen:getModData().EPR_SpriteGenerator = true
    end
    if gen.transmitCompleteItemToClients then
        gen:transmitCompleteItemToClients()
    end

    return gen
end

local function applyGeneratorRadius(gen, radius)
    if not gen or not radius then return end
    if gen.setRadius then pcall(function() gen:setRadius(radius) end) end
    if gen.setRange then pcall(function() gen:setRange(radius) end) end
    if gen.setGeneratorRadius then pcall(function() gen:setGeneratorRadius(radius) end) end
end

local function configureGenerator(gen, active, radius)
    if not gen then return end
    if gen.setCondition then pcall(function() gen:setCondition(100) end) end
    if gen.setFuel then pcall(function() gen:setFuel(100) end) end
    if gen.setUseDelta then pcall(function() gen:setUseDelta(0) end) end
    if gen.setFuelConsumption then pcall(function() gen:setFuelConsumption(0) end) end
    if gen.setConnected then pcall(function() gen:setConnected(true) end) end
    if gen.setActivated then pcall(function() gen:setActivated(active == true) end) end
    if gen.setNoise then pcall(function() gen:setNoise(0) end) end
    if gen.setSurroundingElectricity then pcall(function() gen:setSurroundingElectricity() end) end
    applyGeneratorRadius(gen, radius)
end

local function removeGeneratorFromSquare(square)
    if not square then return end
    local gen = findEPRSpriteGeneratorOnSquare(square)
    if not gen then return end
    if square.RemoveTileObject then
        pcall(function() square:RemoveTileObject(gen) end)
    elseif square.removeTileObject then
        pcall(function() square:removeTileObject(gen) end)
    end
end

local removeSpriteGeneratorObject

local function findGeneratorSpawnSquare(record)
    if record and record.genX then
        local sq = getSquare(record.genX, record.genY, record.genZ or 0)
        if sq and sq.isOutside and sq:isOutside() then
            return sq
        end
    end

    if record then
        local roof = getSquare(record.x, record.y, (record.z or 0) + 1)
        if roof and roof.isOutside and roof:isOutside() then
            record.genX = roof:getX()
            record.genY = roof:getY()
            record.genZ = roof:getZ()
            return roof
        end
    end

    local fallback = record and getSquare(record.x, record.y, record.z) or nil
    local building = fallback and fallback:getBuilding() or nil
    local exterior = findExteriorSquareForBuilding(building, fallback)
    if exterior then
        record.genX = exterior:getX()
        record.genY = exterior:getY()
        record.genZ = exterior:getZ()
        return exterior
    end

    return nil
end

local function ensureSpriteGeneratorObject(record)
    if not record then return nil end
    if EPR.IsServerContext and not EPR.IsServerContext() then
        return nil
    end
    if EPR.Buildings.GeneratorSpawnSupported == false then
        return nil
    end

    local square = findGeneratorSpawnSquare(record)
    if not square then return nil end
    if square.isOutside and not square:isOutside() then
        removeSpriteGeneratorObject(record)
        return nil
    end

    local gen = findEPRSpriteGeneratorOnSquare(square)
    if not gen then
        gen = addGeneratorToSquare(square, true)
    end

    if gen then
        local radius = record.generatorRadius or (EPR.Config and EPR.Config.GeneratorRangeMax) or 65
        configureGenerator(gen, true, radius)
        if gen.setSprite then
            pcall(function() gen:setSprite("invisible") end)
        end
        if IsoGenerator and IsoGenerator.updateGenerator then
            pcall(function() IsoGenerator.updateGenerator(square) end)
        end
    end

    return gen
end

removeSpriteGeneratorObject = function(record)
    if not record then return end
    local square = nil
    if record.genX then
        square = getSquare(record.genX, record.genY, record.genZ or 0)
    end
    if not square then
        square = getSquare(record.x, record.y, record.z)
    end
    if not square then return end

    local gen = findEPRSpriteGeneratorOnSquare(square)
    if gen and gen.setActivated then
        pcall(function() gen:setActivated(false) end)
    end
    if gen and gen.setSurroundingElectricity then
        pcall(function() gen:setSurroundingElectricity() end)
    end
    if gen then
        if square.RemoveTileObject then
            pcall(function() square:RemoveTileObject(gen) end)
        elseif square.removeTileObject then
            pcall(function() square:removeTileObject(gen) end)
        end
        if IsoGenerator and IsoGenerator.updateGenerator then
            pcall(function() IsoGenerator.updateGenerator(square) end)
        end
    end
end

function EPR.Buildings.EnsureGenerator(record, active)
    if not record then return nil end
    if EPR.IsServerContext and not EPR.IsServerContext() then
        return nil
    end
    if EPR.Buildings.GeneratorSpawnSupported == false then
        return nil
    end

    local square = getSquare(record.x, record.y, record.z)
    if not square then return nil end

    local gen = findEPRSpriteGeneratorOnSquare(square)
    if not gen then
        -- Only spawn a new EPR generator if no generator of any kind is already here.
        -- Calling configureGenerator on a user-placed generator would zero its fuel
        -- consumption and corrupt external mod tracking (e.g. PoweredBuildings FuelManager).
        if not findGeneratorOnSquare(square) then
            gen = addGeneratorToSquare(square)
        end
    end
    if gen then
        configureGenerator(gen, active, record.generatorRadius)
    end

    return gen
end

function EPR.Buildings.RemoveGenerator(record)
    if not record then return end
    if EPR.IsServerContext and not EPR.IsServerContext() then
        return
    end
    local square = getSquare(record.x, record.y, record.z)
    if not square then return end
    removeGeneratorFromSquare(square)
end

function EPR.Buildings.IsZoneOnline(zoneName)
    local power = EPR.PoweredZones and EPR.PoweredZones[zoneName] == true
    local water = EPR.WaterZones and EPR.WaterZones[zoneName] == true
    return power or water
end

function EPR.Buildings.GetPowerBlockReason(square)
    if not square then return "No square" end
    local globalOverride = EPR.PowerController and EPR.PowerController.globalOverride
    local ibCompat = EPR.PowerController and EPR.PowerController.IBCompatEnabled and EPR.PowerController.IBCompatEnabled()
    -- Return nil (no block) when EPR is not managing power at all
    if not globalOverride and not ibCompat then
        return nil
    end

    -- IB compat only: do not block while IB hasn't actually triggered a blackout yet
    -- (IB defines its globals even when power is still on, which would otherwise trip the zone check)
    if ibCompat and not globalOverride and not ImmersiveBlackouts_isBlackout then
        return nil
    end

    local building = square.getBuilding and square:getBuilding() or nil
    if building then
        local key = getBuildingKey(building, square)
        if key and EPR.Buildings.IsBuildingPoweredBySpriteGenerator(key, building) then
            return nil
        end
    end

    if CheckPowerOverrides(square) then return nil end

    local zoneName = getZoneForSquare(square:getX(), square:getY())
    if not zoneName then
        return nil  -- Outside all EPR-managed zones; fall back to vanilla behaviour
    end
    if not (EPR.PoweredZones and EPR.PoweredZones[zoneName] == true) then
        return "Zone is offline"
    end
    if building then
        local key = getBuildingKey(building, square)
        if key and EPR.Buildings.IsBuildingConnected(key) then
            return nil
        end
        if EPR.Buildings.IsSquareConnected(square) then
            return nil
        end
        return "Building not connected"
    end

    local key = lightKeyFromSquare(square)
    if key and EPR.StreetLights and EPR.StreetLights.Connected and EPR.StreetLights.Connected[key] then
        return nil
    end

    return "Not connected"
end

function EPR.Buildings.GetWaterBlockReason(square)
    if not square then return "No square" end
    local globalOverride = EPR.PowerController and EPR.PowerController.globalOverride
    local ibCompat = EPR.PowerController and EPR.PowerController.IBCompatEnabled and EPR.PowerController.IBCompatEnabled()
    if not globalOverride and not ibCompat then
        return nil
    end

    -- IB compat only: do not block while IB hasn't actually shut off water yet
    -- (IB defines its globals even when water is still on, which would otherwise trip the zone check)
    if ibCompat and not globalOverride and not ImmersiveBlackouts_isWaterShut then
        return nil
    end

    local zoneName = getZoneForSquare(square:getX(), square:getY())
    if not zoneName then
        return nil  -- Outside all EPR-managed zones; fall back to vanilla behaviour
    end
    if not (EPR.WaterZones and EPR.WaterZones[zoneName] == true) then
        -- Water treatment plant not repaired yet; EPR keeps WaterShutModifier at INT_MAX so
        -- vanilla water is unlimited — don't block, let vanilla behaviour through.
        return nil
    end

    local building = square.getBuilding and square:getBuilding() or nil
    if building then
        local key = getBuildingKey(building, square)
        if key and EPR.Buildings.IsBuildingConnected(key) then
            return nil
        end
        if EPR.Buildings.IsSquareConnected(square) then
            return nil
        end
        return "Building not connected"
    end

    return "Not connected"
end

function EPR.Buildings.IsPowerAllowedAtSquare(square)
    return EPR.Buildings.GetPowerBlockReason(square) == nil
end

function EPR.Buildings.IsWaterAllowedAtSquare(square)
    return EPR.Buildings.GetWaterBlockReason(square) == nil
end

local function turnOffSquareDevices(square)
    if not square or not square.getObjects then return end
    if CheckPowerOverrides(square) then return end
    local objects = square:getObjects()
    if not objects then return end

    local function isBatteryPowered(data)
        if not data then return false end
        if data.getIsBatteryPowered and data:getIsBatteryPowered() then
            if data.getHasBattery and data:getHasBattery() then
                return true
            end
        end
        return false
    end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            local skip = false
            if obj.getDeviceData then
                local data = obj:getDeviceData()
                if data and data.getIsTurnedOn and data.setIsTurnedOn then
                    if isBatteryPowered(data) then
                        skip = true
                    end
                    if not skip and data:getIsTurnedOn() then
                        pcall(function() data:setIsTurnedOn(false) end)
                    end
                end
            end

            if obj.getItem then
                local item = obj:getItem()
                if item and item.getDeviceData then
                    local data = item:getDeviceData()
                    if data and data.getIsTurnedOn and data.setIsTurnedOn then
                        if isBatteryPowered(data) then
                            skip = true
                        end
                        if not skip and data:getIsTurnedOn() then
                            pcall(function() data:setIsTurnedOn(false) end)
                        end
                    end
                end
            end

            if not skip and instanceof and instanceof(obj, "IsoLightSwitch") then
                if obj.setActivated then
                    pcall(function() obj:setActivated(false) end)
                end
            end

            if not skip and obj.toggleLightSource then
                pcall(function() obj:toggleLightSource(false) end)
            end

            if not skip and obj.getLightSource then
                local source = obj:getLightSource()
                if source and source.setActive then
                    pcall(function() source:setActive(false) end)
                end
            end
        end
    end
end

local function getFridgeTypeLookup()
    local types = (EPR.Config and EPR.Config.FridgeContainerTypes) or { "fridge", "freezer" }
    local lookup = {}
    for _, name in ipairs(types) do
        if name then
            lookup[string.lower(tostring(name))] = true
        end
    end
    return lookup
end

local function isFridgeContainer(container, lookup)
    if not container or not container.getType then return false end
    local ctype = container:getType()
    if not ctype then return false end
    return lookup[string.lower(tostring(ctype))] == true
end

local function forEachPlayer(callback)
    local players = getOnlinePlayers and getOnlinePlayers()
    if players and players:size() > 0 then
        for i = 0, players:size() - 1 do
            callback(players:get(i))
        end
        return
    end
    local player = getPlayer and getPlayer()
    if player then
        callback(player)
    end
end

local function processFridgeSpoil()
    if not (EPR.PowerController and EPR.PowerController.globalOverride) then
        return
    end
    if not (EPR.IsServerContext and EPR.IsServerContext()) then
        return
    end
    if not getGameTime then return end

    local gameTime = getGameTime()
    if not gameTime then return end
    local now = gameTime:getWorldAgeHours()

    local intervalMinutes = (EPR.Config and EPR.Config.FridgeSpoilIntervalMinutes) or 60
    local intervalHours = intervalMinutes / 60
    if not EPR.Buildings.LastFridgeSpoilHours then
        EPR.Buildings.LastFridgeSpoilHours = now
        return
    end
    local deltaHours = now - EPR.Buildings.LastFridgeSpoilHours
    if deltaHours < intervalHours then
        return
    end
    EPR.Buildings.LastFridgeSpoilHours = now

    local multiplier = (EPR.Config and EPR.Config.FridgeSpoilMultiplier) or 1.0
    if multiplier <= 0 then return end

    local lookup = getFridgeTypeLookup()
    local radius = (EPR.Config and EPR.Config.FridgeSweepRadius) or 12

    forEachPlayer(function(player)
        if not player then return end
        local px = math.floor(player:getX())
        local py = math.floor(player:getY())
        local pz = math.floor(player:getZ())

        for x = px - radius, px + radius do
            for y = py - radius, py + radius do
                local square = getSquare(x, y, pz)
                if square then
                    local reason = EPR.Buildings.GetPowerBlockReason(square)
                    if reason then
                        local objects = square:getObjects()
                        if objects then
                            for i = 0, objects:size() - 1 do
                                local obj = objects:get(i)
                                if obj and obj.getContainer then
                                    local container = obj:getContainer()
                                    if isFridgeContainer(container, lookup) then
                                        local items = container:getItems()
                                        if items then
                                            for j = 0, items:size() - 1 do
                                                local item = items:get(j)
                                                if item and instanceof(item, "Food") then
                                                    local age = item:getAge()
                                                    item:setAge(age + (deltaHours * multiplier))
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function getMaintenanceConfig()
    local days = (EPR.Config and EPR.Config.BuildingMaintenanceDays) or 14
    if SandboxVars and SandboxVars.EPR and type(SandboxVars.EPR.BuildingMaintenanceDays) == "number" then
        days = SandboxVars.EPR.BuildingMaintenanceDays
    end
    local flickerHours = (EPR.Config and EPR.Config.BuildingFlickerHours) or 24
    return days, flickerHours
end

-- Sandbox-configurable scaling for building-connection maintenance item costs.
local function getMaintenancePartMultiplier()
    if SandboxVars and SandboxVars.EPR and type(SandboxVars.EPR.MaintenancePartMultiplier) == "number" then
        return SandboxVars.EPR.MaintenancePartMultiplier
    end
    return 1.0
end

local function scaledMaintenanceCount(count)
    return math.max(1, math.ceil((count or 1) * getMaintenancePartMultiplier()))
end

function EPR.Buildings.GetMaintenanceItems()
    if EPR.Config and EPR.Config.BuildingMaintenanceItems then
        return EPR.Config.BuildingMaintenanceItems
    end
    return {}
end

function EPR.Buildings.PlayerHasElectricalSkill(player, requiredLevel)
    if not player then return false end
    if EPR.IsDebugMode and EPR.IsDebugMode() then
        return true
    end
    local perk = Perks and Perks.Electricity
    if not perk then return false end
    return player:getPerkLevel(perk) >= requiredLevel
end

function EPR.Buildings.PlayerHasSpriteGeneratorSkill(player)
    if EPR.IsDebugMode and EPR.IsDebugMode() then
        return true
    end
    return EPR.Buildings.PlayerHasElectricalSkill(player, 3)
end

function EPR.Buildings.PlayerHasSpriteGeneratorTools(player)
    if EPR.IsDebugMode and EPR.IsDebugMode() then
        return true
    end
    if not player then return false end
    local inv = player:getInventory()
    if not inv then return false end

    local hasScrewdriver = inv:getCountTypeRecurse("Base.Screwdriver") > 0
    local hasWrench = inv:getCountTypeRecurse("Base.Wrench") > 0 or inv:getCountTypeRecurse("Base.PipeWrench") > 0
    local hasPliers = inv:getCountTypeRecurse("Base.Pliers") > 0

    return hasScrewdriver and hasWrench and hasPliers
end

function EPR.Buildings.SpriteGeneratorsUseVirtualOnly()
    if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.SpriteGeneratorVirtualOnly ~= nil then
        return SandboxVars.EPR.SpriteGeneratorVirtualOnly == true
    end
    return true
end

function EPR.Buildings.CanMaintain(player)
    local items = EPR.Buildings.GetMaintenanceItems()
    if not player or not items then return false, "No items defined" end

    local inv = player:getInventory()
    if not inv then return false, "No inventory" end

    for _, req in ipairs(items) do
        local itemType = req.item
        local count = scaledMaintenanceCount(req.count or 1)
        if itemType and count > 0 then
            if inv:getCountTypeRecurse(itemType) < count then
                return false, "Missing items"
            end
        end
    end
    return true
end

function EPR.Buildings.GetMaintenanceMissingItems(player)
    local items = EPR.Buildings.GetMaintenanceItems()
    if not player or not items then return {} end

    local inv = player:getInventory()
    if not inv then return {} end

    local missing = {}
    for _, req in ipairs(items) do
        local itemType = req.item
        local count = scaledMaintenanceCount(req.count or 1)
        if itemType and count > 0 then
            local have = inv:getCountTypeRecurse(itemType)
            if have < count then
                table.insert(missing, { item = itemType, need = count - have })
            end
        end
    end
    return missing
end

function EPR.Buildings.ConsumeMaintenanceItems(player)
    local items = EPR.Buildings.GetMaintenanceItems()
    if not player or not items then return false end

    local inv = player:getInventory()
    if not inv then return false end

    for _, req in ipairs(items) do
        local itemType = req.item
        local count = scaledMaintenanceCount(req.count or 1)
        if itemType and count > 0 then
            for i = 1, count do
                local item = inv:getFirstTypeRecurse(itemType)
                if not item then
                    return false
                end
                inv:Remove(item)
            end
        end
    end
    return true
end

function EPR.Buildings.GetZoneCount(zoneName)
    return EPR.Buildings.ZoneCounts[zoneName] or 0
end

function EPR.Buildings.RebuildZoneCounts()
    EPR.Buildings.ZoneCounts = {}
    for _, record in pairs(EPR.Buildings.Connected) do
        local zone = record.zone
        if zone then
            EPR.Buildings.ZoneCounts[zone] = (EPR.Buildings.ZoneCounts[zone] or 0) + 1
        end
    end
end

function EPR.Buildings.CanConnectZone(zoneName)
    if not zoneName then
        return false, "No zone found"
    end
    if not EPR.Buildings.IsZoneOnline(zoneName) then
        return false, "Zone is offline"
    end
    local cap = getZoneCap()
    if cap > 0 then
        local count = EPR.Buildings.GetZoneCount(zoneName)
        if count >= cap then
            return false, "Zone building cap reached"
        end
    end
    return true
end

function EPR.Buildings.GetBuildingRecord(buildingKey)
    return EPR.Buildings.Connected[buildingKey]
end

function EPR.Buildings.IsBuildingConnected(buildingKey)
    return EPR.Buildings.Connected[buildingKey] ~= nil
end

function EPR.Buildings.IsSquareConnected(square)
    if not square then return false end
    if not EPR.Buildings.Connected then return false end
    local sx, sy, sz = square:getX(), square:getY(), square:getZ()
    for _, record in pairs(EPR.Buildings.Connected) do
        if record and record.x == sx and record.y == sy and record.z == sz then
            return true
        end
    end
    return false
end

function EPR.Buildings.ConnectBuilding(building, square, zoneName)
    local key = getBuildingKey(building, square)
    if not key then return nil, "No building key" end
    if EPR.Buildings.Connected[key] then
        return key, "Already connected"
    end

    local record = {
        key = key,
        x = square and square:getX() or 0,
        y = square and square:getY() or 0,
        z = square and square:getZ() or 0,
        zone = zoneName,
        lastMaintenanceHours = (function() local gt = getGameTime and getGameTime(); return gt and gt:getWorldAgeHours() or 0 end)(),
        maintenanceStatus = "ok",
        generatorRadius = (EPR.Config and EPR.Config.GeneratorRangeMax) or 65,
    }

    EPR.Buildings.Connected[key] = record
    EPR.Buildings.ZoneCounts[zoneName] = (EPR.Buildings.ZoneCounts[zoneName] or 0) + 1
    EPR.ConnectedBuildings = EPR.Buildings.Connected

    EPR.Buildings.ApplyBuildingRecord(record)

    return key, nil
end

function EPR.Buildings.DisconnectBuilding(buildingKey)
    local record = EPR.Buildings.Connected[buildingKey]
    if not record then return false end

    local square = getSquare(record.x, record.y, record.z)
    local building = square and square:getBuilding()
    setBuildingPower(building, false)
    setBuildingWater(building, false)
    EPR.Buildings.RemoveGenerator(record)

    EPR.Buildings.Connected[buildingKey] = nil
    if record.zone then
        EPR.Buildings.ZoneCounts[record.zone] = math.max(0, (EPR.Buildings.ZoneCounts[record.zone] or 1) - 1)
    end
    EPR.ConnectedBuildings = EPR.Buildings.Connected

    return true
end

function EPR.Buildings.ApplyBuildingRecord(record)
    if not record then return end
    local square = getSquare(record.x, record.y, record.z)
    local building = square and square:getBuilding()
    if not building then return end
    local spritePowered = EPR.Buildings.IsBuildingPoweredBySpriteGenerator(record.key, building)

    local zone = record.zone or getZoneForSquare(record.x, record.y)
    local powered = zone and EPR.PoweredZones and EPR.PoweredZones[zone] == true
    local watered = zone and EPR.WaterZones and EPR.WaterZones[zone] == true

    local _gt1 = getGameTime and getGameTime()
    local now = _gt1 and _gt1:getWorldAgeHours() or 0
    local days, flickerHours = getMaintenanceConfig()
    local last = record.lastMaintenanceHours or 0
    local due = last + (days * 24)
    local flickerUntil = due + flickerHours

    if now >= due and now < flickerUntil then
        record.maintenanceStatus = "flicker"
        local flickerOn = (math.floor(now * 2) % 2) == 0
        setBuildingPower(building, powered and flickerOn)
        EPR.Buildings.EnsureGenerator(record, powered and flickerOn)
        setBuildingWater(building, watered)
        return
    end

    if now >= flickerUntil then
        record.maintenanceStatus = "expired"
        setBuildingPower(building, false)
        setBuildingWater(building, false)
        EPR.Buildings.EnsureGenerator(record, false)
        return
    end

    setBuildingPower(building, powered)
    setBuildingWater(building, watered)
    EPR.Buildings.EnsureGenerator(record, powered)

    if spritePowered then
        setBuildingPower(building, true)
    end
end

function EPR.Buildings.SetGeneratorRadius(buildingKey, radius)
    local record = EPR.Buildings.Connected[buildingKey]
    if not record then return false end
    if EPR.Buildings.GeneratorSpawnSupported == false then
        return false
    end
    record.generatorRadius = radius
    EPR.Buildings.ApplyBuildingRecord(record)
    EPR.ConnectedBuildings = EPR.Buildings.Connected
    return true
end

function EPR.Buildings.ApplyZonePower(zoneName, powered)
    for _, record in pairs(EPR.Buildings.Connected) do
        if record.zone == zoneName then
            local square = getSquare(record.x, record.y, record.z)
            local building = square and square:getBuilding()
            if powered then
                setBuildingPower(building, true)
            else
                local spritePowered = EPR.Buildings.IsBuildingPoweredBySpriteGenerator(record.key, building)
                setBuildingPower(building, spritePowered == true)
            end
        end
    end

    if EPR.StreetLights and EPR.StreetLights.ApplyZonePower then
        EPR.StreetLights.ApplyZonePower(zoneName, powered)
    end
    EPR.Buildings.simulationDirty = true
end

function EPR.Buildings.ApplyZoneWater(zoneName, watered)
    for _, record in pairs(EPR.Buildings.Connected) do
        if record.zone == zoneName then
            local square = getSquare(record.x, record.y, record.z)
            local building = square and square:getBuilding()
            setBuildingWater(building, watered)
        end
    end
    EPR.Buildings.simulationDirty = true
end

function EPR.Buildings.ApplyAllZones()
    for _, record in pairs(EPR.Buildings.Connected) do
        EPR.Buildings.ApplyBuildingRecord(record)
    end
    if EPR.StreetLights and EPR.StreetLights.ApplyAll then
        EPR.StreetLights.ApplyAll()
    end
    if EPR.Buildings.ApplyAllSpriteGenerators then
        EPR.Buildings.ApplyAllSpriteGenerators()
    end
end

function EPR.Buildings.ApplySimulationForAllZones()
    if not EPR.Buildings.simulationDirty then return end
    EPR.Buildings.simulationDirty = false
    local active = (EPR.PowerController and EPR.PowerController.globalOverride) or
        (EPR.PowerController and EPR.PowerController.IBCompatEnabled and EPR.PowerController.IBCompatEnabled())
    if not active then return end
    if not (EPR.Zones and EPR.Zones.Definitions) then return end

    local meta = getWorld and getWorld():getMetaGrid()
    if not meta or not meta.getBuildings then return end
    local buildings = meta:getBuildings()
    if not buildings then return end

    for i = 0, buildings:size() - 1 do
        local b = buildings:get(i)
        local def = b and b.getDef and b:getDef()
        if def and def.getX and def.getY and def.getW and def.getH then
            local bx = def:getX() + math.floor(def:getW() / 2)
            local by = def:getY() + math.floor(def:getH() / 2)
            local zoneName = EPR.Zones.GetZoneAt and EPR.Zones.GetZoneAt(bx, by) or nil
            if not zoneName or not EPR.Buildings.IsZoneOnline(zoneName) then
                local square = getSquare(bx, by, 0)
                local building = square and square:getBuilding() or nil
                if building then
                    local key = getBuildingKey(b, square)
                    local spritePowered = key and EPR.Buildings.IsBuildingPoweredBySpriteGenerator(key, building)
                    if not spritePowered then
                        setBuildingPower(building, false)
                        setBuildingWater(building, false)
                        if building.setAllLightsActive then
                            pcall(function() building:setAllLightsActive(false) end)
                        end
                    end
                end
            end
        end
    end
end

function EPR.Buildings.OnLoaded()
    EPR.Buildings.Connected = EPR.ConnectedBuildings or {}
    EPR.StreetLights.Connected = EPR.ConnectedStreetLights or {}
    EPR.SpriteGenerators = EPR.SpriteGenerators or {}
    EPR.Buildings.RebuildZoneCounts()
    EPR.Buildings.ApplyAllZones()
end

function EPR.Buildings.HookSpriteGenerator(square, spriteName)
    if not square then return nil, "No square" end
    if not EPR.Buildings.IsSpriteGeneratorSprite(spriteName) then
        return nil, "Invalid generator sprite"
    end

    local building = square.getBuilding and square:getBuilding() or nil
    if not building then
        return nil, "No building found"
    end

    local key = getSpriteGeneratorKey(square:getX(), square:getY(), square:getZ())
    if EPR.SpriteGenerators and EPR.SpriteGenerators[key] then
        return EPR.SpriteGenerators[key], "Already hooked"
    end

    local buildingKey = getBuildingKey(building, square)
    local record = {
        key = key,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        buildingKey = buildingKey,
        buildingId = getBuildingId(building),
        buildingBoundsKey = getBuildingBoundsKey(building),
        generatorRadius = (EPR.Config and EPR.Config.GeneratorRangeMax) or 65,
        fuel = 100,
        condition = 100,
        lastRuntimeHours = (function() local gt = getGameTime and getGameTime(); return gt and gt:getWorldAgeHours() or 0 end)(),
        active = false,
        hooked = true,
        sprite = spriteName,
    }

    EPR.SpriteGenerators = EPR.SpriteGenerators or {}
    EPR.SpriteGenerators[key] = record
    return record, nil
end

function EPR.Buildings.ToggleSpriteGenerator(genKey, active)
    if not genKey or not EPR.SpriteGenerators then return nil, "No generator" end
    local record = EPR.SpriteGenerators[genKey]
    if not record then return nil, "Generator not hooked" end
    record.active = active == true
    EPR.Buildings.ApplySpriteGeneratorRecord(record)
    if EPR.PowerController and EPR.PowerController.UpdateNetworks then
        EPR.PowerController.UpdateNetworks()
    end
    return record, nil
end

function EPR.Buildings.ApplySpriteGeneratorRecord(record)
    if not record then return end
    local square = getSquare(record.x, record.y, record.z)
    local building = square and square:getBuilding() or nil
    if not building then return end
    if not record.buildingId then
        record.buildingId = getBuildingId(building)
    end
    if not record.buildingBoundsKey then
        record.buildingBoundsKey = getBuildingBoundsKey(building)
    end

    if record.active then
        local virtualOnly = EPR.Buildings.SpriteGeneratorsUseVirtualOnly and EPR.Buildings.SpriteGeneratorsUseVirtualOnly()
        local fuel = EPR.Buildings.GetSpriteGeneratorFuel(record)
        local condition = EPR.Buildings.GetSpriteGeneratorCondition(record)
        if virtualOnly and (fuel <= 0 or condition <= 0) then
            if EPR.IsServerContext and EPR.IsServerContext() then
                record.active = false
            end
        else
            if virtualOnly then
                removeSpriteGeneratorObject(record)
            else
                ensureSpriteGeneratorObject(record)
            end
            setBuildingPower(building, true)
            if building.setAllLightsActive then
                pcall(function() building:setAllLightsActive(true) end)
            end
            return
        end
    end

    removeSpriteGeneratorObject(record)

    local buildingKey = record.buildingKey or getBuildingKey(building, square)
    local connectedRecord = buildingKey and EPR.Buildings.GetBuildingRecord and EPR.Buildings.GetBuildingRecord(buildingKey)
    if connectedRecord then
        EPR.Buildings.ApplyBuildingRecord(connectedRecord)
    else
        setBuildingPower(building, false)
    end
end

function EPR.Buildings.ApplyAllSpriteGenerators()
    if not EPR.SpriteGenerators then return end
    for _, record in pairs(EPR.SpriteGenerators) do
        EPR.Buildings.ApplySpriteGeneratorRecord(record)
    end
end

function EPR.Buildings.UpdateMaintenance()
    local _gtm = getGameTime and getGameTime()
    local now = _gtm and _gtm:getWorldAgeHours() or 0
    local days, flickerHours = getMaintenanceConfig()
    local changed = false

    for key, record in pairs(EPR.Buildings.Connected) do
        if record.lastMaintenanceHours == nil then
            record.lastMaintenanceHours = now
            changed = true
        end

        local due = record.lastMaintenanceHours + (days * 24)
        local flickerUntil = due + flickerHours

        if now >= flickerUntil then
            if EPR.IsServerContext and EPR.IsServerContext() then
                local removed = EPR.Buildings.DisconnectBuilding(key)
                if removed then
                    changed = true
                    if EPR.Server and EPR.Server.SendBuildingUpdate then
                        EPR.Server.SendBuildingUpdate(key, nil, true)
                    end
                end
            else
                EPR.Buildings.ApplyBuildingRecord(record)
            end
        elseif now >= due then
            record.maintenanceStatus = "flicker"
            EPR.Buildings.ApplyBuildingRecord(record)
            changed = true
        else
            if record.maintenanceStatus ~= "ok" then
                record.maintenanceStatus = "ok"
                changed = true
            end
        end
    end

    if changed then
        EPR.ConnectedBuildings = EPR.Buildings.Connected
    end
end

function EPR.Buildings.UpdateSpriteGeneratorRuntime()
    if EPR.Buildings.SpriteGeneratorsUseVirtualOnly and not EPR.Buildings.SpriteGeneratorsUseVirtualOnly() then
        return
    end
    if EPR.IsServerContext and not EPR.IsServerContext() then
        return
    end
    if not EPR.SpriteGenerators then return end

    local _gts = getGameTime and getGameTime()
    local now = _gts and _gts:getWorldAgeHours() or nil
    if not now then return end

    local rate = (SandboxVars and SandboxVars.EPR and SandboxVars.EPR.GeneratorFuelConsumption) or 1.0
    local conditionRate = 0.2 * rate
    for _, record in pairs(EPR.SpriteGenerators) do
        if record and record.active then
            local last = record.lastRuntimeHours or now
            local delta = now - last
            if delta > 0 then
                local fuel = EPR.Buildings.GetSpriteGeneratorFuel(record)
                local condition = EPR.Buildings.GetSpriteGeneratorCondition(record)
                fuel = math.max(0, fuel - (delta * rate))
                condition = math.max(0, condition - (delta * conditionRate))
                record.fuel = fuel
                record.condition = condition
                record.lastRuntimeHours = now

                if fuel <= 0 or condition <= 0 then
                    record.active = false
                end

                if EPR.Buildings.ApplySpriteGeneratorRecord then
                    EPR.Buildings.ApplySpriteGeneratorRecord(record)
                end
                if EPR.Server and EPR.Server.SendSpriteGeneratorUpdate then
                    EPR.Server.SendSpriteGeneratorUpdate(record.key, record, false)
                end
                if EPR.PowerController and EPR.PowerController.UpdateNetworks then
                    EPR.PowerController.UpdateNetworks()
                end
                EPR.SaveData()
            end
        end
    end
end

function EPR.Buildings.ConnectAllInZone(zoneName)
    local ok = EPR.Buildings.IsZoneOnline(zoneName)
    if not ok then
        return 0, "Zone is offline"
    end

    local zoneDef = EPR.Zones and EPR.Zones.Definitions and EPR.Zones.Definitions[zoneName]
    if not zoneDef or not zoneDef.bounds then
        return 0, "Zone not found"
    end

    local meta = getWorld() and getWorld():getMetaGrid()
    if not meta or not meta.getBuildings then
        return 0, "Building list unavailable"
    end

    local buildings = meta:getBuildings()
    if not buildings then
        return 0, "Building list empty"
    end

    local cap = getZoneCap()
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
                    local key = getBuildingKey(b, square)
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

    return connected, nil
end

-- ============================================
-- STREETLIGHTS
-- ============================================

function EPR.StreetLights.IsStreetLight(obj)
    if not obj or not obj.getSprite then return false end
    local sprite = obj:getSprite()
    if not sprite or not sprite.getName then return false end
    local name = string.lower(sprite:getName() or "")
    if name == "" then return false end
    return name:find("streetlight") or name:find("streetlamp") or name:find("lamppost") or name:find("lampost")
end

function EPR.StreetLights.Connect(square, zoneName)
    if not square then return nil end
    local key = lightKeyFromSquare(square)
    if not key then return nil end
    if EPR.StreetLights.Connected[key] then
        return key, "Already connected"
    end

    local record = {
        key = key,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        zone = zoneName,
    }

    EPR.StreetLights.Connected[key] = record
    EPR.ConnectedStreetLights = EPR.StreetLights.Connected
    EPR.StreetLights.ApplyRecord(record)

    return key, nil
end

function EPR.StreetLights.Disconnect(lightKey)
    local record = EPR.StreetLights.Connected[lightKey]
    if not record then return false end

    local source = EPR.StreetLights.ActiveSources[lightKey]
    if source then
        removeLightSource(source)
        EPR.StreetLights.ActiveSources[lightKey] = nil
    end

    EPR.StreetLights.Connected[lightKey] = nil
    EPR.ConnectedStreetLights = EPR.StreetLights.Connected
    return true
end

function EPR.StreetLights.ApplyRecord(record)
    if not record then return end
    local zone = record.zone or getZoneForSquare(record.x, record.y)
    local powered = zone and EPR.PoweredZones and EPR.PoweredZones[zone] == true
    local key = record.key
    local square = getSquare(record.x, record.y, record.z)

    if powered then
        if not EPR.StreetLights.ActiveSources[key] then
            EPR.StreetLights.ActiveSources[key] = addLightSource(square)
        end
    else
        local source = EPR.StreetLights.ActiveSources[key]
        if source then
            removeLightSource(source)
            EPR.StreetLights.ActiveSources[key] = nil
        end
    end
end

function EPR.StreetLights.ApplyZonePower(zoneName, powered)
    for _, record in pairs(EPR.StreetLights.Connected) do
        if record.zone == zoneName then
            EPR.StreetLights.ApplyRecord(record)
        end
    end
end

function EPR.StreetLights.ApplyAll()
    for _, record in pairs(EPR.StreetLights.Connected) do
        EPR.StreetLights.ApplyRecord(record)
    end
end

local function onLoadGridSquare(square)
    if not square then return end

    local building = square.getBuilding and square:getBuilding() or nil
    local zoneName = EPR.Zones and EPR.Zones.GetZoneAt and EPR.Zones.GetZoneAt(square:getX(), square:getY()) or nil
    if building then
        local key = getBuildingKey(building, square)
        local record = key and EPR.Buildings.Connected[key]
        if record then
            EPR.Buildings.ApplyBuildingRecord(record)
        else
            if key and EPR.Buildings.IsBuildingPoweredBySpriteGenerator(key, building) then
                setBuildingPower(building, true)
                return
            end
            local globalOverride = EPR.PowerController and EPR.PowerController.globalOverride == true
            if globalOverride then
                local reason = EPR.Buildings.GetPowerBlockReason(square)
                if reason then
                    setBuildingPower(building, false)
                    setBuildingWater(building, false)
                    if building.setAllLightsActive then
                        pcall(function() building:setAllLightsActive(false) end)
                    end
                    turnOffSquareDevices(square)
                end
            end
        end
    end

    if not building then
        local globalOverride = EPR.PowerController and EPR.PowerController.globalOverride == true
        if globalOverride then
            local reason = EPR.Buildings.GetPowerBlockReason(square)
            if reason then
                turnOffSquareDevices(square)
            end
        end
    end

    local lightKey = lightKeyFromSquare(square)
    local lightRecord = lightKey and EPR.StreetLights.Connected[lightKey]
    if lightRecord then
        EPR.StreetLights.ApplyRecord(lightRecord)
    end
end

if Events and Events.OnLoadGridSquare then
    Events.OnLoadGridSquare.Add(onLoadGridSquare)
end

local tickCounter = 0
local TICK_INTERVAL = 60
local SWEEP_RADIUS = 15
local lastSweepX, lastSweepY, lastSweepZ

local function applyActiveSpriteGenerators()
    if not EPR.SpriteGenerators then return end
    for _, record in pairs(EPR.SpriteGenerators) do
        if record and record.active then
            EPR.Buildings.ApplySpriteGeneratorRecord(record)
        end
    end
end

local function hasActiveSpriteGenerators()
    if not EPR.SpriteGenerators then return false end
    if EPR.Buildings and EPR.Buildings.IsSpriteGeneratorActive then
        for _, record in pairs(EPR.SpriteGenerators) do
            if record and EPR.Buildings.IsSpriteGeneratorActive(record) then
                return true
            end
        end
    else
        for _, record in pairs(EPR.SpriteGenerators) do
            if record and record.active == true then
                return true
            end
        end
    end
    return false
end

local function onTick()
    tickCounter = tickCounter + 1
    if tickCounter < TICK_INTERVAL then return end
    tickCounter = 0

    local spriteActive = hasActiveSpriteGenerators()
    if spriteActive then
        applyActiveSpriteGenerators()
    end

    if not (EPR.PowerController and EPR.PowerController.globalOverride) then
        return
    end

    processFridgeSpoil()

    local player = getPlayer and getPlayer()
    if not player then return end
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    if lastSweepX == px and lastSweepY == py and lastSweepZ == pz then
        return
    end
    lastSweepX, lastSweepY, lastSweepZ = px, py, pz

    for x = px - SWEEP_RADIUS, px + SWEEP_RADIUS do
        for y = py - SWEEP_RADIUS, py + SWEEP_RADIUS do
            local square = getSquare(x, y, pz)
            if square then
                local building = square.getBuilding and square:getBuilding() or nil
                local reason = EPR.Buildings.GetPowerBlockReason(square)
                if building then
                    local key = getBuildingKey(building, square)
                    local record = key and EPR.Buildings.Connected[key]
                    if record then
                        EPR.Buildings.ApplyBuildingRecord(record)
                    else
                        if reason then
                            setBuildingPower(building, false)
                            setBuildingWater(building, false)
                            if building.setAllLightsActive then
                                pcall(function() building:setAllLightsActive(false) end)
                            end
                            turnOffSquareDevices(square)
                        end
                    end
                elseif reason then
                    turnOffSquareDevices(square)
                end
            end
        end
    end
end

if Events and Events.OnTick then
    Events.OnTick.Add(onTick)
end

-- EPR_Compat_PoweredBuildings.lua is auto-executed by the PZ engine after this file
-- (alphabetical order: BuildingGrid < Compat). The pcall(require ...) that was here
-- always failed because PZ's runtime require cannot locate subdirectory files by
-- base-name before they have been indexed. Removed — the compat self-registers via events.

print("[EPR] EPR_BuildingGrid.lua loaded successfully")
