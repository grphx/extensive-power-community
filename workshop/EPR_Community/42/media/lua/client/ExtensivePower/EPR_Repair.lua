--[[
    Extensive Power Rework - Repair System

    Multi-stage repair system with tool and part requirements:

    REPAIR STAGES (per component):
    1. Assessment - Inspect damage, determine what's needed
    2. Part Replacement - Install new parts (consumes items)
    3. Calibration - Fine-tune the repaired component
    4. Startup - Power on the facility (loud, attracts zombies)

    Each stage has:
    - Different time requirements
    - Different tool requirements
    - Different part requirements (Stage 2)
    - Skill-based time reduction
]]--

if isServer() and not isClient() then return end

print("[EPR] EPR_Repair.lua loading...")

require "TimedActions/ISBaseTimedAction"

EPR = EPR or {}
EPR.Repair = {}

local function saveIfAuthoritative()
    if EPR and EPR.IsServerContext and EPR.IsServerContext() then
        EPR.SaveData()
    end
end

-- ============================================
-- REPAIR STAGES CONFIGURATION
-- ============================================

EPR.Repair.Stages = {
    Assessment = {
        order = 1,
        name = "Assessment",
        description = "Inspecting damage",
        baseTimeMinutes = 30,
        skillWeight = 0.3,
        tools = {},  -- No tools needed for assessment
        consumesParts = false,
        attractsZombies = false,
        noiseRadius = 10,  -- Quiet - just looking
    },
    PartReplacement = {
        order = 2,
        name = "Part Replacement",
        description = "Installing parts",
        baseTimeMinutes = 360,
        skillWeight = 0.5,
        tools = {"Screwdriver", "Wrench", "WeldingMask", "BlowTorch"},
        consumesParts = true,
        attractsZombies = false,
        noiseRadius = 80,
    },
    Calibration = {
        order = 3,
        name = "Calibration",
        description = "Calibrating systems",
        baseTimeMinutes = 90,
        skillWeight = 0.4,
        tools = {"Screwdriver"},
        consumesParts = false,
        attractsZombies = false,
        noiseRadius = 20,
    },
    Startup = {
        order = 4,
        name = "Startup",
        description = "DEFEND THE AREA!",
        baseTimeMinutes = 5,
        skillWeight = 0,
        tools = {},
        consumesParts = false,
        attractsZombies = true,
        noiseRadius = 150,
    },
}

EPR.Repair.StageOrder = {"Assessment", "PartReplacement", "Calibration", "Startup"}

-- ============================================
-- TOOL DEFINITIONS
-- Uses exact in-game item names as display names
-- Multiple itemTypes allow different item versions to fulfill the requirement
-- ============================================

EPR.Repair.Tools = {
    Screwdriver = {
        itemTypes = {
            "Base.Screwdriver",
            "Base.ScrewdriverElectronic",  -- Electronic Screwdriver (if exists)
        },
        displayName = "Screwdriver",
        consumed = false,
        damageOnUse = 0.02,
    },
    Wrench = {
        itemTypes = {
            "Base.Wrench",           -- Wrench
            "Base.PipeWrench",       -- Pipe Wrench
            "Base.LugWrench",        -- Lug Wrench (vehicle maintenance)
        },
        displayName = "Wrench (or Pipe Wrench, Lug Wrench)",
        consumed = false,
        damageOnUse = 0.02,
    },
    WeldingMask = {
        itemTypes = {
            "Base.WeldingMask",      -- Welder Mask
            "Base.WeldingGoggles",   -- Welding Goggles (if exists in B42)
        },
        displayName = "Welder Mask",
        consumed = false,
        damageOnUse = 0,
    },
    BlowTorch = {
        itemTypes = {
            "Base.BlowTorch",        -- Welding Torch
        },
        displayName = "Welding Torch",
        consumed = false,
        damageOnUse = 0.05,
        requiresPropane = true,
    },
    Hammer = {
        itemTypes = {
            "Base.Hammer",           -- Hammer
            "Base.HammerStone",      -- Stone Hammer
            "Base.BallPeenHammer",   -- Ball-peen Hammer
            "Base.ClubHammer",       -- Club Hammer
            "Base.WoodenMallet",     -- Wooden Mallet
        },
        displayName = "Hammer (any type)",
        consumed = false,
        damageOnUse = 0.01,
    },
    Pliers = {
        itemTypes = {
            "Base.Pliers",           -- Pliers
        },
        displayName = "Pliers",
        consumed = false,
        damageOnUse = 0.01,
    },
    Saw = {
        itemTypes = {
            "Base.Saw",              -- Hand Saw / Wood Saw
            "Base.GardenSaw",        -- Garden Saw
            "Base.Hacksaw",          -- Hacksaw (for metal)
        },
        displayName = "Saw (Hand Saw, Garden Saw, or Hacksaw)",
        consumed = false,
        damageOnUse = 0.03,
    },
}

-- ============================================
-- PART DEFINITIONS (Expanded)
-- Uses exact in-game item names as display names
-- Multiple itemTypes allow different item versions to fulfill the requirement
-- ============================================

EPR.Repair.Parts = {
    -- Electrical parts
    Electronics = {
        itemTypes = {
            "Base.ElectronicsScrap",     -- Scrap Electronics
            "Base.Receiver",             -- Receiver (alternative)
        },
        displayName = "Scrap Electronics",
        weight = 0.3,
    },
    ElectricWire = {
        itemTypes = {
            "Base.ElectricWire",         -- Electrical Wire
            "Base.Wire",                 -- Wire (if different)
        },
        displayName = "Electrical Wire",
        weight = 0.1,
    },
    Amplifier = {
        itemTypes = {
            "Base.Amplifier",            -- Amplifier
        },
        displayName = "Amplifier",
        weight = 0.5,
    },
    Battery = {
        itemTypes = {
            "Base.Battery",              -- Battery
            "Base.CarBattery1",          -- Car Battery (alternative)
            "Base.CarBattery2",          -- Car Battery (alternative)
            "Base.CarBattery3",          -- Car Battery (alternative)
        },
        displayName = "Battery (or Car Battery)",
        weight = 1.0,
    },

    -- Metal parts
    ScrapMetal = {
        itemTypes = {
            "Base.ScrapMetal",           -- Scrap Metal
            "Base.UnusableMetal",        -- Unusable Metal (alternative)
        },
        displayName = "Scrap Metal",
        weight = 1.0,
    },
    MetalPipe = {
        itemTypes = {
            "Base.MetalPipe",            -- Metal Pipe
            "Base.LeadPipe",             -- Lead Pipe (alternative)
        },
        displayName = "Metal Pipe (or Lead Pipe)",
        weight = 1.5,
    },
    SmallSheetMetal = {
        itemTypes = {
            "Base.SmallSheetMetal",      -- Small Sheet Metal
        },
        displayName = "Small Sheet Metal",
        weight = 2.0,
    },
    SheetMetal = {
        itemTypes = {
            "Base.SheetMetal",           -- Sheet Metal
            "Base.SmallSheetMetal",      -- Small Sheet Metal (alternative)
        },
        displayName = "Sheet Metal (or Small Sheet Metal)",
        weight = 3.0,
    },
    MetalBar = {
        itemTypes = {
            "Base.SteelBar",             -- Steel Bar (B42)
            "Base.IronBar",              -- Iron Bar (alternative)
        },
        displayName = "Steel/Iron Bar",
        weight = 1.5,
    },

    -- Small parts
    Screws = {
        itemTypes = {
            "Base.Screws",               -- Screws (box)
            "Base.ScrewsBox",            -- Screws Box (if different)
        },
        displayName = "Screws",
        weight = 0.1,
    },
    Nails = {
        itemTypes = {
            "Base.Nails",                -- Nails (box)
            "Base.NailsBox",             -- Nails Box (if different)
        },
        displayName = "Nails",
        weight = 0.1,
    },
    DuctTape = {
        itemTypes = {
            "Base.DuctTape",             -- Duct Tape
            "Base.Scotchtape",           -- Scotch Tape (alternative)
        },
        displayName = "Duct Tape (or Scotch Tape)",
        weight = 0.2,
    },
    Glue = {
        itemTypes = {
            "Base.Glue",                 -- Glue
            "Base.WoodGlue",             -- Wood Glue
            "Base.Superglue",            -- Superglue (if exists)
        },
        displayName = "Glue (any type)",
        weight = 0.3,
    },

    -- Mechanical parts
    Pipe = {
        itemTypes = {
            "Base.Pipe",                 -- Pipe
            "Base.MetalPipe",            -- Metal Pipe (alternative)
        },
        displayName = "Pipe",
        weight = 1.0,
    },
    Rope = {
        itemTypes = {
            "Base.Rope",                 -- Rope
            "Base.SheetRope",            -- Sheet Rope (alternative)
            "Base.TwineLine",            -- Twine (alternative)
        },
        displayName = "Rope (or Sheet Rope, Twine)",
        weight = 0.5,
    },

    -- Welding supplies (for Part Replacement stage)
    WeldingRods = {
        itemTypes = {
            "Base.WeldingRods",          -- Welding Rods
        },
        displayName = "Welding Rods",
        weight = 0.5,
    },
}

