--[[
    EPR Compatibility — PoweredBuildings V2 (buildinggenpowerv2)

    When a building is actively powered by a PB V2 generator, EPR will not
    block context menus or turn off devices inside that building, even if the
    building's EPR zone is offline.

    EPR's PowerOverrideChecks registry is populated once after game start so
    we don't pay a PB V2 detection cost on every tick.
]]--

local function isPBV2Building(square)
    if not PoweredBuildings then return false end
    local SM = PoweredBuildings.Core and PoweredBuildings.Core.StateManager
    if not SM or not SM.GetAllBuildings then return false end

    local building = square and square.getBuilding and square:getBuilding()
    if not building then return false end

    local allBuildings = SM.GetAllBuildings()
    if not allBuildings then return false end

    for _, bdata in pairs(allBuildings) do
        if bdata and bdata.isPowered and bdata.x and bdata.y then
            local bsq = getSquare(bdata.x, bdata.y, bdata.z or 0)
            if bsq and bsq.getBuilding and bsq:getBuilding() == building then
                return true
            end
        end
    end

    return false
end

local registered = false

local function registerOverride()
    if registered then return end
    if not (EPR and EPR.Buildings and EPR.Buildings.RegisterPowerOverride) then return end
    -- Do NOT guard on PoweredBuildings here — isPBV2Building already nil-checks it.
    -- Guarding here caused silent failure when PB initialises its global after OnGameStart.
    EPR.Buildings.RegisterPowerOverride("PoweredBuildings_V2", isPBV2Building)
    registered = true
    print("[EPR Compat] PoweredBuildings V2 power override registered")
end

if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(registerOverride) end
    if Events.OnInitGlobalModData then Events.OnInitGlobalModData.Add(registerOverride) end
end