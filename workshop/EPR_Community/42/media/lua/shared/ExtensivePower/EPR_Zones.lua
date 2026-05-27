--[[
    Extensive Power Rework - Zone & Facility Definitions

    Defines the power grid hierarchy:
    1. Louisville Combined Plant (PREREQUISITE) - must be repaired first
    2. Regional substations and water treatment - unlocked after Louisville

    Facility Coverage:
    - Louisville Plant: Power for Louisville (prerequisite)
    - Louisville South Sub: Power for West Point, Valley Station, LV Airport
    - Muldraugh Sub: Power for Muldraugh, Rosewood, March Ridge, Fallas Lake
    - Riverside Relay: Power for Riverside
    - Irvington Substation: Power for Irvington, Echo Creek, Ekron, Brandenburg
    - Rosewood Water: Water for entire map

    Component System:
    - Each facility has fixed repair point locations
    - Components can span multiple tiles (clicking any tile works)
    - Some facilities may not have all component types
]]--

local function logDebug(message)
    if EPR and EPR.IsDebugMode and EPR.IsDebugMode() then
        print(message)
    end
end

logDebug("[EPR] EPR_Zones.lua loading...")

EPR = EPR or {}
EPR.Zones = {}

-- ============================================
-- COMPONENT DEFINITIONS
-- ============================================

EPR.Components = {
    -- Main console component (always repaired first)
    ControlPanel = {
        name = "Control Panel",
        repairSkill = "Electricity",
        baseTime = 90,
        description = "Main control and monitoring panel",
        isMainConsole = true,  -- Marks this as the main console component
    },
    -- Field components (randomly selected for Phase 2)
    Transformer = {
        name = "Transformer",
        repairSkill = "Electricity",
        baseTime = 120,
        description = "High-voltage transformer unit",
    },
    CircuitBreakers = {
        name = "Circuit Breakers",
        repairSkill = "Mechanics",
        baseTime = 60,
        description = "High-amperage circuit breaker array",
    },
    CoolingSystem = {
        name = "Cooling System",
        repairSkill = "Mechanics",
        baseTime = 45,
        description = "Equipment cooling and ventilation system",
    },
    PowerConduits = {
        name = "Power Conduits",
        repairSkill = "Electricity",
        baseTime = 75,
        description = "High-voltage power distribution cables",
    },
    SwitchGear = {
        name = "Switch Gear",
        repairSkill = "Electricity",
        baseTime = 50,
        description = "Main power switching equipment",
    },
    BackupGenerator = {
        name = "Backup Generator",
        repairSkill = "Mechanics",
        baseTime = 80,
        description = "Emergency backup power unit",
    },
    GroundingSystem = {
        name = "Grounding System",
        repairSkill = "Electricity",
        baseTime = 40,
        description = "Electrical grounding and safety system",
    },
    VoltageRegulator = {
        name = "Voltage Regulator",
        repairSkill = "Electricity",
        baseTime = 55,
        description = "Voltage stabilization equipment",
    },
}

-- List of field components that can be randomly selected
EPR.FieldComponents = {
    "Transformer", "CircuitBreakers", "CoolingSystem", "PowerConduits",
    "SwitchGear", "BackupGenerator", "GroundingSystem", "VoltageRegulator"
}

-- Component order for UI display (ControlPanel always first, then field components)
EPR.ComponentOrder = {"ControlPanel", "Transformer", "CircuitBreakers", "CoolingSystem", "PowerConduits", "SwitchGear", "BackupGenerator", "GroundingSystem", "VoltageRegulator"}

-- ============================================
-- FACILITY DEFINITIONS WITH EXACT COORDINATES
-- ============================================