-- Parts required per component type, per damage level
EPR.Repair.ComponentParts = {
    ControlPanel = {
        light = {"Electronics", "ElectricWire", "Screws"},
        medium = {"Electronics", "Electronics", "ElectricWire", "Screws", "Screws", "DuctTape"},
        heavy = {"Electronics", "Electronics", "Electronics", "ElectricWire", "ElectricWire", "Amplifier", "Screws", "Screws", "ScrapMetal", "DuctTape"},
    },
    Transformer = {
        light = {"Electronics", "ElectricWire", "Screws"},
        medium = {"Electronics", "ElectricWire", "ElectricWire", "Amplifier", "Screws", "ScrapMetal"},
        heavy = {"Electronics", "Electronics", "ElectricWire", "ElectricWire", "Amplifier", "Amplifier", "Screws", "ScrapMetal", "SmallSheetMetal", "DuctTape"},
    },
    CircuitBreakers = {
        light = {"ElectricWire", "Screws", "ScrapMetal"},
        medium = {"ElectricWire", "ElectricWire", "Screws", "ScrapMetal", "ScrapMetal", "SmallSheetMetal"},
        heavy = {"ElectricWire", "ElectricWire", "ElectricWire", "Screws", "ScrapMetal", "ScrapMetal", "SmallSheetMetal", "SmallSheetMetal", "SheetMetal", "DuctTape"},
    },
    CoolingSystem = {
        light = {"MetalPipe", "Screws"},
        medium = {"MetalPipe", "MetalPipe", "Screws", "DuctTape"},
        heavy = {"MetalPipe", "MetalPipe", "ScrapMetal", "Screws", "Screws", "DuctTape"},
    },
    PowerConduits = {
        light = {"ElectricWire", "ElectricWire", "DuctTape"},
        medium = {"ElectricWire", "ElectricWire", "ElectricWire", "DuctTape", "Screws"},
        heavy = {"ElectricWire", "ElectricWire", "ElectricWire", "ElectricWire", "DuctTape", "Screws", "ScrapMetal"},
    },
    SwitchGear = {
        light = {"Electronics", "Screws"},
        medium = {"Electronics", "ElectricWire", "Screws", "ScrapMetal"},
        heavy = {"Electronics", "Electronics", "ElectricWire", "Screws", "ScrapMetal", "SmallSheetMetal"},
    },
    BackupGenerator = {
        light = {"ScrapMetal", "Screws"},
        medium = {"ScrapMetal", "ScrapMetal", "MetalPipe", "Screws"},
        heavy = {"ScrapMetal", "ScrapMetal", "MetalPipe", "MetalPipe", "Screws", "DuctTape"},
    },
    GroundingSystem = {
        light = {"ElectricWire", "MetalBar"},
        medium = {"ElectricWire", "ElectricWire", "MetalBar", "Screws"},
        heavy = {"ElectricWire", "ElectricWire", "ElectricWire", "MetalBar", "MetalBar", "Screws"},
    },
    VoltageRegulator = {
        light = {"Electronics", "ElectricWire"},
        medium = {"Electronics", "Electronics", "ElectricWire", "Screws"},
        heavy = {"Electronics", "Electronics", "ElectricWire", "ElectricWire", "Amplifier", "Screws"},
    },
}

-- ============================================
-- SKILL DIALOGUE RESPONSES
-- ============================================

EPR.Repair.SkillDialogues = {
    "UI_EPR_Dialogue_NeedSkill",
    "UI_EPR_Dialogue_NeedSkill_Alt1",
    "UI_EPR_Dialogue_NeedSkill_Alt2",
    "UI_EPR_Dialogue_NeedSkill_Alt3",
    "UI_EPR_Dialogue_NeedSkill_Alt4",
    "UI_EPR_Dialogue_NeedSkill_Alt5",
}

