-- EPR_StormBlackouts: storm-driven random blackouts.
-- During thunderstorms, an online substation has a chance per 10-minute tick
-- of being knocked offline (lightning strike), triggering EPR's normal
-- breakdown flow so the player must repair it.
--
-- Server-only. Sandbox-gated.

if isClient() and not isServer() then return end

print("[EPR StormBlackouts] loading...")

EPR = EPR or {}
EPR.StormBlackouts = EPR.StormBlackouts or {}

-- ============================================================
-- Climate probe (probe-once Java methods to avoid pcall logspam)
-- ============================================================

local _probed = false
local _hasIsThunderStorming = false
local _hasGetIntensity      = false

local function probeClimateOnce()
    if _probed then return end
    local climate = getClimateManager and getClimateManager() or nil
    if not climate then return end
    local ts = climate.getThunderStorm and climate:getThunderStorm() or nil
    if ts then
        _hasIsThunderStorming = ts.isThunderStorming ~= nil
        _hasGetIntensity      = ts.getIntensity      ~= nil
    end
    _probed = true
    print("[EPR StormBlackouts] climate probed: isThunderStorming=" ..
        tostring(_hasIsThunderStorming) .. " getIntensity=" .. tostring(_hasGetIntensity))
end

local function isStormActive()
    probeClimateOnce()
    local climate = getClimateManager and getClimateManager() or nil
    if not climate then return false end
    local ts = climate.getThunderStorm and climate:getThunderStorm() or nil
    if not ts then return false end
    if _hasIsThunderStorming then
        local ok, v = pcall(function() return ts:isThunderStorming() end)
        if ok and v == true then return true end
    end
    if _hasGetIntensity then
        local ok, v = pcall(function() return ts:getIntensity() end)
        if ok and type(v) == "number" and v > 0.0 then return true end
    end
    return false
end

-- Optional: also accept heavy rain as "stormy" if the user opted out of
-- requiring thunder. Heavy rain = climate rainIntensity above ~0.5.
local function isAnyWeatherStormy()
    if isStormActive() then return true end
    local climate = getClimateManager and getClimateManager() or nil
    if not climate then return false end
    local ok, rain = pcall(function() return climate:getRainIntensity() end)
    if ok and type(rain) == "number" and rain >= 0.5 then return true end
    return false
end

-- ============================================================
-- Config from sandbox
-- ============================================================

local function cfg()
    local s = (SandboxVars and SandboxVars.EPR) or {}
    return {
        enabled        = s.StormBlackoutsEnabled ~= false,           -- default ON
        chance         = tonumber(s.StormBlackoutChancePerCheck) or 25, -- 0..100
        requireThunder = s.StormBlackoutRequireThunder ~= false,     -- default ON
    }
end

-- ============================================================
-- Pick a random online substation
-- ============================================================

local function pickOnlineSubstation()
    if not EPR.Substations then return nil, nil end
    local online = {}
    for id, st in pairs(EPR.Substations) do
        if st and st.status == "online" then
            table.insert(online, { id = id, state = st })
        end
    end
    if #online == 0 then return nil, nil end
    local pick = online[ZombRand(#online) + 1]
    return pick.id, pick.state
end

-- ============================================================
-- Tick
-- ============================================================

function EPR.StormBlackouts.OnTenMinutes()
    if not (isServer() or (not isClient() and not isServer())) then return end -- server / host / SP
    local c = cfg()
    if not c.enabled or c.chance <= 0 then return end

    -- Weather gate.
    if c.requireThunder then
        if not isStormActive() then return end
    else
        if not isAnyWeatherStormy() then return end
    end

    -- RNG roll.
    if ZombRand(100) >= c.chance then return end

    -- Pick target.
    local fid, state = pickOnlineSubstation()
    if not fid or not state then return end

    -- Trigger EPR's existing breakdown flow (status->offline, components->damaged).
    if EPR.Maintenance and EPR.Maintenance.TriggerBreakdown then
        EPR.Maintenance.TriggerBreakdown(fid, state, "power")
    else
        state.status = "offline"
        state.health = 0
    end

    -- Drop zones this facility was powering so lights actually go out.
    local facility = EPR.Zones and EPR.Zones.GetFacility and EPR.Zones.GetFacility(fid)
    if facility and facility.powersZones then
        for _, zoneName in ipairs(facility.powersZones) do
            EPR.PoweredZones[zoneName] = false
            if EPR.Buildings and EPR.Buildings.ApplyZonePower then
                EPR.Buildings.ApplyZonePower(zoneName, false)
            end
            if EPR.Server and EPR.Server.BroadcastZonePowerChange then
                EPR.Server.BroadcastZonePowerChange(zoneName, false)
            end
        end
    end
    if EPR.PowerController and EPR.PowerController.UpdateNetworks then
        EPR.PowerController.UpdateNetworks()
    end

    -- Save + broadcast facility update + notify players.
    if EPR.SaveData then EPR.SaveData() end
    if EPR.Server and EPR.Server.BroadcastFacilityUpdate then
        EPR.Server.BroadcastFacilityUpdate(fid, "power", state)
    end
    -- NB: BroadcastFacilityStartupFlicker is a power-ON flicker (Immersive
    -- Blackouts ends with lights restored). Not what we want for a strike.

    local facName = fid
    if EPR.Zones and EPR.Zones.GetFacility then
        local f = EPR.Zones.GetFacility(fid)
        if f and f.name then facName = f.name end
    end

    print("[EPR StormBlackouts] Lightning strike: " .. tostring(facName) ..
        " (" .. fid .. ") knocked offline")

    -- Tell every player in chat.
    local players = getOnlinePlayers and getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p and p.Say then
                pcall(function() p:Say("A lightning bolt strikes " .. facName .. "!") end)
            end
        end
    end
end

-- ============================================================
-- Wire to EveryTenMinutes
-- ============================================================

if Events and Events.EveryTenMinutes then
    Events.EveryTenMinutes.Add(EPR.StormBlackouts.OnTenMinutes)
    print("[EPR StormBlackouts] registered on EveryTenMinutes")
else
    print("[EPR StormBlackouts] WARN: EveryTenMinutes event unavailable")
end

print("[EPR StormBlackouts] loaded")