EPR.Zones.Facilities = {
    -- ==========================================
    -- LOUISVILLE POWER PLANT
    -- Main power facility - part of power network
    -- ==========================================
    LouisvillePlant = {
        id = "louisville_plant",
        name = "Louisville Power Plant",
        type = "power",
        x = 12120,  -- Center/terminal location
        y = 1617,
        z = 0,
        isPrerequisite = true,
        requiresPrerequisite = false,
        repairDifficulty = 0.6,
        network = "power",  -- Part of power network
        description = "Main power generation facility. Required for the power network.",
        powersZones = {"Louisville"},

        -- Fixed component locations
        components = {
            Transformer = {
                tiles = {
                    {x = 12112, y = 1628},
                },
            },
            ControlPanel = {
                tiles = {
                    {x = 12120, y = 1617},
                },
            },
            CircuitBreakers = {
                tiles = {
                    {x = 12107, y = 1624},
                },
            },
        },
    },

    -- ==========================================
    -- LOUISVILLE SOUTH ELECTRICAL SUBSTATION
    -- Part of power network (east side)
    -- ==========================================
    LouisvilleSouthSubstation = {
        id = "louisville_south_substation",
        name = "Louisville South Substation",
        type = "power",
        x = 14732,  -- Control panel location
        y = 4083,
        z = 0,
        isPrerequisite = false,
        requiresPrerequisite = true,
        repairDifficulty = 1.0,
        network = "power",  -- Part of power network
        description = "Eastern substation. Required for the power network.",
        powersZones = {"WestPoint", "ValleyStation", "LouisvilleAirport"},

        components = {
            Transformer = {
                -- Large transformer array spanning multiple tiles
                tiles = {
                    {x = 14754, y = 4086}, {x = 14753, y = 4086},
                    {x = 14760, y = 4086}, {x = 14759, y = 4086},
                    {x = 14762, y = 4086}, {x = 14763, y = 4086},
                    {x = 14768, y = 4086}, {x = 14769, y = 4086},
                    {x = 14771, y = 4086}, {x = 14772, y = 4086},
                    {x = 14774, y = 4086}, {x = 14775, y = 4086},
                    {x = 14777, y = 4086}, {x = 14778, y = 4086},
                    {x = 14780, y = 4086}, {x = 14781, y = 4086},
                    {x = 14783, y = 4086}, {x = 14784, y = 4086},
                },
            },
            ControlPanel = {
                tiles = {
                    {x = 14732, y = 4083},
                },
            },
            CircuitBreakers = {
                tiles = {
                    {x = 14767, y = 4064},
                },
            },
        },
    },

    -- ==========================================
    -- MULDRAUGH ELECTRICAL SUBSTATION
    -- ==========================================
    MuldraughSubstation = {
        id = "muldraugh_substation",
        name = "Muldraugh Electrical Substation",
        type = "power",
        x = 10389,  -- Control panel location
        y = 10060,
        z = 0,
        isPrerequisite = false,
        requiresPrerequisite = true,
        repairDifficulty = 1.0,
        network = "power",
        description = "Central hub substation. Critical for the power network.",
        powersZones = {"Muldraugh", "Rosewood", "MarchRidge", "FallasLake"},

        components = {
            Transformer = {
                -- Transformer array
                tiles = {
                    {x = 10380, y = 10093}, {x = 10381, y = 10093},
                    {x = 10383, y = 10093}, {x = 10384, y = 10093},
                    {x = 10386, y = 10093}, {x = 10387, y = 10093},
                    {x = 10389, y = 10093}, {x = 10390, y = 10093},
                    {x = 10392, y = 10093}, {x = 10393, y = 10093},
                    {x = 10395, y = 10093}, {x = 10396, y = 10093},
                },
            },
            ControlPanel = {
                tiles = {
                    {x = 10389, y = 10060},
                },
            },
            CircuitBreakers = {
                -- Multiple breaker locations
                tiles = {
                    {x = 10397, y = 10084},
                    {x = 10394, y = 10084},
                    {x = 10391, y = 10084},
                    {x = 10388, y = 10084},
                    {x = 10384, y = 10084},
                    {x = 10384, y = 10082},
                    {x = 10379, y = 10084},
                },
            },
        },
    },

    -- ==========================================
    -- ROSEWOOD WATER TREATMENT PLANT
    -- Main water facility - part of water network
    -- ==========================================
    RosewoodWater = {
        id = "rosewood_water",
        name = "Rosewood Water Treatment Plant",
        type = "water",
        x = 8044,  -- Control panel location
        y = 15360,
        z = 0,
        isPrerequisite = false,
        requiresPrerequisite = true,
        repairDifficulty = 1.0,
        network = "water",  -- Part of water network
        description = "Main water treatment facility. Required for the water network.",
        watersZones = {"Louisville", "WestPoint", "Muldraugh", "Rosewood", "Riverside", "MarchRidge", "ValleyStation", "LouisvilleAirport", "EchoCreek", "Ekron", "Irvington", "Brandenburg", "FallasLake"},

        components = {
            Transformer = {
                -- 3 separate transformer units
                tiles = {
                    {x = 8015, y = 15356},
                    {x = 8015, y = 15343},
                    {x = 8015, y = 15332},
                },
            },
            ControlPanel = {
                tiles = {
                    {x = 8044, y = 15360},
                },
            },
            CircuitBreakers = {
                -- 3 circuit breaker units, each spanning 4 tiles
                -- Breaker 1
                tiles = {
                    {x = 8053, y = 15360}, {x = 8054, y = 15360},
                    {x = 8055, y = 15360}, {x = 8056, y = 15360},
                    -- Breaker 2
                    {x = 8061, y = 15360}, {x = 8062, y = 15360},
                    {x = 8063, y = 15360}, {x = 8064, y = 15360},
                    -- Breaker 3
                    {x = 8069, y = 15360}, {x = 8070, y = 15360},
                    {x = 8071, y = 15360}, {x = 8072, y = 15360},
                },
            },
        },
    },

    -- ==========================================
    -- RIVERSIDE RELAY STATION
    -- NOTE: No circuit breakers at this facility!
    -- ==========================================
    RiversideRelay = {
        id = "riverside_relay",
        name = "Riverside Relay Station",
        type = "power",
        x = 4832,  -- Control panel location
        y = 6279,
        z = 0,
        isPrerequisite = false,
        requiresPrerequisite = true,
        repairDifficulty = 0.5,  -- Easier since only 1 component
        network = "power",  -- Part of power network
        description = "Western relay station. Required for the power network.",
        powersZones = {"Riverside"},

        components = {
            -- Only Control Panel required for this facility
            ControlPanel = {
                tiles = {
                    {x = 4832, y = 6279},
                },
            },
        },
    },

    -- ==========================================
    -- IRVINGTON ELECTRICAL SUBSTATION
    -- ==========================================
    IrvingtonSubstation = {
        id = "irvington_substation",
        name = "Irvington Substation",
        type = "power",
        x = 2210,
        y = 13914,
        z = 0,
        isPrerequisite = false,
        requiresPrerequisite = true,
        repairDifficulty = 0.9,
        network = "power",
        description = "Western substation. Required for the power network.",
        powersZones = {"Irvington", "EchoCreek", "Ekron", "Brandenburg"},

        components = {
            Transformer = {
                tiles = {
                    {x = 2215, y = 13884},
                },
            },
            ControlPanel = {
                tiles = {
                    {x = 2210, y = 13914},
                },
            },
            CircuitBreakers = {
                tiles = {
                    {x = 2183, y = 13894}, {x = 2184, y = 13894},
                    {x = 2186, y = 13894}, {x = 2187, y = 13894},
                    {x = 2189, y = 13894}, {x = 2190, y = 13894},
                    {x = 2192, y = 13894}, {x = 2193, y = 13894},
                    {x = 2195, y = 13894}, {x = 2196, y = 13894},
                    {x = 2198, y = 13894}, {x = 2199, y = 13894},
                },
            },
        },
    },
}

