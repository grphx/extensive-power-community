--[[
    Extensive Power Rework - Shared Repair State Generation

    Generates and validates facility repair state in a server-authoritative way.
    Adds state flags so data persists across restarts and schema changes.
]]--

print("[EPR] EPR_RepairState.lua loading...")

EPR = EPR or {}
EPR.RepairState = EPR.RepairState or {}

EPR.RepairState.SchemaVersion = 1

-- Bumped when the part-requirement item set changes so old saves get migrated.
-- (Bump this in future releases if more items are renamed/removed.)
EPR.RepairState.PartsSchemaVersion = 1

-- Explicit remaps for items that existed in older EPR versions but were removed
-- from the part tables (and from the game). Anything not listed here that fails
-- script-manager validation is simply dropped.
EPR.RepairState.PartRemap = {
    ["Base.CircuitBoard"] = "Base.ElectronicsScrap",
}

local function tableHasEntries(tbl)
    if type(tbl) ~= "table" then return false end
    for _ in pairs(tbl) do
        return true
    end
    return false
end

local function applyStateFlags(state)
    state.flags = state.flags or {}
    if state.flags.schema == nil then
        state.flags.schema = EPR.RepairState.SchemaVersion
    end
    if state.flags.initialized == nil then
        state.flags.initialized = true
    end
    if state.flags.generatedAtHours == nil then
        local gt = getGameTime and getGameTime()
        state.flags.generatedAtHours = gt and gt:getWorldAgeHours() or 0
    end
    return state
end

function EPR.RepairState.SelectRandomStages()
    local allStages = {"Assessment", "PartReplacement", "Calibration"}
    local numStages = ZombRand(1, 4)  -- 1 to 3 stages

    local shuffled = {}
    for _, stage in ipairs(allStages) do
        table.insert(shuffled, stage)
    end
    for i = #shuffled, 2, -1 do
        local j = ZombRand(i) + 1
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    local selected = {}
    for i = 1, numStages do
        table.insert(selected, shuffled[i])
    end

    local stageOrder = {Assessment = 1, PartReplacement = 2, Calibration = 3}
    table.sort(selected, function(a, b)
        return stageOrder[a] < stageOrder[b]
    end)

    return selected
end

function EPR.RepairState.CalculateSkillRequirement(damageLevel, baseSkill)
    local base = baseSkill or 5

    local skillMult = 1.0
    if SandboxVars and SandboxVars.EPR and type(SandboxVars.EPR.SkillRequirementMultiplier) == "number" then
        skillMult = SandboxVars.EPR.SkillRequirementMultiplier
    end

    local variation = 0
    if damageLevel == "heavy" then
        variation = ZombRand(0, 3)
    elseif damageLevel == "medium" then
        variation = ZombRand(-1, 2)
    else
        variation = ZombRand(-2, 1)
    end

    local requirement = math.max(1, math.floor((base + variation) * skillMult))
    return math.min(10, requirement)
end