function EPR.Repair.GetRandomSkillDialogue()
    local dialogues = {
        "I don't know how to do this...",
        "This is way beyond my expertise.",
        "I'd need more training for this.",
        "I have no idea where to even start.",
        "This equipment is too complex for me.",
        "I'd probably make it worse...",
    }
    local key = EPR.Repair.SkillDialogues[ZombRand(#EPR.Repair.SkillDialogues) + 1]
    local translated = getText(key)
    if translated and translated ~= key then
        return translated
    end
    return dialogues[ZombRand(#dialogues) + 1]
end

-- ============================================
-- RANDOM FACILITY STATE GENERATION
-- New repair flow:
-- Phase 1: Control Panel at main console (Assessment, PartReplacement, Calibration)
-- Phase 2: 2 randomly chosen field components (1-3 random stages each)
-- Final: Startup stage (triggers when all components repaired)
-- ============================================

-- Helper to select random stages for field components (1-3 stages)
function EPR.Repair.SelectRandomStages()
    local allStages = {"Assessment", "PartReplacement", "Calibration"}
    local numStages = ZombRand(1, 4)  -- 1 to 3 stages

    -- Shuffle the stages
    local shuffled = {}
    for _, stage in ipairs(allStages) do
        table.insert(shuffled, stage)
    end
    for i = #shuffled, 2, -1 do
        local j = ZombRand(i) + 1
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Take first numStages
    local selected = {}
    for i = 1, numStages do
        table.insert(selected, shuffled[i])
    end

    -- Sort by stage order
    local stageOrder = {Assessment = 1, PartReplacement = 2, Calibration = 3}
    table.sort(selected, function(a, b)
        return stageOrder[a] < stageOrder[b]
    end)

    return selected
end

-- Calculate skill requirement based on damage level
function EPR.Repair.CalculateSkillRequirement(damageLevel, baseSkill)
    local base = baseSkill or 5

    -- Get multiplier from sandbox
    local skillMult = 1.0
    if SandboxVars and SandboxVars.EPR and type(SandboxVars.EPR.SkillRequirementMultiplier) == "number" then
        skillMult = SandboxVars.EPR.SkillRequirementMultiplier
    end

    -- Add variation based on damage level
    local variation = 0
    if damageLevel == "heavy" then
        variation = ZombRand(0, 3)  -- +0 to +2 skill levels
    elseif damageLevel == "medium" then
        variation = ZombRand(-1, 2)  -- -1 to +1 skill levels
    else -- light
        variation = ZombRand(-2, 1)  -- -2 to 0 skill levels
    end

    local requirement = math.max(1, math.floor((base + variation) * skillMult))
    return math.min(10, requirement)  -- Cap at level 10
end

function EPR.Repair.GenerateRandomState(facility)
    if EPR.RepairState and EPR.RepairState.GenerateRandomState then
        return EPR.RepairState.GenerateRandomState(facility)
    end

    return {
        status = "offline",
        health = 0,
        repairProgress = 0,
        lastMaintenance = 0,
        repairQuality = 0,
        facilityKey = facility.key or facility.id,
        discovered = true,
        discoveredTime = getGameTime():getWorldAgeHours(),
        components = {},
        componentOrder = {},
        initialDamageLevel = 0,
        phase = 1,
    }
end

function EPR.Repair.GetPartsForComponent(componentType, damageLevel)
    local componentParts = EPR.Repair.ComponentParts[componentType]
    if not componentParts then
        componentParts = {light = {"Electronics", "ElectricWire", "Screws"}}
    end

    local parts = componentParts[damageLevel] or componentParts.light
    local result = {}

    -- Apply part requirement multiplier from sandbox
    local partMult = 1.0
    if SandboxVars.EPR and SandboxVars.EPR.PartRequirementMultiplier then
        partMult = SandboxVars.EPR.PartRequirementMultiplier
    end

    -- Count each unique part type
    local partCounts = {}
    for _, part in ipairs(parts) do
        partCounts[part] = (partCounts[part] or 0) + 1
    end

    -- Apply multiplier and add to result
    for part, count in pairs(partCounts) do
        local adjustedCount = math.max(1, math.ceil(count * partMult))
        for i = 1, adjustedCount do
            table.insert(result, part)
        end
    end

    return result
end

-- ============================================
-- PART & TOOL CHECKING
-- ============================================

function EPR.Repair.GetPartDisplayName(partKey)
    local partDef = EPR.Repair.Parts[partKey]
    if partDef then
        return partDef.displayName
    end
    return partKey
end

function EPR.Repair.GetToolDisplayName(toolKey)
    local toolDef = EPR.Repair.Tools[toolKey]
    if toolDef then
        return toolDef.displayName
    end
    return toolKey
end

function EPR.Repair.HasTool(player, toolKey)
    local toolDef = EPR.Repair.Tools[toolKey]
    if not toolDef then return false end

    local inv = player:getInventory()
    for _, itemType in ipairs(toolDef.itemTypes) do
        if inv:containsTypeRecurse(itemType) then
            -- Check propane for blow torch
            if toolDef.requiresPropane then
                local torch = inv:getFirstTypeRecurse(itemType)
                if torch and torch:getCurrentUses() > 0 then
                    return true, torch
                end
            else
                return true, inv:getFirstTypeRecurse(itemType)
            end
        end
    end

    return false
end

function EPR.Repair.HasPart(player, partKey)
    local inv = player:getInventory()
    local partDef = EPR.Repair.Parts[partKey]
    if partDef then
        for _, itemType in ipairs(partDef.itemTypes) do
            if inv:containsTypeRecurse(itemType) then
                return true, inv:getFirstTypeRecurse(itemType)
            end
        end
        return false
    end
    -- partKey is a raw item type string (e.g. "Base.ElectronicsScrap")
    if inv:containsTypeRecurse(partKey) then
        return true, inv:getFirstTypeRecurse(partKey)
    end
    return false
end

function EPR.Repair.CountPart(player, partKey)
    local inv = player:getInventory()
    local partDef = EPR.Repair.Parts[partKey]
    if partDef then
        local count = 0
        for _, itemType in ipairs(partDef.itemTypes) do
            local items = inv:getAllTypeRecurse(itemType)
            if items then count = count + items:size() end
        end
        return count
    end
    -- partKey is a raw item type string
    local items = inv:getAllTypeRecurse(partKey)
    return items and items:size() or 0
end

function EPR.Repair.ConsumePart(player, partKey)
    local inv = player:getInventory()
    local partDef = EPR.Repair.Parts[partKey]
    if partDef then
        for _, itemType in ipairs(partDef.itemTypes) do
            local item = inv:getFirstTypeRecurse(itemType)
            if item then
                inv:Remove(item)
                return true
            end
        end
        return false
    end
    -- partKey is a raw item type string
    local item = inv:getFirstTypeRecurse(partKey)
    if item then
        inv:Remove(item)
        return true
    end
    return false
end

function EPR.Repair.CheckStageTools(player, stageName)
    local stageDef = EPR.Repair.Stages[stageName]
    if not stageDef or not stageDef.tools then return true, nil end

    -- Check sandbox setting
    local requireTools = true
    if SandboxVars.EPR then
        requireTools = SandboxVars.EPR.RequireTools ~= false
    end

    if not requireTools then return true, nil end

    for _, toolKey in ipairs(stageDef.tools) do
        local hasTool = EPR.Repair.HasTool(player, toolKey)
        if not hasTool then
            return false, toolKey
        end
    end

    return true, nil
end

function EPR.Repair.CheckStageParts(player, compState, stageName)
    local stageDef = EPR.Repair.Stages[stageName]
    if not stageDef or not stageDef.consumesParts then return true, nil, nil end

    if not compState.partsNeeded then return true, nil, nil end

    -- Count needed parts
    local partCounts = {}
    for _, partKey in ipairs(compState.partsNeeded) do
        partCounts[partKey] = (partCounts[partKey] or 0) + 1
    end

    -- Subtract installed parts
    if compState.partsInstalled then
        for partKey, count in pairs(compState.partsInstalled) do
            partCounts[partKey] = (partCounts[partKey] or 0) - count
        end
    end

    -- Check if player has remaining needed parts
    for partKey, needed in pairs(partCounts) do
        if needed > 0 then
            local has = EPR.Repair.CountPart(player, partKey)
            if has < needed then
                return false, partKey, needed - has
            end
        end
    end

    return true, nil, nil
end

function EPR.Repair.DamageTool(player, toolKey)
    local toolDef = EPR.Repair.Tools[toolKey]
    if not toolDef or toolDef.damageOnUse == 0 then return end

    -- Check sandbox setting
    local toolsConsumed = true
    if SandboxVars.EPR then
        toolsConsumed = SandboxVars.EPR.ToolsConsumed ~= false
    end

    if not toolsConsumed then return end

    local hasTool, item = EPR.Repair.HasTool(player, toolKey)
    if hasTool and item and item.setCondition then
        local currentCond = item:getCondition()
        local newCond = math.max(0, currentCond - (toolDef.damageOnUse * 100))
        item:setCondition(math.floor(newCond))

        if newCond <= 0 then
            player:getInventory():Remove(item)
            player:Say("My " .. toolDef.displayName .. " broke!")
        end
    end
end

-- ============================================
-- REPAIR STATE MANAGEMENT
-- ============================================

function EPR.Repair.GetFacilityState(facility)
    if not facility or not facility.id or not facility.type then
        return {
            status = "unknown",
            components = {},
            componentOrder = {},
            discovered = true,
        }
    end

    local function tableHasEntries(tbl)
        if type(tbl) ~= "table" then return false end
        if type(pairs) ~= "function" then
            return true
        end
        for _ in pairs(tbl) do
            return true
        end
        return false
    end

    local state = nil

    if facility.type == "power" or facility.type == "combined" then
        state = EPR.Substations[facility.id]
    elseif facility.type == "water" then
        state = EPR.WaterPlants[facility.id]
    end

    local hasComponents = state and tableHasEntries(state.components)
    local isMP = EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer()
    local syncReady = (not isMP) or (EPR.Client and EPR.Client.syncCompleted)
    if not state or not hasComponents then
        if isMP and not syncReady then
            if EPR.Client and EPR.Client.RequestSync then
                EPR.Client.RequestSync()
            end
            return {
                status = "syncing",
                components = {},
                componentOrder = {},
                discovered = true,
            }
        end

        if isMP and state and not hasComponents then
            -- Server sent a minimal shell; initialize full state locally and push back.
        end

        local previous = state
        state = EPR.Repair.GenerateRandomState(facility)

        if previous then
            state.status = previous.status or state.status
            state.health = previous.health or state.health
            state.lastMaintenance = previous.lastMaintenance or state.lastMaintenance
            state.repairQuality = previous.repairQuality or state.repairQuality

            if state.status == "ready" or state.status == "starting" or state.status == "online" then
                if state.components then
                    for _, compState in pairs(state.components) do
                        compState.status = "repaired"
                        compState.currentStage = nil
                        compState.stageProgress = 0
                        compState.stagesCompleted = {
                            Assessment = true,
                            PartReplacement = true,
                            Calibration = true,
                            Startup = true,
                        }
                    end
                end
            end
        end

        if facility.type == "power" or facility.type == "combined" then
            EPR.Substations[facility.id] = state
        end
        if facility.type == "water" or facility.type == "combined" then
            EPR.WaterPlants[facility.id] = state
        end

        EPR.SaveData()

        if isMP and syncReady and isServer() then
            if EPR.Client and EPR.Client.SendCommand then
                EPR.Client.SendCommand("UpdateFacilityState", {
                    facilityId = facility.id,
                    facilityType = facility.type,
                    state = state,
                })
            end
        end
    elseif state.discovered == nil then
        state.discovered = true
    end

    return state
end

function EPR.Repair.SetFacilityState(facility, state)
    if facility.type == "power" or facility.type == "combined" then
        EPR.Substations[facility.id] = state
    end
    if facility.type == "water" or facility.type == "combined" then
        EPR.WaterPlants[facility.id] = state
    end
    saveIfAuthoritative()

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() and isServer() then
        if EPR.Client.SendCommand then
            EPR.Client.SendCommand("UpdateFacilityState", {
                facilityId = facility.id,
                facilityType = facility.type,
                state = state,
            })
        end
    end
end

function EPR.Repair.AreAllComponentsRepaired(state)
    if not state.components then
        print("[EPR DEBUG] AreAllComponentsRepaired: no components table")
        return false
    end

    for compType, compState in pairs(state.components) do
        print("[EPR DEBUG] AreAllComponentsRepaired: " .. tostring(compType) .. " status=" .. tostring(compState.status))
        if compState.status ~= "functional" and compState.status ~= "repaired" then
            print("[EPR DEBUG] AreAllComponentsRepaired: " .. tostring(compType) .. " NOT repaired, returning false")
            return false
        end
    end
    print("[EPR DEBUG] AreAllComponentsRepaired: ALL components repaired, returning true")
    print("[EPR DEBUG] Current facility status before change: " .. tostring(state.status))
    return true
end

function EPR.Repair.GetDamagedComponentCount(state)
    local count = 0
    if state.components then
        for compType, compState in pairs(state.components) do
            if compState.status == "damaged" or compState.status == "repairing" then
                count = count + 1
            end
        end
    end
    return count
end

-- ============================================
-- SKILL CALCULATIONS
-- ============================================

function EPR.Repair.GetSkillTimeMultiplier(player, facility, stageName)
    local requirements = nil

    if facility.type == "power" or facility.type == "combined" then
        requirements = EPR.Config.SubstationSkills
    elseif facility.type == "water" then
        requirements = EPR.Config.WaterPlantSkills
    end

    if not requirements then return 1.0 end

    local stageDef = EPR.Repair.Stages[stageName]
    local skillWeight = stageDef and stageDef.skillWeight or 0.3

    local totalExcess = 0
    local skillCount = 0

    for skill, reqLevel in pairs(requirements) do
        local perk = Perks[skill]
        if perk then
            local playerLevel = player:getPerkLevel(perk)
            local excess = playerLevel - reqLevel
            totalExcess = totalExcess + excess
            skillCount = skillCount + 1
        end
    end

    if skillCount == 0 then return 1.0 end

    local avgExcess = totalExcess / skillCount
    local reduction = math.min(skillWeight, math.max(0, avgExcess * 0.05))

    return 1.0 - reduction
end

function EPR.Repair.GetStageTime(player, facility, stageName)
    local stageDef = EPR.Repair.Stages[stageName]
    if not stageDef then return 60 end

    local baseMinutes = stageDef.baseTimeMinutes

    -- Get from sandbox settings
    if SandboxVars.EPR then
        if stageName == "Assessment" and SandboxVars.EPR.AssessmentTimeMinutes then
            baseMinutes = SandboxVars.EPR.AssessmentTimeMinutes
        elseif stageName == "PartReplacement" and SandboxVars.EPR.PartReplacementTimeMinutes then
            baseMinutes = SandboxVars.EPR.PartReplacementTimeMinutes
        elseif stageName == "Calibration" and SandboxVars.EPR.CalibrationTimeMinutes then
            baseMinutes = SandboxVars.EPR.CalibrationTimeMinutes
        elseif stageName == "Startup" and SandboxVars.EPR.StartupDefenseTimeMinutes then
            baseMinutes = SandboxVars.EPR.StartupDefenseTimeMinutes
        end
    end

    local skillMult = EPR.Repair.GetSkillTimeMultiplier(player, facility, stageName)
    local difficultyMod = facility.repairDifficulty or 1.0

    local actualMinutes = baseMinutes * skillMult * difficultyMod

    -- Global repair speed multiplier
    if SandboxVars.EPR and SandboxVars.EPR.RepairSpeedMultiplier then
        actualMinutes = actualMinutes * SandboxVars.EPR.RepairSpeedMultiplier
    end

    -- Convert to game ticks (approx 1 minute = 60 ticks at normal speed)
    return actualMinutes * 60
end


-- Check player skills against component-specific requirements
-- compState is optional - if provided, uses stored skill requirements from component state
function EPR.Repair.CheckPlayerSkills(player, facility, compState)
    -- Safety check for required globals
    if not player then
        print("[EPR] CheckPlayerSkills: missing player")
        return true
    end
    if not facility then
        print("[EPR] CheckPlayerSkills: missing facility")
        return true
    end

    -- Debug mode bypasses skill requirements
    if (EPR and EPR.IsDebugMode and EPR.IsDebugMode())
        or (SandboxVars and SandboxVars.EPR and (SandboxVars.EPR.DebugMode == true or SandboxVars.EPR.DebugMode == 1 or SandboxVars.EPR.DebugMode == "true")) then
        print("[EPR] Debug mode enabled - bypassing skill requirements")
        return true
    end

    -- Build requirements - prefer component-specific stored requirements
    local requirements = {}

    if compState and compState.skillRequirements and compState.skillRequirements.Electricity then
        -- Use stored skill requirements from component state (already randomized based on damage)
        for skill, level in pairs(compState.skillRequirements) do
            requirements[skill] = level
        end
        -- Debug disabled to prevent spam
        -- print("[EPR] Using component-specific skill requirements: Electricity=" ..
        --       tostring(requirements.Electricity) .. ", Welding=" .. tostring(requirements.Welding))
    elseif compState then
        -- Generate skill requirements on the fly for old save compatibility
        local damageLevel = compState.damageLevel or "medium"
        local baseElecSkill = 5
        local baseWeldSkill = 4
        if SandboxVars and SandboxVars.EPR then
            if type(SandboxVars.EPR.MinElectricalSkill) == "number" then
                baseElecSkill = SandboxVars.EPR.MinElectricalSkill
            end
            if type(SandboxVars.EPR.MinMetalworkSkill) == "number" then
                baseWeldSkill = SandboxVars.EPR.MinMetalworkSkill
            end
        end
        requirements.Electricity = EPR.Repair.CalculateSkillRequirement(damageLevel, baseElecSkill)
        requirements.Welding = EPR.Repair.CalculateSkillRequirement(damageLevel, baseWeldSkill)
        -- Store for future use
        compState.skillRequirements = {
            Electricity = requirements.Electricity,
            Welding = requirements.Welding,
        }
        -- Debug disabled to prevent spam
        -- print("[EPR] Generated skill requirements for old save: Electricity=" ..
        --       tostring(requirements.Electricity) .. ", Welding=" .. tostring(requirements.Welding))
    else
        -- Fallback to facility-based requirements (for backwards compatibility)
        local facilityType = facility.type
        if not facilityType then
            print("[EPR] CheckPlayerSkills: facility has no type")
            return true
        end

        local skillMult = 1.0
        if SandboxVars and SandboxVars.EPR and type(SandboxVars.EPR.SkillRequirementMultiplier) == "number" then
            skillMult = SandboxVars.EPR.SkillRequirementMultiplier
        end

        local defaultElecSkill = 7
        local defaultMetalSkill = 4

        if facilityType == "power" or facilityType == "combined" then
            local elecSkill = defaultElecSkill
            local metalSkill = defaultMetalSkill

            if EPR.Config and EPR.Config.SubstationSkills then
                if type(EPR.Config.SubstationSkills.Electrical) == "number" then
                    elecSkill = EPR.Config.SubstationSkills.Electrical
                end
                if type(EPR.Config.SubstationSkills.MetalWelding) == "number" then
                    metalSkill = EPR.Config.SubstationSkills.MetalWelding
                end
            end

            if SandboxVars and SandboxVars.EPR then
                if type(SandboxVars.EPR.MinElectricalSkill) == "number" then
                    elecSkill = SandboxVars.EPR.MinElectricalSkill
                end
                if type(SandboxVars.EPR.MinMetalworkSkill) == "number" then
                    metalSkill = SandboxVars.EPR.MinMetalworkSkill
                end
            end

            requirements.Electricity = math.ceil(elecSkill * skillMult)
            requirements.Welding = math.ceil(metalSkill * skillMult)

        elseif facilityType == "water" then
            local elecSkill = 5
            local metalSkill = 5

            if EPR.Config and EPR.Config.WaterPlantSkills then
                if type(EPR.Config.WaterPlantSkills.Electrical) == "number" then
                    elecSkill = EPR.Config.WaterPlantSkills.Electrical
                end
                if type(EPR.Config.WaterPlantSkills.MetalWelding) == "number" then
                    metalSkill = EPR.Config.WaterPlantSkills.MetalWelding
                end
            end

            if SandboxVars and SandboxVars.EPR then
                if type(SandboxVars.EPR.WaterPlantElectricalSkill) == "number" then
                    elecSkill = SandboxVars.EPR.WaterPlantElectricalSkill
                end
                if type(SandboxVars.EPR.WaterPlantMetalworkSkill) == "number" then
                    metalSkill = SandboxVars.EPR.WaterPlantMetalworkSkill
                end
            end

            requirements.Electricity = math.ceil(elecSkill * skillMult)
            requirements.Welding = math.ceil(metalSkill * skillMult)
        end
    end

    -- No requirements = pass
    local hasRequirements = false
    for _ in pairs(requirements) do
        hasRequirements = true
        break
    end
    if not hasRequirements then return true end

    -- Check if Perks global exists
    if not Perks then
        print("[EPR] CheckPlayerSkills: Perks global not available")
        return true
    end

    -- Check each required skill
    for skill, reqLevel in pairs(requirements) do
        if reqLevel and type(reqLevel) == "number" then
            -- Try to find the perk - handle potential naming differences in B42
            local perk = Perks[skill]
            local perkName = skill

            -- Fallback perk names for B42 compatibility
            if not perk then
                if skill == "Welding" then
                    perk = Perks.MetalWelding
                    perkName = "MetalWelding"
                elseif skill == "Electricity" then
                    perk = Perks.Electrical
                    perkName = "Electrical"
                end
            end

            if perk then
                local playerLevel = 0
                if player and player.getPerkLevel then
                    local success, result = pcall(function()
                        return player:getPerkLevel(perk)
                    end)
                    if success and result then
                        playerLevel = result
                    end
                end
                -- Debug disabled to prevent spam
                -- print("[EPR] Skill check: " .. perkName .. " requires " .. reqLevel .. ", player has " .. playerLevel)
                if playerLevel < reqLevel then
                    return false, skill, reqLevel, playerLevel
                end
            else
                print("[EPR] WARNING: Perk not found: " .. tostring(skill) .. " (tried fallbacks too)")
            end
        end
    end

    return true
end

-- ============================================
-- TIMED ACTION: STAGE REPAIR
-- ============================================

EPR_StageRepairAction = ISBaseTimedAction:derive("EPR_StageRepairAction")

function EPR_StageRepairAction:new(player, facility, state, componentType, stageName)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = player
    o.facility = facility
    o.state = state
    o.componentType = componentType
    o.stageName = stageName
    o.compState = state.components[componentType]
    o.compDef = EPR.Components[componentType]
    o.stageDef = EPR.Repair.Stages[stageName]

    o.maxTime = EPR.Repair.GetStageTime(player, facility, stageName)

    -- Respect previous progress
    if o.compState.currentStage == stageName and o.compState.stageProgress > 0 then
        o.startProgress = o.compState.stageProgress
        o.maxTime = o.maxTime * (1 - o.compState.stageProgress / 100)
    else
        o.startProgress = 0
    end

    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = true
    o.caloriesModifier = 5

    return o
end

function EPR_StageRepairAction:isValid()
    local px = self.character:getX()
    local py = self.character:getY()
    local dx = self.compState.x - px
    local dy = self.compState.y - py
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 15 then
        return false
    end

    return true
end

function EPR_StageRepairAction:waitToStart()
    self.character:faceLocation(self.compState.x, self.compState.y)
    return self.character:shouldBeTurning()
end

function EPR_StageRepairAction:start()
    self.compState.status = "repairing"
    self.compState.currentStage = self.stageName
    self.state.status = "repairing"
    EPR.Repair.SetFacilityState(self.facility, self.state)

    self:setActionAnim("Loot")

    -- Stage-specific dialogue
    local dialogues = {
        Assessment = getText("UI_EPR_Dialogue_StartAssessment") or "Let me take a look at this...",
        PartReplacement = getText("UI_EPR_Dialogue_StartReplacement") or "Time to swap out these parts.",
        Calibration = getText("UI_EPR_Dialogue_StartCalibration") or "Now for the delicate work...",
        Startup = getText("UI_EPR_Dialogue_StartStartup") or "Here goes nothing... stay alert!",
    }

    self.character:Say(dialogues[self.stageName] or "Working...")

    -- Play work sound
    if ZombRand(100) < 50 then
        self.character:getEmitter():playSound("MetalBarCreak")
    end

    -- Startup attracts zombies immediately
    if self.stageDef.attractsZombies then
        EPR.Repair.TriggerNoise(self.facility, self.stageDef.noiseRadius, self.stageDef.attractsZombies)
        HaloTextHelper.addTextWithArrow(self.character, "STARTUP SEQUENCE - DEFEND!", true, HaloTextHelper.getColorRed())
    end
end

function EPR_StageRepairAction:update()
    local progress = self.startProgress + (self:getJobDelta() * (100 - self.startProgress))
    self.compState.stageProgress = math.min(100, progress)

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() and not isServer() then
        local now = (getTimestampMs and getTimestampMs()) or ((getGameTime and getGameTime():getWorldAgeHours() or 0) * 3600000)
        self._lastProgressSent = self._lastProgressSent or -1
        self._lastProgressSentAt = self._lastProgressSentAt or 0
        if now - self._lastProgressSentAt >= 1000 then
            local current = math.floor(self.compState.stageProgress or 0)
            if math.abs(current - self._lastProgressSent) >= 5 then
                self._lastProgressSent = current
                self._lastProgressSentAt = now
                if EPR.Client.NotifyStageProgress then
                    EPR.Client.NotifyStageProgress(self.facility.id, self.componentType, self.stageName, current)
                end
            end
        end
    end

    -- Periodic sounds and noise
    if ZombRand(100) < 3 then
        self.character:getEmitter():playSound("MetalBarCreak")
    end

    -- Continuous noise during startup
    if self.stageDef.attractsZombies then
        EPR.Repair.TriggerNoise(self.facility, self.stageDef.noiseRadius, self.stageDef.attractsZombies)
    elseif self.stageDef.noiseRadius > 0 and ZombRand(100) < 5 then
        EPR.Repair.TriggerNoise(self.facility, self.stageDef.noiseRadius, self.stageDef.attractsZombies)
    end
end

function EPR_StageRepairAction:stop()
    -- stageProgress is kept current by update(); just persist it without recalculating
    EPR.Repair.SetFacilityState(self.facility, self.state)

    self.character:Say(getText("UI_EPR_Dialogue_Interrupted") or "I'll continue later...")

    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() and not isServer() then
        local current = math.floor(self.compState.stageProgress or 0)
        if EPR.Client.NotifyStageProgress then
            EPR.Client.NotifyStageProgress(self.facility.id, self.componentType, self.stageName, current)
        end
        -- Release the server-side repair lock so an interrupted repair (walked/
        -- ran/aimed away) can be resumed without a server restart (Bug 1).
        if EPR.Client.CancelRepair then
            EPR.Client.CancelRepair()
        end
    end

    ISBaseTimedAction.stop(self)
end

function EPR_StageRepairAction:perform()
    -- Mark stage as complete
    self.compState.stagesCompleted[self.stageName] = true
    self.compState.stageProgress = 0

    -- Consume parts if this was Part Replacement stage
    if self.stageDef.consumesParts and self.compState.partsNeeded then
        local partCounts = {}
        for _, partKey in ipairs(self.compState.partsNeeded) do
            partCounts[partKey] = (partCounts[partKey] or 0) + 1
        end

        if not self.compState.partsInstalled then
            self.compState.partsInstalled = {}
        end

        for partKey, needed in pairs(partCounts) do
            local installed = self.compState.partsInstalled[partKey] or 0
            local toInstall = needed - installed
            for i = 1, toInstall do
                if EPR.Repair.ConsumePart(self.character, partKey) then
                    self.compState.partsInstalled[partKey] = (self.compState.partsInstalled[partKey] or 0) + 1
                end
            end
        end
    end

    -- Damage tools
    if self.stageDef.tools then
        for _, toolKey in ipairs(self.stageDef.tools) do
            EPR.Repair.DamageTool(self.character, toolKey)
        end
    end

    -- Stage-specific completion dialogue
    local dialogues = {
        Assessment = getText("UI_EPR_Dialogue_FinishAssessment") or "I know what needs to be done now.",
        PartReplacement = getText("UI_EPR_Dialogue_FinishReplacement") or "Parts installed. Almost there.",
        Calibration = getText("UI_EPR_Dialogue_FinishCalibration") or "Systems calibrated. Ready for startup.",
        Startup = getText("UI_EPR_Dialogue_FinishStartup") or "It's running! We did it!",
    }

    self.character:Say(dialogues[self.stageName] or "Done!")

    -- Find next stage
    local nextStage = EPR.Repair.GetNextStage(self.compState)

    if nextStage then
        -- Move to next stage
        self.compState.currentStage = nextStage

        local compName = self.compDef and self.compDef.name or self.componentType
        local nextStageDef = EPR.Repair.Stages[nextStage]
        local nextStageName = nextStageDef and nextStageDef.name or nextStage

        HaloTextHelper.addTextWithArrow(self.character, compName .. ": " .. nextStageName .. " next", true, HaloTextHelper.getColorWhite())
    else
        -- Component fully repaired
        self.compState.status = "repaired"
        self.compState.currentStage = nil

        local compName = self.compDef and self.compDef.name or self.componentType
        HaloTextHelper.addTextWithArrow(self.character, compName .. " REPAIRED!", true, HaloTextHelper.getColorGreen())

        -- Check if all components done
        if EPR.Repair.AreAllComponentsRepaired(self.state) then
            -- All components repaired - set to "ready" state (requires manual startup from terminal)
            self.state.status = "ready"
            EPR.Repair.SetFacilityState(self.facility, self.state)
            HaloTextHelper.addTextWithArrow(self.character, "All repairs complete! Return to Control Panel to start facility.", true, HaloTextHelper.getColorGreen())
            self.character:Say(getText("UI_EPR_Dialogue_ReadyForStartup") or "Everything's repaired. Time to fire it up from the control panel!")
        else
            local remaining = EPR.Repair.GetDamagedComponentCount(self.state)
            HaloTextHelper.addTextWithArrow(self.character, remaining .. " component(s) remaining", true, HaloTextHelper.getColorWhite())
        end
    end

    EPR.Repair.SetFacilityState(self.facility, self.state)
    EPR.Repair.AwardStageXP(self.character, self.stageName, self.componentType)

    -- Notify server in MP mode
    if EPR.Client and EPR.Client.NotifyStageComplete then
        EPR.Client.NotifyStageComplete(self.facility.id, self.componentType, self.stageName)
    end

    ISBaseTimedAction.perform(self)
end

-- ============================================
-- STAGE MANAGEMENT
-- ============================================

function EPR.Repair.GetNextStage(compState)
    if not compState.stagesCompleted then
        compState.stagesCompleted = {}
    end

    -- Use component-specific required stages if available
    local stageOrder = compState.requiredStages or EPR.Repair.StageOrder

    for _, stageName in ipairs(stageOrder) do
        if not compState.stagesCompleted[stageName] then
            return stageName
        end
    end

    return nil  -- All required stages complete
end

function EPR.Repair.GetCurrentStageName(compState)
    if compState.currentStage then
        return compState.currentStage
    end
    return EPR.Repair.GetNextStage(compState)
end

-- ============================================
-- REPAIR ENTRY POINT
-- ============================================

function EPR.Repair.StartComponentRepair(player, facility, componentType, skipRequest)
    local state = EPR.Repair.GetFacilityState(facility)
    local isMP = EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer()

    -- Check if facility can be repaired
    local canRepair, reason = EPR.Zones.CanRepairFacility(facility.id)
    if not canRepair then
        player:Say(reason or "Cannot repair this facility yet.")
        return false
    end

    -- Get component state first (needed for skill check)
    local compState = state.components[componentType]
    if not compState then
        player:Say("Repair point not found.")
        return false
    end

    -- Check skills (uses component-specific requirements if available)
    local meetsSkills, missingSkill, reqLevel, playerLevel = EPR.Repair.CheckPlayerSkills(player, facility, compState)
    if not meetsSkills then
        local compDef = EPR.Components and EPR.Components[componentType]
        local compName = compDef and compDef.name or componentType
        player:Say(EPR.Repair.GetRandomSkillDialogue())
        -- Show specific requirement
        if missingSkill and reqLevel and playerLevel then
            HaloTextHelper.addTextWithArrow(player, compName .. " requires " .. missingSkill .. " " .. reqLevel .. " (you have " .. playerLevel .. ")", true, HaloTextHelper.getColorRed())
        end
        return false
    end

    if compState.status == "functional" or compState.status == "repaired" then
        player:Say("This component is already functional.")
        return false
    end

    -- Determine current stage
    local currentStage = EPR.Repair.GetCurrentStageName(compState)
    if not currentStage then
        player:Say("This component is already repaired.")
        return false
    end

    -- Check tools for this stage
    local hasTools, missingTool = EPR.Repair.CheckStageTools(player, currentStage)
    if not hasTools then
        local toolName = EPR.Repair.GetToolDisplayName(missingTool)
        player:Say(getText("UI_EPR_Dialogue_NeedTools") or "I need a " .. toolName)
        return false
    end

    -- Check parts for this stage (only Part Replacement consumes)
    local hasParts, missingPart, missingCount = EPR.Repair.CheckStageParts(player, compState, currentStage)
    if not hasParts then
        local partName = EPR.Repair.GetPartDisplayName(missingPart)
        player:Say((getText("UI_EPR_Dialogue_NeedParts") or "I need more parts") .. " - " .. partName)
        return false
    end

    -- MP client: ask server to start repair, wait for confirmation
    if isMP and not isServer() and not skipRequest then
        EPR.Repair.PendingRepair = { facilityId = facility.id, componentType = componentType }
        if EPR.Client and EPR.Client.RequestRepair then
            EPR.Client.RequestRepair(facility.id, componentType)
            return true
        end
        return false
    end

    -- Start the stage repair action
    local action = EPR_StageRepairAction:new(player, facility, state, componentType, currentStage)
    ISTimedActionQueue.add(action)

    return true
end

-- ============================================
-- FACILITY ONLINE
-- ============================================

function EPR.Repair.BringFacilityOnline(player, facility, state)
    print("[EPR] BringFacilityOnline called for: " .. tostring(facility.name))

    state.status = "online"
    state.health = 100
    state.lastMaintenance = getGameTime():getWorldAgeHours()
    state.repairQuality = EPR.Repair.CalculateRepairQuality(player, facility)

    -- Save facility state
    EPR.Repair.SetFacilityState(facility, state)

    -- SP/host: apply zone power/water locally (server handles this in MP)
    if EPR.IsServerContext and EPR.IsServerContext() then
        if facility.powersZones then
            for _, zoneName in ipairs(facility.powersZones) do
                EPR.PoweredZones[zoneName] = true
                if EPR.Buildings and EPR.Buildings.ApplyZonePower then
                    EPR.Buildings.ApplyZonePower(zoneName, true)
                end
            end
        end
        if facility.watersZones then
            for _, zoneName in ipairs(facility.watersZones) do
                EPR.WaterZones[zoneName] = true
                if EPR.Buildings and EPR.Buildings.ApplyZoneWater then
                    EPR.Buildings.ApplyZoneWater(zoneName, true)
                end
            end
        end
        if EPR.Zones and EPR.Zones.UpdateZoneStatus then
            EPR.Zones.UpdateZoneStatus()
        end
        saveIfAuthoritative()
    end

    -- Notify PowerController to check network status
    if EPR.PowerController and EPR.PowerController.OnFacilityOnline then
        EPR.PowerController.OnFacilityOnline(facility.id)
    end

    local successMsg = facility.name .. " is now ONLINE!"
    player:Say(successMsg)
    HaloTextHelper.addTextWithArrow(player, successMsg, true, HaloTextHelper.getColorGreen())

    EPR.Repair.AwardFacilityXP(player, facility)

    -- Notify server in MP mode
    if EPR.Client and EPR.Client.NotifyFacilityOnline then
        EPR.Client.NotifyFacilityOnline(facility.id)
    end

    print("[EPR] Facility activated: " .. facility.name)

    -- Debug: Show network status
    if EPR.PowerController and EPR.PowerController.DebugStatus then
        EPR.PowerController.DebugStatus()
    end
end

-- ============================================
-- FACILITY STARTUP (Manual trigger from Control Panel)
-- ============================================

function EPR.Repair.StartFacilityStartup(player, facility, state)
    -- Verify all components are repaired
    if not EPR.Repair.AreAllComponentsRepaired(state) then
        player:Say(getText("UI_EPR_Dialogue_NotReady") or "Not all components are repaired yet!")
        return false
    end

    -- Check if facility is in "ready" state
    if state.status ~= "ready" then
        if state.status == "online" then
            player:Say("This facility is already running.")
        else
            player:Say("The facility isn't ready for startup yet.")
        end
        return false
    end

    -- Check skills
    local meetsSkills, missingSkill, reqLevel, playerLevel = EPR.Repair.CheckPlayerSkills(player, facility, nil)
    if not meetsSkills then
        player:Say(EPR.Repair.GetRandomSkillDialogue())
        if missingSkill and reqLevel and playerLevel then
            HaloTextHelper.addTextWithArrow(player, "Startup requires " .. missingSkill .. " " .. reqLevel .. " (you have " .. playerLevel .. ")", true, HaloTextHelper.getColorRed())
        end
        return false
    end

    -- Start the startup action
    local action = EPR_FacilityStartupAction:new(player, facility, state)
    ISTimedActionQueue.add(action)

    return true
end

-- ============================================
-- TIMED ACTION: FACILITY STARTUP
-- ============================================

EPR_FacilityStartupAction = ISBaseTimedAction:derive("EPR_FacilityStartupAction")

function EPR_FacilityStartupAction:new(player, facility, state)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = player
    o.facility = facility
    o.state = state

    -- Get startup time from config/sandbox
    local baseMinutes = 5
    if SandboxVars.EPR and SandboxVars.EPR.StartupDefenseTimeMinutes then
        baseMinutes = SandboxVars.EPR.StartupDefenseTimeMinutes
    end

    -- Global repair speed multiplier
    if SandboxVars.EPR and SandboxVars.EPR.RepairSpeedMultiplier then
        baseMinutes = baseMinutes * SandboxVars.EPR.RepairSpeedMultiplier
    end

    o.maxTime = baseMinutes * 60  -- Convert to ticks

    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = true
    o.caloriesModifier = 5

    -- Noise settings
    o.noiseRadius = 150
    if SandboxVars.EPR and SandboxVars.EPR.StartupNoiseRadius then
        o.noiseRadius = SandboxVars.EPR.StartupNoiseRadius
    end

    return o
end

function EPR_FacilityStartupAction:isValid()
    local px = self.character:getX()
    local py = self.character:getY()
    local dx = self.facility.x - px
    local dy = self.facility.y - py
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 15 then
        return false
    end

    return true
end

function EPR_FacilityStartupAction:waitToStart()
    self.character:faceLocation(self.facility.x, self.facility.y)
    return self.character:shouldBeTurning()
end

function EPR_FacilityStartupAction:start()
    self.state.status = "starting"
    EPR.Repair.SetFacilityState(self.facility, self.state)

    self:setActionAnim("Loot")

    self.character:Say(getText("UI_EPR_Dialogue_StartStartup") or "Initiating startup sequence... Stay alert!")
    HaloTextHelper.addTextWithArrow(self.character, "STARTUP SEQUENCE - DEFEND THE AREA!", true, HaloTextHelper.getColorRed())

    -- Immediate zombie attraction
    EPR.Repair.TriggerNoise(self.facility, self.noiseRadius, true)
end

function EPR_FacilityStartupAction:update()
    -- Continuous noise during startup - this is the defense phase!
    EPR.Repair.TriggerNoise(self.facility, self.noiseRadius, true)

    -- Periodic sounds
    if ZombRand(100) < 5 then
        self.character:getEmitter():playSound("MetalBarCreak")
    end
end

function EPR_FacilityStartupAction:stop()
    -- Startup was interrupted - revert to ready state
    self.state.status = "ready"
    EPR.Repair.SetFacilityState(self.facility, self.state)

    self.character:Say(getText("UI_EPR_Dialogue_StartupAborted") or "Startup aborted! We'll have to try again.")
    HaloTextHelper.addTextWithArrow(self.character, "Startup aborted - return to Control Panel to retry", true, HaloTextHelper.getColorRed())

    ISBaseTimedAction.stop(self)
end

function EPR_FacilityStartupAction:perform()
    -- Startup complete - bring facility online!
    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() and not isServer() then
        if EPR.Client.NotifyFacilityOnline then
            EPR.Client.NotifyFacilityOnline(self.facility.id)
        end
        ISBaseTimedAction.perform(self)
        return
    end
    EPR.Repair.BringFacilityOnline(self.character, self.facility, self.state)

    ISBaseTimedAction.perform(self)
end

-- ============================================
-- REPAIR HELPERS
-- ============================================

function EPR.Repair.CalculateRepairQuality(player, facility)
    local skillMult = EPR.Repair.GetSkillTimeMultiplier(player, facility, "Calibration")
    local quality = 1.0 + (1.0 - skillMult)
    quality = quality + (ZombRand(-10, 11) / 100)
    return math.max(0.5, math.min(1.5, quality))
end

function EPR.Repair.TriggerNoise(facility, radius, isStartup)
    local noiseEnabled = true
    if SandboxVars.EPR then
        noiseEnabled = SandboxVars.EPR.ZombieAttractionEnabled ~= false
    end

    if not noiseEnabled then return end

    -- Override radius from sandbox options if available
    local baseRadius = radius
    if SandboxVars.EPR then
        if isStartup and SandboxVars.EPR.StartupNoiseRadius then
            baseRadius = SandboxVars.EPR.StartupNoiseRadius
        elseif not isStartup and SandboxVars.EPR.RepairNoiseRadius then
            baseRadius = SandboxVars.EPR.RepairNoiseRadius
        end
    end

    local noiseMult = 1.0
    if SandboxVars.EPR and SandboxVars.EPR.ZombieAttractionMultiplier then
        noiseMult = SandboxVars.EPR.ZombieAttractionMultiplier
    end

    local actualRadius = math.floor(baseRadius * noiseMult)
    addSound(nil, facility.x, facility.y, 0, actualRadius, actualRadius)
end

function EPR.Repair.AwardStageXP(player, stageName, componentType)
    local xpAmounts = {
        Assessment = 5,
        PartReplacement = 15,
        Calibration = 10,
        Startup = 20,
    }

    local xp = xpAmounts[stageName] or 5

    local compDef = EPR.Components[componentType]
    local primarySkill = compDef and compDef.repairSkill or "Electricity"
    local perk = Perks[primarySkill]
    if perk then
        player:getXp():AddXP(perk, xp)
    end
end

function EPR.Repair.AwardFacilityXP(player, facility)
    local xpReward = {
        power = {Electricity = 60, Welding = 40},
        water = {Electricity = 50, Welding = 50},
        combined = {Electricity = 55, Welding = 45},
    }

    local rewards = xpReward[facility.type] or xpReward.power

    for skill, xp in pairs(rewards) do
        local perk = Perks[skill]
        if perk then
            player:getXp():AddXP(perk, xp)
        end
    end

    print("[EPR] XP awarded for completing: " .. facility.name)
end

-- ============================================
-- MAINTENANCE (unchanged from before)
-- ============================================

function EPR.Repair.StartMaintenance(player, facility)
    local state = EPR.Repair.GetFacilityState(facility)

    if state.status ~= "online" then
        player:Say("This facility isn't online.")
        return false
    end

    if state.health >= 95 then
        player:Say("This facility doesn't need maintenance.")
        return false
    end

    local action = EPR_MaintenanceAction:new(player, facility, state)
    ISTimedActionQueue.add(action)

    return true
end

EPR_MaintenanceAction = ISBaseTimedAction:derive("EPR_MaintenanceAction")

function EPR_MaintenanceAction:new(player, facility, state)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = player
    o.facility = facility
    o.state = state

    o.maxTime = 300
    local skillMult = EPR.Repair.GetSkillTimeMultiplier(player, facility, "Calibration")
    o.maxTime = o.maxTime * skillMult

    o.stopOnWalk = false
    o.stopOnRun = true
    o.caloriesModifier = 2

    return o
end

function EPR_MaintenanceAction:isValid()
    local px = self.character:getX()
    local py = self.character:getY()
    local dx = self.facility.x - px
    local dy = self.facility.y - py
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist <= 50
end

function EPR_MaintenanceAction:start()
    self:setActionAnim("Loot")
    self.character:Say(getText("UI_EPR_Action_Maintaining") or "Performing maintenance...")
end

function EPR_MaintenanceAction:perform()
    local healthGain = 20 + ZombRand(10, 20)
    self.state.health = math.min(100, self.state.health + healthGain)
    self.state.lastMaintenance = getGameTime():getWorldAgeHours()

    EPR.Repair.SetFacilityState(self.facility, self.state)

    self.character:Say((getText("UI_EPR_Notify_MaintenanceComplete") or "Maintenance complete!") .. " Health: " .. math.floor(self.state.health) .. "%")

    self.character:getXp():AddXP(Perks.Mechanics, 5)
    self.character:getXp():AddXP(Perks.Electricity, 5)

    ISBaseTimedAction.perform(self)
end

function EPR_MaintenanceAction:stop()
    self.character:Say("Maintenance interrupted.")
    ISBaseTimedAction.stop(self)
end

print("[EPR] EPR_Repair.lua loaded successfully")