-- ============================================
-- NETWORK DEFINITIONS
-- All facilities in a network must be online for it to work
-- ============================================

EPR.Zones.Networks = {}

-- ============================================
-- ZONE DEFINITIONS (Bounding Boxes)
-- ============================================

EPR.Zones.Definitions = {
    -- Major Towns
    Louisville = {
        name = "Louisville",
        bounds = {11500, 800, 15000, 4500},
        description = "Kentucky's largest city. High zombie density.",
    },
    WestPoint = {
        name = "West Point",
        bounds = {10800, 6400, 12600, 8200},
        description = "Industrial town at the confluence.",
    },
    Muldraugh = {
        name = "Muldraugh",
        bounds = {10200, 8800, 11200, 10800},
        description = "Small town south of West Point.",
    },
    Rosewood = {
        name = "Rosewood",
        bounds = {7400, 10400, 8600, 12200},
        description = "Small town with nearby prison.",
    },
    Riverside = {
        name = "Riverside",
        bounds = {5400, 5000, 7200, 6800},
        description = "Northern farming community.",
    },
    MarchRidge = {
        name = "March Ridge",
        bounds = {9400, 12000, 10600, 13200},
        description = "Rural settlement south of Rosewood.",
    },
    FallasLake = {
        name = "Fallas Lake",
        bounds = {6328, 7408, 8342, 9493},
        description = "Lake settlement east of Muldraugh.",
    },

    -- Louisville Suburbs/Areas
    ValleyStation = {
        name = "Valley Station",
        bounds = {11000, 4500, 12500, 6000},
        description = "Louisville suburb.",
    },
    LouisvilleAirport = {
        name = "Louisville Airport",
        bounds = {13500, 3500, 15500, 5000},
        description = "Regional airport facility.",
    },

    -- Western Rural Areas
    EchoCreek = {
        name = "Echo Creek",
        bounds = {4000, 7000, 5500, 8500},
        description = "Small rural community.",
    },
    Ekron = {
        name = "Ekron",
        bounds = {5000, 8000, 6500, 9500},
        description = "Rural farming area.",
    },
    Irvington = {
        name = "Irvington",
        bounds = {3500, 9000, 5000, 10500},
        description = "Western rural town.",
    },
    Brandenburg = {
        name = "Brandenburg",
        bounds = {2500, 7500, 4000, 9000},
        description = "Far western settlement.",
    },
}

-- ============================================
-- COMPONENT TILE LOOKUP
-- ============================================

-- Check if coordinates match any component tile for a facility
-- Returns: componentType or nil
function EPR.Zones.GetComponentAtTile(facility, x, y)
    if not facility or not facility.components then return nil end

    for compType, compData in pairs(facility.components) do
        if compData and compData.tiles then
            for _, tile in ipairs(compData.tiles) do
                if tile.x == x and tile.y == y then
                    return compType
                end
            end
        end
    end
    return nil
end

-- Check if coordinates are near any component tile (within tolerance)
-- Returns: componentType, facility, facilityKey
function EPR.Zones.FindComponentNearTile(x, y, tolerance)
    tolerance = tolerance or 2

    for key, facility in pairs(EPR.Zones.Facilities) do
        if facility.components then
            for compType, compData in pairs(facility.components) do
                if compData and compData.tiles then
                    for _, tile in ipairs(compData.tiles) do
                        local dx = math.abs(tile.x - x)
                        local dy = math.abs(tile.y - y)
                        if dx <= tolerance and dy <= tolerance then
                            return compType, facility, key
                        end
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

-- Get the "primary" tile for a component (first tile in list)
function EPR.Zones.GetComponentPrimaryTile(facility, compType)
    if not facility or not facility.components then return nil end
    local compData = facility.components[compType]
    if compData and compData.tiles and #compData.tiles > 0 then
        return compData.tiles[1]
    end
    return nil
end

-- Get list of component types that exist at a facility
function EPR.Zones.GetFacilityComponentTypes(facility)
    local types = {}
    if facility and facility.components then
        for _, compType in ipairs(EPR.ComponentOrder) do
            if facility.components[compType] and facility.components[compType].tiles then
                table.insert(types, compType)
            end
        end
    end
    return types