EPR.RepairState.ComponentParts = {
    ControlPanel = {
        light = {"Base.ElectronicsScrap", "Base.ElectricWire", "Base.Screws"},
        medium = {"Base.ElectronicsScrap", "Base.ElectronicsScrap", "Base.ElectricWire", "Base.Screws", "Base.Screws", "Base.DuctTape"},
        heavy = {"Base.ElectronicsScrap", "Base.ElectronicsScrap", "Base.ElectronicsScrap", "Base.ElectricWire", "Base.ElectricWire", "Base.Amplifier", "Base.Screws", "Base.Screws", "Base.ScrapMetal", "Base.DuctTape"},
    },
    Transformer = {
        light = {"Base.ElectronicsScrap", "Base.ElectricWire", "Base.Screws"},
        medium = {"Base.ElectronicsScrap", "Base.ElectricWire", "Base.ElectricWire", "Base.Amplifier", "Base.Screws", "Base.ScrapMetal"},
        heavy = {"Base.ElectronicsScrap", "Base.ElectronicsScrap", "Base.ElectricWire", "Base.ElectricWire", "Base.Amplifier", "Base.Amplifier", "Base.Screws", "Base.ScrapMetal", "Base.SmallSheetMetal", "Base.DuctTape"},
    },
    CircuitBreakers = {
        light = {"Base.ElectricWire", "Base.Screws", "Base.ScrapMetal"},
        medium = {"Base.ElectricWire", "Base.ElectricWire", "Base.Screws", "Base.ScrapMetal", "Base.ScrapMetal", "Base.SmallSheetMetal"},
        heavy = {"Base.ElectricWire", "Base.ElectricWire", "Base.ElectricWire", "Base.Screws", "Base.ScrapMetal", "Base.ScrapMetal", "Base.SmallSheetMetal", "Base.SmallSheetMetal", "Base.SheetMetal", "Base.DuctTape"},
    },
    CoolingSystem = {
        light = {"Base.MetalPipe", "Base.Screws"},
        medium = {"Base.MetalPipe", "Base.MetalPipe", "Base.Screws", "Base.DuctTape"},
        heavy = {"Base.MetalPipe", "Base.MetalPipe", "Base.ScrapMetal", "Base.Screws", "Base.Screws", "Base.DuctTape"},
    },
    PowerConduits = {
        light = {"Base.ElectricWire", "Base.ElectricWire", "Base.DuctTape"},
        medium = {"Base.ElectricWire", "Base.ElectricWire", "Base.ElectricWire", "Base.DuctTape", "Base.Screws"},
        heavy = {"Base.ElectricWire", "Base.ElectricWire", "Base.ElectricWire", "Base.ElectricWire", "Base.DuctTape", "Base.Screws", "Base.ScrapMetal"},
    },
    SwitchGear = {
        light = {"Base.ElectronicsScrap", "Base.Screws"},
        medium = {"Base.ElectronicsScrap", "Base.ElectricWire", "Base.Screws", "Base.ScrapMetal"},
        heavy = {"Base.ElectronicsScrap", "Base.ElectronicsScrap", "Base.ElectricWire", "Base.Screws", "Base.ScrapMetal", "Base.SmallSheetMetal"},
    },
    BackupGenerator = {
        light = {"Base.ScrapMetal", "Base.Screws"},
        medium = {"Base.ScrapMetal", "Base.ScrapMetal", "Base.MetalPipe", "Base.Screws"},
        heavy = {"Base.ScrapMetal", "Base.ScrapMetal", "Base.MetalPipe", "Base.MetalPipe", "Base.Screws", "Base.DuctTape"},
    },
    GroundingSystem = {
        light = {"Base.ElectricWire", "Base.SteelBar"},
        medium = {"Base.ElectricWire", "Base.ElectricWire", "Base.SteelBar", "Base.Screws"},
        heavy = {"Base.ElectricWire", "Base.ElectricWire", "Base.ElectricWire", "Base.SteelBar", "Base.SteelBar", "Base.Screws"},
    },
    VoltageRegulator = {
        light = {"Base.ElectronicsScrap", "Base.ElectricWire"},
        medium = {"Base.ElectronicsScrap", "Base.ElectronicsScrap", "Base.ElectricWire", "Base.Screws"},
        heavy = {"Base.ElectronicsScrap", "Base.ElectronicsScrap", "Base.ElectricWire", "Base.ElectricWire", "Base.Amplifier", "Base.Screws"},
    },
}

function EPR.RepairState.GetPartsForComponent(componentType, damageLevel)
    local componentParts = EPR.RepairState.ComponentParts[componentType]
    if not componentParts then
        componentParts = {light = {"Base.ElectronicsScrap", "Base.ElectricWire", "Base.Screws"}}
    end

    local parts = componentParts[damageLevel] or componentParts.light
    local result = {}

    local partMult = 1.0
    if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.PartRequirementMultiplier then
        partMult = SandboxVars.EPR.PartRequirementMultiplier
    end

    local partCounts = {}
    for _, part in ipairs(parts) do
        partCounts[part] = (partCounts[part] or 0) + 1
    end

    for part, count in pairs(partCounts) do
        local adjustedCount = math.max(1, math.ceil(count * partMult))
        for i = 1, adjustedCount do
            table.insert(result, part)
        end
    end

    return result
end

function EPR.RepairState.GenerateRandomState(facility)
    local state = {
        status = "offline",
        health = 0,
        repairProgress = 0,
        lastMaintenance = 0,
        repairQuality = 0,
        facilityKey = facility.key or facility.id,
        discovered = true,
        discoveredTime = getGameTime() and getGameTime():getWorldAgeHours() or 0,
        components = {},
        componentOrder = {},
        initialDamageLevel = 0,
        phase = 1,
    }

    applyStateFlags(state)

    local baseElecSkill = 5
    local baseWeldSkill = 4
    if EPR.Config and EPR.Config.SubstationSkills then
        baseElecSkill = EPR.Config.SubstationSkills.Electrical or 5
        baseWeldSkill = EPR.Config.SubstationSkills.MetalWelding or 4
    end

    if SandboxVars and SandboxVars.EPR then
        if type(SandboxVars.EPR.MinElectricalSkill) == "number" then
            baseElecSkill = SandboxVars.EPR.MinElectricalSkill
        end
        if type(SandboxVars.EPR.MinMetalworkSkill) == "number" then
            baseWeldSkill = SandboxVars.EPR.MinMetalworkSkill
        end
    end

    local facilityDamageRoll = ZombRand(100)
    local facilityDamageLevel = "medium"
    if facilityDamageRoll < 40 then
        facilityDamageLevel = "heavy"
    elseif facilityDamageRoll < 70 then
        facilityDamageLevel = "medium"
    else
        facilityDamageLevel = "light"
    end

    local controlPanelX = facility.x
    local controlPanelY = facility.y
    if facility.components and facility.components.ControlPanel and facility.components.ControlPanel.tiles then
        local tile = facility.components.ControlPanel.tiles[1]
        if tile then
            controlPanelX = tile.x
            controlPanelY = tile.y
        end
    end

    local controlPanelState = {
        type = "ControlPanel",
        status = "damaged",
        currentStage = "Assessment",
        stageProgress = 0,
        damageLevel = facilityDamageLevel,
        x = controlPanelX,
        y = controlPanelY,
        partsNeeded = EPR.RepairState.GetPartsForComponent("ControlPanel", facilityDamageLevel),
        partsInstalled = {},
        stagesCompleted = {},
        requiredStages = {"Assessment", "PartReplacement", "Calibration"},
        isMainConsole = true,
        skillRequirements = {
            Electricity = EPR.RepairState.CalculateSkillRequirement(facilityDamageLevel, baseElecSkill),
            Welding = EPR.RepairState.CalculateSkillRequirement(facilityDamageLevel, baseWeldSkill),
        },
    }

    state.components["ControlPanel"] = controlPanelState
    table.insert(state.componentOrder, "ControlPanel")

    local numFieldComponents = 2
    if SandboxVars and SandboxVars.EPR and type(SandboxVars.EPR.FieldComponentCount) == "number" then
        numFieldComponents = SandboxVars.EPR.FieldComponentCount
    end

    local availableField = {}
    if EPR.FieldComponents then
        for _, comp in ipairs(EPR.FieldComponents) do
            table.insert(availableField, comp)
        end
    else
        availableField = {"Transformer", "CircuitBreakers"}
    end

    for i = #availableField, 2, -1 do
        local j = ZombRand(i) + 1
        availableField[i], availableField[j] = availableField[j], availableField[i]
    end

    local numToSelect = math.min(numFieldComponents, #availableField)

    for i = 1, numToSelect do
        local compType = availableField[i]

        local compDamageRoll = ZombRand(100)
        local compDamageLevel = "medium"
        if compDamageRoll < 35 then
            compDamageLevel = "heavy"
        elseif compDamageRoll < 65 then
            compDamageLevel = "medium"
        else
            compDamageLevel = "light"
        end

        local compX = facility.x + ZombRand(-5, 6)
        local compY = facility.y + ZombRand(-5, 6)
        if facility.components and facility.components[compType] and facility.components[compType].tiles then
            local tile = facility.components[compType].tiles[1]
            if tile then
                compX = tile.x
                compY = tile.y
            end
        end

        local selectedStages = EPR.RepairState.SelectRandomStages()

        local fieldCompState = {
            type = compType,
            status = "damaged",
            currentStage = selectedStages[1],
            stageProgress = 0,
            damageLevel = compDamageLevel,
            x = compX,
            y = compY,
            partsNeeded = EPR.RepairState.GetPartsForComponent(compType, compDamageLevel),
            partsInstalled = {},
            stagesCompleted = {},
            requiredStages = selectedStages,
            isMainConsole = false,
            skillRequirements = {
                Electricity = EPR.RepairState.CalculateSkillRequirement(compDamageLevel, baseElecSkill),
                Welding = EPR.RepairState.CalculateSkillRequirement(compDamageLevel, baseWeldSkill),
            },
        }

        state.components[compType] = fieldCompState
        table.insert(state.componentOrder, compType)
    end

    local totalDamage = 0
    local numComponents = 0
    for _, compState in pairs(state.components) do
        numComponents = numComponents + 1
        if compState.damageLevel == "heavy" then
            totalDamage = totalDamage + 90
        elseif compState.damageLevel == "medium" then
            totalDamage = totalDamage + 60
        else
            totalDamage = totalDamage + 30
        end
    end
    state.initialDamageLevel = numComponents > 0 and math.floor(totalDamage / numComponents) or 0

    return state
end

-- Returns true if itemType resolves to a real script item. If the script
-- manager API is unavailable/different we assume valid (never wipe legit parts
-- just because we couldn't check) — the explicit PartRemap still handles the
-- known-bad Base.CircuitBoard case regardless.
local function isValidItemType(itemType)
    if type(itemType) ~= "string" or itemType == "" then return false end
    local sm = getScriptManager and getScriptManager()
    if not sm then return true end
    if sm.getItem then
        local ok, scriptItem = pcall(function() return sm:getItem(itemType) end)
        if ok then return scriptItem ~= nil end
    end
    if sm.FindItem then
        local ok, scriptItem = pcall(function() return sm:FindItem(itemType) end)
        if ok then return scriptItem ~= nil end
    end
    return true
end

-- One-time migration of persisted component part lists. Old saves baked raw
-- item ids (e.g. the long-removed "Base.CircuitBoard") into partsNeeded; new
-- code never regenerates them, so repairs stay permanently blocked. Runs once
-- per facility state, gated by state.flags.partsSchema. Returns true if changed.
function EPR.RepairState.SanitizeComponentParts(state)
    if not state or type(state.components) ~= "table" then return false end
    state.flags = state.flags or {}
    if state.flags.partsSchema == EPR.RepairState.PartsSchemaVersion then
        return false
    end

    local remap = EPR.RepairState.PartRemap or {}
    local changed = false

    for compType, compState in pairs(state.components) do
        if type(compState) == "table" then
            local damageLevel = compState.damageLevel or "medium"
            local partReplacementDone = type(compState.stagesCompleted) == "table"
                and compState.stagesCompleted.PartReplacement == true
            local fullyDone = compState.status == "repaired" or compState.status == "functional"

            local needsFix = false
            if type(compState.partsNeeded) == "table" then
                for _, p in ipairs(compState.partsNeeded) do
                    if remap[p] or not isValidItemType(p) then needsFix = true break end
                end
            end
            if not needsFix and type(compState.partsInstalled) == "table" then
                for p in pairs(compState.partsInstalled) do
                    if remap[p] or not isValidItemType(p) then needsFix = true break end
                end
            end

            if needsFix then
                if (not partReplacementDone) and (not fullyDone)
                    and EPR.RepairState.ComponentParts[compType] then
                    -- No installed progress to preserve: regenerate cleanly
                    -- from the current part tables.
                    compState.partsNeeded = EPR.RepairState.GetPartsForComponent(compType, damageLevel)
                    compState.partsInstalled = {}
                else
                    -- Preserve repair progress: remap/strip invalid entries.
                    if type(compState.partsNeeded) == "table" then
                        local cleaned = {}
                        for _, p in ipairs(compState.partsNeeded) do
                            local mapped = remap[p] or p
                            if isValidItemType(mapped) then
                                table.insert(cleaned, mapped)
                            end
                        end
                        compState.partsNeeded = cleaned
                    end
                    if type(compState.partsInstalled) == "table" then
                        local cleaned = {}
                        for p, count in pairs(compState.partsInstalled) do
                            local mapped = remap[p] or p
                            if isValidItemType(mapped) then
                                cleaned[mapped] = (cleaned[mapped] or 0) + count
                            end
                        end
                        compState.partsInstalled = cleaned
                    end
                end
                changed = true
            end
        end
    end

    state.flags.partsSchema = EPR.RepairState.PartsSchemaVersion
    return changed
end

function EPR.RepairState.EnsureFacilityState(facility, state)
    if not facility then return state, false end

    local hasComponents = state and tableHasEntries(state.components)
    if not state or not hasComponents then
        local previous = state
        local newState = EPR.RepairState.GenerateRandomState(facility)

        if previous then
            newState.status = previous.status or newState.status
            newState.health = previous.health or newState.health
            newState.lastMaintenance = previous.lastMaintenance or newState.lastMaintenance
            newState.repairQuality = previous.repairQuality or newState.repairQuality
            if previous.discovered ~= nil then
                newState.discovered = previous.discovered
            end
            if previous.discoveredTime ~= nil then
                newState.discoveredTime = previous.discoveredTime
            end
            if previous.flags then
                for k, v in pairs(previous.flags) do
                    if newState.flags[k] == nil then
                        newState.flags[k] = v
                    end
                end
            end

            if newState.status == "ready" or newState.status == "starting" or newState.status == "online" then
                if newState.components then
                    for _, compState in pairs(newState.components) do
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

        applyStateFlags(newState)
        -- Freshly generated from current part tables: mark parts up to date.
        newState.flags.partsSchema = EPR.RepairState.PartsSchemaVersion
        return newState, true
    end

    local changed = false
    if state.discovered == nil then
        state.discovered = true
        changed = true
    end
    if not state.flags or state.flags.initialized ~= true or state.flags.schema == nil then
        applyStateFlags(state)
        changed = true
    end

    -- Migrate stale/removed part ids baked into old saves (e.g. Base.CircuitBoard).
    if EPR.RepairState.SanitizeComponentParts(state) then
        changed = true
    end

    return state, changed
end

function EPR.RepairState.EnsureAllFacilities()
    if EPR.IsServerContext and not EPR.IsServerContext() then
        return
    end
    if not EPR.Zones or not EPR.Zones.Facilities then return end

    local changed = false
    for _, facility in pairs(EPR.Zones.Facilities) do
        local state = nil
        if facility.type == "power" or facility.type == "combined" then
            state = EPR.Substations and EPR.Substations[facility.id]
        elseif facility.type == "water" then
            state = EPR.WaterPlants and EPR.WaterPlants[facility.id]
        end

        local newState, didChange = EPR.RepairState.EnsureFacilityState(facility, state)
        if didChange then
            if facility.type == "power" or facility.type == "combined" then
                EPR.Substations[facility.id] = newState
            end
            if facility.type == "water" or facility.type == "combined" then
                EPR.WaterPlants[facility.id] = newState
            end
            changed = true
        end
    end

    if changed and EPR.SaveData then
        EPR.SaveData()
    end
end

print("[EPR] EPR_RepairState.lua loaded successfully")