end

-- ============================================
-- FACILITY LOOKUP FUNCTIONS
-- ============================================

function EPR.Zones.GetFacility(facilityId)
    for key, facility in pairs(EPR.Zones.Facilities) do
        if facility.id == facilityId then
            return facility, key
        end
    end
    return nil, nil
end

function EPR.Zones.GetAllFacilities()
    return EPR.Zones.Facilities
end

function EPR.Zones.GetPrerequisiteFacility()
    for key, facility in pairs(EPR.Zones.Facilities) do
        if facility.isPrerequisite then
            return facility, key
        end
    end
    return nil, nil
end

function EPR.Zones.IsPrerequisiteComplete()
    local prereq = EPR.Zones.GetPrerequisiteFacility()
    if not prereq then return true end

    local status = EPR.Substations[prereq.id] or EPR.WaterPlants[prereq.id]
    if status and status.status == "online" then
        return true
    end
    return false
end

function EPR.Zones.CanRepairFacility(facilityId)
    local facility = EPR.Zones.GetFacility(facilityId)
    if not facility then return false, "Facility not found" end

    -- Check if power is still on (vanilla power shutoff hasn't happened yet)
    -- The mod should only work AFTER the power goes out
    -- Uses saved original shutoff values for compatibility with mods that modify SandboxVars
    -- (e.g., "Immersive Water Shutoff & Blackouts" mod)
    local requirePowerOff = true
    if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.RequirePowerOff ~= nil then
        requirePowerOff = SandboxVars.EPR.RequirePowerOff
    end

    if requirePowerOff then
        -- Use the saved original shutoff values (not current SandboxVars which may be modified)
        local powerIsOff = EPR.Zones.IsPowerShutoff()

        if not powerIsOff then
            -- Check if shutoff is set to effectively "never" (very high values)
            local originalShutoff = EPR.Zones.GetOriginalElecShutoff()
            if type(originalShutoff) == "string" then
                originalShutoff = tonumber(originalShutoff)
            end
            if originalShutoff and originalShutoff > 3650 then
                return false, getText("UI_EPR_PowerNeverShutoff") or "Power is set to never shut off. EPR facilities cannot be used."
            end
            return false, getText("UI_EPR_PowerStillOn") or "The grid is still operational. No repairs needed yet."
        end
    end

    -- Check if Louisville Plant is disabled via sandbox option
    if facility.isPrerequisite then
        local louisvilleEnabled = true
        if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.LouisvillePlantEnabled ~= nil then
            louisvilleEnabled = SandboxVars.EPR.LouisvillePlantEnabled
        end
        if not louisvilleEnabled then
            return false, getText("UI_EPR_Prerequisite_Disabled") or "Louisville Plant is disabled in sandbox settings."
        end
        return true
    end

    -- Check prerequisite requirement (if enabled in sandbox)
    if facility.requiresPrerequisite then
        local requirePrereq = true
        if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.RequirePrerequisite ~= nil then
            requirePrereq = SandboxVars.EPR.RequirePrerequisite
        end

        if requirePrereq and not EPR.Zones.IsPrerequisiteComplete() then
            return false, getText("UI_EPR_Prerequisite_Required") or "Must restore Louisville Combined Plant first!"
        end
    end

    return true
end

-- Get facility near coordinates (checks control panel location)
function EPR.Zones.GetNearbyFacility(x, y, radius)
    radius = radius or 50

    for key, facility in pairs(EPR.Zones.Facilities) do
        local dx = facility.x - x
        local dy = facility.y - y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= radius then
            return facility, key, dist
        end
    end
    return nil, nil, nil
end

-- Get facility that contains a component at given coordinates
function EPR.Zones.GetFacilityByComponentTile(x, y)
    local compType, facility, key = EPR.Zones.FindComponentNearTile(x, y, 1)
    if facility then
        return facility, key, compType
    end
    return nil, nil, nil
end

-- ============================================
-- ZONE LOOKUP FUNCTIONS
-- ============================================

function EPR.Zones.GetZoneAt(x, y)
    for zoneName, zone in pairs(EPR.Zones.Definitions) do
        local bounds = zone.bounds
        if bounds then
            if x >= bounds[1] and x <= bounds[3] and
               y >= bounds[2] and y <= bounds[4] then
                return zoneName, zone
            end
        end
    end
    return nil, nil
end

function EPR.Zones.GetZone(zoneName)
    return EPR.Zones.Definitions[zoneName]
end

function EPR.Zones.GetAllZoneNames()
    local names = {}
    for name, _ in pairs(EPR.Zones.Definitions) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- ============================================
-- POWER/WATER STATUS FUNCTIONS
-- ============================================

function EPR.Zones.GetPowerSourceForZone(zoneName)
    for key, facility in pairs(EPR.Zones.Facilities) do
        if facility.powersZones then
            for _, zone in ipairs(facility.powersZones) do
                if zone == zoneName then
                    return facility, key
                end
            end
        end
    end
    return nil, nil
end

function EPR.Zones.GetWaterSourceForZone(zoneName)
    for key, facility in pairs(EPR.Zones.Facilities) do
        if facility.watersZones then
            for _, zone in ipairs(facility.watersZones) do
                if zone == zoneName then
                    return facility, key
                end
            end
        end
    end
    return nil, nil
end

function EPR.Zones.UpdateZoneStatus()
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

    local louisvilleOnline = true
    if EPR.PowerController and EPR.PowerController.globalOverride ~= nil then
        louisvilleOnline = EPR.PowerController.globalOverride == true
    else
        local louisville = EPR.Substations and EPR.Substations["louisville_plant"]
        louisvilleOnline = louisville and louisville.status == "online"
    end

    if not louisvilleEnabled or not requirePrereq then
        louisvilleOnline = true
    end

    if not louisvilleOnline then
        for zoneName, _ in pairs(EPR.Zones.Definitions) do
            EPR.PoweredZones[zoneName] = false
            EPR.WaterZones[zoneName] = false
        end

        if EPR.Buildings and EPR.Buildings.ApplyAllZones then
            EPR.Buildings.ApplyAllZones()
        end

        if EPR.Buildings and EPR.Buildings.ApplySimulationForAllZones then
            EPR.Buildings.ApplySimulationForAllZones()
        end
        return
    end

    -- Reset all zones
    for zoneName, _ in pairs(EPR.Zones.Definitions) do
        EPR.PoweredZones[zoneName] = false
        EPR.WaterZones[zoneName] = false
    end

    -- Check each facility
    for key, facility in pairs(EPR.Zones.Facilities) do
        local status = nil

        if facility.type == "power" then
            status = EPR.Substations[facility.id]
        elseif facility.type == "water" then
            status = EPR.WaterPlants[facility.id]
        elseif facility.type == "combined" then
            status = EPR.Substations[facility.id]
        end

        if status and status.status == "online" then
            if facility.powersZones then
                for _, zoneName in ipairs(facility.powersZones) do
                    EPR.PoweredZones[zoneName] = true
                end
            end
            if facility.watersZones then
                for _, zoneName in ipairs(facility.watersZones) do
                    EPR.WaterZones[zoneName] = true
                end
            end
        end
    end

    if EPR.Buildings and EPR.Buildings.ApplyAllZones then
        EPR.Buildings.ApplyAllZones()
    end

    if EPR.Buildings and EPR.Buildings.ApplySimulationForAllZones then
        EPR.Buildings.ApplySimulationForAllZones()
    end
end

-- ============================================
-- ORIGINAL SHUTOFF VALUES (for mod compatibility)
-- ============================================

-- Save original sandbox shutoff values before other mods can modify them
-- This is needed for compatibility with "Immersive Water Shutoff & Blackouts" mod
-- which dynamically changes SandboxVars.ElecShutModifier and WaterShutModifier
function EPR.Zones.SaveOriginalShutoffValues()
    if not ModData then
        return
    end
    if not SandboxVars then
        return
    end

    local modData = ModData.getOrCreate("EPR_GlobalData")

    -- Only save if not already saved (so we don't overwrite with modified values)
    if modData.originalElecShut == nil then
        modData.originalElecShut = SandboxVars.ElecShutModifier
        print("[EPR Zones] Saved original ElecShutModifier: " .. tostring(modData.originalElecShut))
    end

    if modData.originalWaterShut == nil then
        modData.originalWaterShut = SandboxVars.WaterShutModifier
        print("[EPR Zones] Saved original WaterShutModifier: " .. tostring(modData.originalWaterShut))
    end
end

-- Get the original shutoff day (before other mods modified it)
function EPR.Zones.GetOriginalElecShutoff()
    local modData = ModData.getOrCreate("EPR_GlobalData")
    if modData.originalElecShut ~= nil then
        return modData.originalElecShut
    end
    -- Fallback to current value if not saved yet
    return SandboxVars.ElecShutModifier
end

function EPR.Zones.GetOriginalWaterShutoff()
    local modData = ModData.getOrCreate("EPR_GlobalData")
    if modData.originalWaterShut ~= nil then
        return modData.originalWaterShut
    end
    -- Fallback to current value if not saved yet
    return SandboxVars.WaterShutModifier
end

-- ============================================
-- VANILLA-ACCURATE OUTAGE DETECTION
-- ============================================
-- The base game decides whether the municipal grid is live with:
--   power ON  while  worldAgeHours/24 + (TimeSinceApo - 1) * 30 < ElecShutModifier
-- (verified against vanilla B42: media/lua/client/ISUI/ISButtonPrompt.lua and
-- ISVehicleMenu.lua). The (TimeSinceApo - 1) * 30 term is what EPR used to
-- ignore: any "X months/years later" world start shuts the grid off long before
-- the raw world age reaches ElecShutModifier, so without it EPR thought power
-- was still on and refused to restore anything. Water uses the same offset.

-- Days to add for the world's "time since the apocalypse" start offset.
function EPR.Zones.GetApoOffsetDays()
    local timeSinceApo = nil
    local okOpt, opts = pcall(getSandboxOptions)
    if okOpt and opts and opts.getTimeSinceApo then
        local okTsa, tsa = pcall(function() return opts:getTimeSinceApo() end)
        if okTsa and type(tsa) == "number" then
            timeSinceApo = tsa
        end
    end
    if timeSinceApo == nil and SandboxVars and type(SandboxVars.TimeSinceApo) == "number" then
        timeSinceApo = SandboxVars.TimeSinceApo
    end
    if timeSinceApo == nil then
        timeSinceApo = 1
    end
    return (timeSinceApo - 1) * 30
end

-- Effective elapsed days the engine compares against the shutoff day.
function EPR.Zones.GetEffectiveElapsedDays()
    local gameTime = getGameTime()
    if not gameTime then return nil end
    return (gameTime:getWorldAgeHours() / 24) + EPR.Zones.GetApoOffsetDays()
end

-- The configured shutoff day, ignoring any sentinel EPR itself wrote into
-- SandboxVars while its override was active (45000 / INT_MAX). Without this,
-- once EPR brought one facility online every later "is the grid down?" check
-- read 45000 and reported the grid as healthy — silently blocking the repair
-- of every remaining facility.
local function eprCleanShutoffValue(v)
    if type(v) == "string" then v = tonumber(v) end
    if v == nil then return nil end
    if v == 45000 or v == 2147483647 then return nil end
    return v
end

function EPR.Zones.GetEffectiveElecShutoff()
    local md = ModData and ModData.getOrCreate and ModData.getOrCreate("EPR_GlobalData")
    local v = md and eprCleanShutoffValue(md.originalElecShut)
    if v ~= nil then return v end
    v = EPR.PowerController and eprCleanShutoffValue(EPR.PowerController.originalElecShutModifier)
    if v ~= nil then return v end
    return eprCleanShutoffValue(SandboxVars and SandboxVars.ElecShutModifier)
end

function EPR.Zones.GetEffectiveWaterShutoff()
    local md = ModData and ModData.getOrCreate and ModData.getOrCreate("EPR_GlobalData")
    local v = md and eprCleanShutoffValue(md.originalWaterShut)
    if v ~= nil then return v end
    v = EPR.PowerController and eprCleanShutoffValue(EPR.PowerController.originalWaterShutModifier)
    if v ~= nil then return v end
    return eprCleanShutoffValue(SandboxVars and SandboxVars.WaterShutModifier)
end

-- Check if vanilla power has shut off (using the ORIGINAL configured values, so
-- it stays correct even after EPR forces SandboxVars.ElecShutModifier high).
-- Value semantics for ElecShutModifier:
--   -1 = Instant shutoff (power is off from world start)
--   0+ = day count (compared against world age + apocalypse offset)
--   Very high / sentinel = effectively never
function EPR.Zones.IsPowerShutoff()
    local shutoffDay = EPR.Zones.GetEffectiveElecShutoff()
    if type(shutoffDay) == "string" then shutoffDay = tonumber(shutoffDay) end

    -- Instant shutoff: power is off from the start of the world.
    if shutoffDay == -1 then
        return true
    end

    -- Effectively never: the grid is configured to stay up forever, so EPR must
    -- not engage at all.
    if shutoffDay ~= nil and shutoffDay > 3650 then
        return false
    end

    -- Most reliable signal: the world's actual grid power where the player is.
    -- Only a *negative* reading is trusted, and only while EPR isn't already
    -- forcing the vanilla grid on (otherwise haveElectricity() is always true).
    local overrideActive = EPR.PowerController and EPR.PowerController.globalOverride == true
    if not overrideActive then
        local player = getPlayer()
        if player then
            local px, py = math.floor(player:getX()), math.floor(player:getY())
            local zoneName = EPR.Zones.GetZoneAt and EPR.Zones.GetZoneAt(px, py)
            local isEPRPowered = zoneName and EPR.PoweredZones and EPR.PoweredZones[zoneName]
            if not isEPRPowered then
                local testSquare = getSquare(px, py, 0)
                if testSquare and testSquare.haveElectricity and not testSquare:haveElectricity() then
                    return true  -- Power is actually off in the world
                end
            end
        end
    end

    -- Day-count math, vanilla-accurate (includes the apocalypse-start offset).
    if shutoffDay == nil then
        return false
    end
    local effectiveDays = EPR.Zones.GetEffectiveElapsedDays()
    if effectiveDays == nil then
        return false
    end
    if shutoffDay >= 0 then
        return effectiveDays >= shutoffDay
    end
    return false
end

-- Check if vanilla water has shut off (using original values). Mirrors the
-- electricity logic, including the apocalypse-start day offset.
function EPR.Zones.IsWaterShutoff()
    local shutoffDay = EPR.Zones.GetEffectiveWaterShutoff()
    if type(shutoffDay) == "string" then shutoffDay = tonumber(shutoffDay) end

    if shutoffDay == nil then
        return false
    end
    if shutoffDay == -1 then
        return true
    end
    if shutoffDay > 3650 then
        return false
    end

    local effectiveDays = EPR.Zones.GetEffectiveElapsedDays()
    if effectiveDays == nil then
        return false
    end
    if shutoffDay >= 0 then
        return effectiveDays >= shutoffDay
    end
    return false
end

-- Register to save original values as early as possible
Events.OnInitGlobalModData.Add(function()
    EPR.Zones.SaveOriginalShutoffValues()
end)

-- ============================================
-- PUBLIC MODDER API
-- ============================================
-- Other mods can extend EPR's grid by registering zones/facilities and by
-- editing the coverage of existing facilities (e.g. carve RavenCreek out of
-- Rosewood Water's coverage so a modded RavenCreek plant serves it instead).
--
-- IMPORTANT: call these at shared-file scope or from Events.OnGameBoot — they
-- must run BEFORE EPR initialises (OnGameStart / OnInitGlobalModData), which is
-- when InitializeZones() and EnsureAllFacilities() consume these tables. New
-- facilities then get repair state + persistence automatically (state is keyed
-- by facility.id).
--
-- Example:
--   EPR.Zones.RegisterZone("RavenCreek", { name = "Raven Creek",
--       bounds = {x1, y1, x2, y2}, description = "Raven Creek township" })
--   EPR.Zones.RegisterFacility("RavenCreekWater", { id = "ravencreek_water",
--       name = "Raven Creek Water Treatment", type = "water",
--       x = wx, y = wy, watersZones = {"RavenCreek"} })
--   EPR.Zones.RemoveZoneFromFacilityCoverage("rosewood_water", "RavenCreek")

local function eprResolveFacility(facilityKeyOrId)
    if not facilityKeyOrId then return nil, nil end
    local direct = EPR.Zones.Facilities[facilityKeyOrId]
    if direct then return direct, facilityKeyOrId end
    for key, facility in pairs(EPR.Zones.Facilities) do
        if facility.id == facilityKeyOrId then
            return facility, key
        end
    end
    return nil, nil
end
EPR.Zones.ResolveFacility = eprResolveFacility

local function eprNormalizeZoneList(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    for _, z in ipairs(list) do
        if type(z) == "string" and z ~= "" then
            table.insert(out, z)
        end
    end
    return out
end

function EPR.Zones.RegisterZone(zoneName, def)
    if type(zoneName) ~= "string" or zoneName == "" then
        print("[EPR] RegisterZone: invalid zone name")
        return false, "invalid zone name"
    end
    if type(def) ~= "table" or type(def.bounds) ~= "table" or #def.bounds ~= 4 then
        print("[EPR] RegisterZone: '" .. zoneName .. "' needs bounds = {x1, y1, x2, y2}")
        return false, "invalid bounds"
    end
    for i = 1, 4 do
        if type(def.bounds[i]) ~= "number" then
            print("[EPR] RegisterZone: '" .. zoneName .. "' bounds must be numbers")
            return false, "invalid bounds"
        end
    end
    if EPR.Zones.Definitions[zoneName] then
        print("[EPR] RegisterZone: overwriting existing zone '" .. zoneName .. "'")
    end
    EPR.Zones.Definitions[zoneName] = {
        name = def.name or zoneName,
        bounds = { def.bounds[1], def.bounds[2], def.bounds[3], def.bounds[4] },
        description = def.description or "",
    }
    if EPR.PoweredZones and EPR.PoweredZones[zoneName] == nil then
        EPR.PoweredZones[zoneName] = false
    end
    if EPR.WaterZones and EPR.WaterZones[zoneName] == nil then
        EPR.WaterZones[zoneName] = false
    end
    print("[EPR] Registered zone: " .. zoneName)
    return true
end

function EPR.Zones.RegisterFacility(facilityKey, def)
    if type(facilityKey) ~= "string" or facilityKey == "" then
        print("[EPR] RegisterFacility: invalid facility key")
        return false, "invalid key"
    end
    if type(def) ~= "table" then
        print("[EPR] RegisterFacility: '" .. facilityKey .. "' def must be a table")
        return false, "invalid def"
    end
    if type(def.id) ~= "string" or def.id == "" then
        print("[EPR] RegisterFacility: '" .. facilityKey .. "' requires a string 'id'")
        return false, "missing id"
    end
    local ftype = def.type
    if ftype ~= "power" and ftype ~= "water" and ftype ~= "combined" then
        print("[EPR] RegisterFacility: '" .. facilityKey .. "' type must be power|water|combined")
        return false, "invalid type"
    end
    if type(def.x) ~= "number" or type(def.y) ~= "number" then
        print("[EPR] RegisterFacility: '" .. facilityKey .. "' requires numeric x,y")
        return false, "invalid coordinates"
    end
    -- Duplicate id check (persisted state is keyed by id; collisions corrupt it).
    for existingKey, facility in pairs(EPR.Zones.Facilities) do
        if existingKey ~= facilityKey and facility.id == def.id then
            print("[EPR] RegisterFacility: id '" .. def.id .. "' already used by '" .. existingKey .. "'")
            return false, "duplicate id"
        end
    end
    if EPR.Zones.Facilities[facilityKey] then
        print("[EPR] RegisterFacility: overwriting existing facility '" .. facilityKey .. "'")
    end

    def.z = def.z or 0
    if def.requiresPrerequisite == nil then def.requiresPrerequisite = true end
    if def.isPrerequisite == nil then def.isPrerequisite = false end
    def.repairDifficulty = def.repairDifficulty or 1.0
    def.network = def.network or (ftype == "water" and "water" or "power")
    def.powersZones = eprNormalizeZoneList(def.powersZones) or def.powersZones
    def.watersZones = eprNormalizeZoneList(def.watersZones) or def.watersZones
    def.components = def.components or {
        ControlPanel = { tiles = { { x = def.x, y = def.y } } },
    }
    EPR.Zones.Facilities[facilityKey] = def
    print("[EPR] Registered facility: " .. facilityKey .. " (" .. def.id .. ")")
    return true
end

function EPR.Zones.SetFacilityCoverage(facilityKeyOrId, coverage)
    local facility = eprResolveFacility(facilityKeyOrId)
    if not facility then
        print("[EPR] SetFacilityCoverage: facility not found: " .. tostring(facilityKeyOrId))
        return false, "facility not found"
    end
    if type(coverage) ~= "table" then
        return false, "invalid coverage"
    end
    if coverage.powersZones ~= nil then
        facility.powersZones = eprNormalizeZoneList(coverage.powersZones) or {}
    end
    if coverage.watersZones ~= nil then
        facility.watersZones = eprNormalizeZoneList(coverage.watersZones) or {}
    end
    if EPR.Zones.UpdateZoneStatus then
        pcall(EPR.Zones.UpdateZoneStatus)
    end
    return true
end

function EPR.Zones.RemoveZoneFromFacilityCoverage(facilityKeyOrId, zoneName)
    local facility = eprResolveFacility(facilityKeyOrId)
    if not facility then
        print("[EPR] RemoveZoneFromFacilityCoverage: facility not found: " .. tostring(facilityKeyOrId))
        return false, "facility not found"
    end
    local removed = false
    local function strip(list)
        if type(list) ~= "table" then return list end
        local out = {}
        for _, z in ipairs(list) do
            if z ~= zoneName then
                table.insert(out, z)
            else
                removed = true
            end
        end
        return out
    end
    facility.powersZones = strip(facility.powersZones)
    facility.watersZones = strip(facility.watersZones)
    if removed and EPR.Zones.UpdateZoneStatus then
        pcall(EPR.Zones.UpdateZoneStatus)
    end
    return removed
end

-- ============================================
-- INITIALIZATION
-- ============================================

function EPR.Zones.InitializeZones()
    logDebug("[EPR Zones] Initializing zone system...")

    local facilityCount = 0
    local zoneCount = 0

    for key, facility in pairs(EPR.Zones.Facilities) do
        facilityCount = facilityCount + 1

        if facility.type == "power" or facility.type == "combined" then
            if not EPR.Substations[facility.id] then
                EPR.Substations[facility.id] = {
                    status = "offline",
                    health = 0,
                    repairProgress = 0,
                    currentStage = 0,
                    lastMaintenance = 0,
                    repairQuality = 0,
                    facilityKey = key,
                    components = {},
                }
            end
        end

        if facility.type == "water" or facility.type == "combined" then
            if not EPR.WaterPlants[facility.id] then
                EPR.WaterPlants[facility.id] = {
                    status = "offline",
                    health = 0,
                    repairProgress = 0,
                    currentStage = 0,
                    lastMaintenance = 0,
                    repairQuality = 0,
                    facilityKey = key,
                    components = {},
                }
            end
        end
    end

    for zoneName, _ in pairs(EPR.Zones.Definitions) do
        zoneCount = zoneCount + 1
        if EPR.PoweredZones[zoneName] == nil then
            EPR.PoweredZones[zoneName] = false
        end
        if EPR.WaterZones[zoneName] == nil then
            EPR.WaterZones[zoneName] = false
        end
    end

    EPR.Zones.UpdateZoneStatus()

    logDebug("[EPR Zones] Loaded " .. facilityCount .. " facilities, " .. zoneCount .. " zones")
end

-- ============================================
-- DEBUG
-- ============================================

function EPR.Zones.PrintFacilityStatus()
    logDebug("[EPR Zones] === Facility Status ===")

    local prereqComplete = EPR.Zones.IsPrerequisiteComplete()
    logDebug("  Prerequisite complete: " .. tostring(prereqComplete))
    logDebug("")

    for key, facility in pairs(EPR.Zones.Facilities) do
        local status = EPR.Substations[facility.id] or EPR.WaterPlants[facility.id]
        local statusStr = status and status.status or "unknown"
        local prereqStr = facility.isPrerequisite and " [PREREQUISITE]" or ""

        logDebug("  " .. facility.name .. prereqStr)
        logDebug("    ID: " .. facility.id)
        logDebug("    Type: " .. facility.type)
        logDebug("    Terminal: " .. facility.x .. ", " .. facility.y)
        logDebug("    Status: " .. statusStr)

        -- Print component info
        local compTypes = EPR.Zones.GetFacilityComponentTypes(facility)
        logDebug("    Components: " .. table.concat(compTypes, ", "))

        if facility.powersZones then
            logDebug("    Powers: " .. table.concat(facility.powersZones, ", "))
        end
        if facility.watersZones then
            logDebug("    Waters: " .. table.concat(facility.watersZones, ", "))
        end
        logDebug("")
    end
end

function EPR.Zones.PrintZoneStatus()
    logDebug("[EPR Zones] === Zone Status ===")
    local names = EPR.Zones.GetAllZoneNames()
    for _, name in ipairs(names) do
        local pwr = EPR.PoweredZones[name] and "PWR" or "---"
        local wtr = EPR.WaterZones[name] and "H2O" or "---"
        logDebug("  " .. name .. " [" .. pwr .. "] [" .. wtr .. "]")
    end
end

logDebug("[EPR] EPR_Zones.lua loaded successfully")
