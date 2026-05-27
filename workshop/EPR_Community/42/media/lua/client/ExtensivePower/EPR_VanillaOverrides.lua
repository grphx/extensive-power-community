--[[
    Extensive Power Rework - Vanilla UI/Interaction Overrides

    Blocks appliance and light interactions when global override is active
    and the building is not connected or zone is offline.
]]--

-- Clients only, not dedicated server
if isServer() and not isClient() then return end

print("[EPR] client/EPR_VanillaOverrides.lua loading...")

require "ISUI/ISWorldObjectContextMenu"

EPR = EPR or {}
EPR.VanillaOverrides = EPR.VanillaOverrides or {}

local function logDebug(message)
    if EPR.IsDebugMode and EPR.IsDebugMode() then
        print(message)
    end
end

local function isDebugEnabled()
    if EPR and EPR.IsDebugMode and EPR.IsDebugMode() then
        return true
    end
    if getDebug and getDebug() then
        return true
    end
    return false
end

logDebug("[EPR] EPR_VanillaOverrides.lua loading...")

local function getPowerBlockReasonForSquare(square)
    if EPR.Buildings and EPR.Buildings.GetPowerBlockReason then
        return EPR.Buildings.GetPowerBlockReason(square)
    end
    return nil
end

local function getWaterBlockReasonForSquare(square)
    if EPR.Buildings and EPR.Buildings.GetWaterBlockReason then
        return EPR.Buildings.GetWaterBlockReason(square)
    end
    return nil
end

-- Fills a washer/combo-washer to capacity if its tank is below capacity.
-- Called from shouldBeVisible (no sync) so the vanilla fluid check passes naturally.
-- No-op if already full; safe to call every frame.
local function eprFillWasherTankLocal(object)
    if not object then return end
    local capacity = object.getFluidCapacity and object:getFluidCapacity()
    if not capacity or capacity <= 0 then return end
    local current = (object.getFluidAmount and object:getFluidAmount()) or 0
    if current >= capacity then return end
    local waterFluidType = FluidType and FluidType.FromNameLower and FluidType.FromNameLower("water")
    if not waterFluidType then return end
    pcall(function() object:addFluid(waterFluidType, capacity - current) end)
end

local function showBlockedTooltip(context, label, reason)
    local option = context:addOption(label, nil, nil)
    option.notAvailable = true
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.addToolTip then
        option.toolTip = ISWorldObjectContextMenu.addToolTip()
        option.toolTip:setVisible(false)
        option.toolTip.description = reason or "No power"
    end
end

local function markOptionUnavailable(option, reason)
    if not option then return end
    option.notAvailable = true
    if not option.toolTip and ISWorldObjectContextMenu and ISWorldObjectContextMenu.addToolTip then
        option.toolTip = ISWorldObjectContextMenu.addToolTip()
        option.toolTip:setVisible(false)
        option.toolTip.description = reason or "No water"
    elseif option.toolTip then
        option.toolTip.description = reason or option.toolTip.description
    end
end

local function disableWaterOptionsInMenu(context, reason)
    if not context or not context.options then return end
    for i = 1, #context.options do
        local opt = context.options[i]
        if opt then
            local name = opt.name or opt.text or ""
            if name == getText("ContextMenu_Drink")
                or name == getText("ContextMenu_Fill")
                or name == getText("ContextMenu_Wash") then
                markOptionUnavailable(opt, reason)
            end
            if opt.subMenu then
                disableWaterOptionsInMenu(opt.subMenu, reason)
            end
        end
    end
end

local function applyOverrides()
    if EPR.VanillaOverrides.hooksApplied then
        return
    end

    if isDebugEnabled() then
        if not ISItemsListTable then
            pcall(require, "ISUI/AdminPanel/ISItemsListTable")
        end

        if ISItemsListTable and ISItemsListTable.initList and not EPR.VanillaOverrides.originalItemsListInit then
            EPR.VanillaOverrides.originalItemsListInit = ISItemsListTable.initList
            ISItemsListTable.initList = function(self, module)
                if not module or type(module) ~= "table" then
                    return EPR.VanillaOverrides.originalItemsListInit(self, module)
                end

                local filtered = {}
                if module.size and module.get then
                    for i = 0, module:size() - 1 do
                        local item = module:get(i)
                        local itemType = item and item.getItemType and item:getItemType() or nil
                        if itemType then
                            table.insert(filtered, item)
                        end
                    end
                else
                    for _, item in ipairs(module) do
                        local itemType = item and item.getItemType and item:getItemType() or nil
                        if itemType then
                            table.insert(filtered, item)
                        end
                    end
                end

                return EPR.VanillaOverrides.originalItemsListInit(self, filtered)
            end
        end

        if ISItemsListTable and ISItemsListTable.filterCategory and not EPR.VanillaOverrides.originalItemsListFilterCategory then
            EPR.VanillaOverrides.originalItemsListFilterCategory = ISItemsListTable.filterCategory
            ISItemsListTable.filterCategory = function(self, widget, scriptItem)
                if widget and widget.selected == 1 then return true end
                if not scriptItem or not scriptItem.getItemType then return false end
                local itemType = scriptItem:getItemType()
                if not itemType then return false end
                return itemType:toString() == widget:getOptionText(widget.selected)
            end
        end

        if not ISItemsListViewer then
            pcall(require, "ISUI/AdminPanel/ISItemsListViewer")
        end

        if ISItemsListViewer and ISItemsListViewer.initList and not EPR.VanillaOverrides.originalItemsListViewerInit then
            EPR.VanillaOverrides.originalItemsListViewerInit = ISItemsListViewer.initList
            ISItemsListViewer.initList = function(self)
                local items = getAllItems()
                if items and items.size and items.get then
                    local filtered = {}
                    for i = 0, items:size() - 1 do
                        local item = items:get(i)
                        local itemType = item and item.getItemType and item:getItemType() or nil
                        if itemType and not item:getObsolete() and not item:isHidden() then
                            table.insert(filtered, item)
                        end
                    end

                    self.items = items
                    self.module = {}
                    local moduleNames = {}
                    local allItems = {}
                    for _, item in ipairs(filtered) do
                        local moduleName = item:getModuleName()
                        if not self.module[moduleName] then
                            self.module[moduleName] = {}
                            table.insert(moduleNames, moduleName)
                        end
                        table.insert(self.module[moduleName], item)
                        table.insert(allItems, item)
                    end

                    table.sort(moduleNames, function(a, b) return not string.sort(a, b) end)

                    local listBox = ISItemsListTable:new(0, 0, self.panel.width, self.panel.height - self.panel.tabHeight, self)
                    listBox:initialise()
                    self.panel:addView("All", listBox)
                    listBox:initList(allItems)

                    for _, moduleName in ipairs(moduleNames) do
                        if moduleName ~= "Moveables" then
                            local cat1 = ISItemsListTable:new(0, 0, self.panel.width, self.panel.height - self.panel.tabHeight, self)
                            cat1:initialise()
                            self.panel:addView(moduleName, cat1)
                            cat1:initList(self.module[moduleName])
                        end
                    end
                    self.panel:activateView("All")
                    return
                end
                return EPR.VanillaOverrides.originalItemsListViewerInit(self)
            end
        end
    end

    if not ISWorldObjectContextMenu then
        return
    end

    -- Light switch context menu
    if ISWorldObjectContextMenu.doLightSwitchOption and not EPR.VanillaOverrides.originalDoLightSwitchOption then
        EPR.VanillaOverrides.originalDoLightSwitchOption = ISWorldObjectContextMenu.doLightSwitchOption
        ISWorldObjectContextMenu.doLightSwitchOption = function(test, context, player)
            local fetch = ISWorldObjectContextMenu.fetchVars
            if fetch and fetch.lightSwitch and fetch.lightSwitch.getSquare then
                local reason = getPowerBlockReasonForSquare(fetch.lightSwitch:getSquare())
                if reason then
                    if test == true then return true end
                    showBlockedTooltip(context, fetch.lightSwitch:getTileName(), reason)
                    return
                end
            end
            return EPR.VanillaOverrides.originalDoLightSwitchOption(test, context, player)
        end
    end

    -- Light switch toggle action
    if ISWorldObjectContextMenu.onToggleLight and not EPR.VanillaOverrides.originalToggleLight then
        EPR.VanillaOverrides.originalToggleLight = ISWorldObjectContextMenu.onToggleLight
        ISWorldObjectContextMenu.onToggleLight = function(worldobjects, light, player)
            if light and light.getSquare then
                local reason = getPowerBlockReasonForSquare(light:getSquare())
                if reason then
                    local playerObj = getSpecificPlayer(player)
                    if playerObj then
                        playerObj:Say(reason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalToggleLight(worldobjects, light, player)
        end
    end

    -- Stove toggles (context menu)
    if ISWorldObjectContextMenu.onToggleStove and not EPR.VanillaOverrides.originalToggleStove then
        EPR.VanillaOverrides.originalToggleStove = ISWorldObjectContextMenu.onToggleStove
        ISWorldObjectContextMenu.onToggleStove = function(worldobjects, stove, player)
            if stove and stove.getSquare then
                local reason = getPowerBlockReasonForSquare(stove:getSquare())
                if reason then
                    local playerObj = getSpecificPlayer(player)
                    if playerObj then
                        playerObj:Say(reason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalToggleStove(worldobjects, stove, player)
        end
    end

    -- Combo washer/dryer menu and toggles
    if ISWorldObjectContextMenu.toggleComboWasherDryer and not EPR.VanillaOverrides.originalToggleComboMenu then
        EPR.VanillaOverrides.originalToggleComboMenu = ISWorldObjectContextMenu.toggleComboWasherDryer
        ISWorldObjectContextMenu.toggleComboWasherDryer = function(context, playerObj, object)
            if object and object.getSquare then
                local powerReason = getPowerBlockReasonForSquare(object:getSquare())
                local waterReason = getWaterBlockReasonForSquare(object:getSquare())
                if powerReason or waterReason then
                    local label = object:getName() or "Combo Washer/Dryer"
                    showBlockedTooltip(context, label, powerReason or waterReason)
                    return
                end
            end
            return EPR.VanillaOverrides.originalToggleComboMenu(context, playerObj, object)
        end
    end

    if ISWorldObjectContextMenu.onToggleComboWasherDryer and not EPR.VanillaOverrides.originalToggleCombo then
        EPR.VanillaOverrides.originalToggleCombo = ISWorldObjectContextMenu.onToggleComboWasherDryer
        ISWorldObjectContextMenu.onToggleComboWasherDryer = function(playerObj, object)
            if object and object.getSquare then
                local powerReason = getPowerBlockReasonForSquare(object:getSquare())
                local waterReason = getWaterBlockReasonForSquare(object:getSquare())
                if powerReason or waterReason then
                    if playerObj then
                        playerObj:Say(powerReason or waterReason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalToggleCombo(playerObj, object)
        end
    end

    -- Clothing washer/dryer toggles
    if ISWorldObjectContextMenu.onToggleClothingWasher and not EPR.VanillaOverrides.originalToggleWasher then
        EPR.VanillaOverrides.originalToggleWasher = ISWorldObjectContextMenu.onToggleClothingWasher
        ISWorldObjectContextMenu.onToggleClothingWasher = function(worldobjects, object, playerId)
            if object and object.getSquare then
                local powerReason = getPowerBlockReasonForSquare(object:getSquare())
                local waterReason = getWaterBlockReasonForSquare(object:getSquare())
                if powerReason or waterReason then
                    local playerObj = getSpecificPlayer(playerId)
                    if playerObj then
                        playerObj:Say(powerReason or waterReason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalToggleWasher(worldobjects, object, playerId)
        end
    end

    if ISWorldObjectContextMenu.onToggleClothingDryer and not EPR.VanillaOverrides.originalToggleDryer then
        EPR.VanillaOverrides.originalToggleDryer = ISWorldObjectContextMenu.onToggleClothingDryer
        ISWorldObjectContextMenu.onToggleClothingDryer = function(worldobjects, object, playerId)
            if object and object.getSquare then
                local reason = getPowerBlockReasonForSquare(object:getSquare())
                if reason then
                    local playerObj = getSpecificPlayer(playerId)
                    if playerObj then
                        playerObj:Say(reason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalToggleDryer(worldobjects, object, playerId)
        end
    end

    -- Water actions (drink/fill/wash)

    -- Natural sources (wells, rain collectors, rivers, puddles) must never be blocked
    -- by EPR's water zone check — they don't depend on municipal water infrastructure.
    local function IsNaturalWaterSource(object)
        if not object then return false end
        if instanceof and instanceof(object, "IsoWaterDispenser") then return false end
        local sprite = object.getSprite and object:getSprite()
        local name = sprite and sprite.getName and string.lower(sprite:getName() or "") or ""
        if name:find("waterwell") or name:find("water_well") or name:find("well_")
        or name:find("handpump") or name:find("pump_hand") or name:find("raincollect")
        or name:find("rain_collect") or name:find("river") or name:find("pond")
        or name:find("puddle") then
            return true
        end
        if object.getDeviceData then
            local ok, data = pcall(function() return object:getDeviceData() end)
            if ok and data then return false end
        end
        if object.getContainerByType then
            if object:getContainerByType("water") ~= nil then return true end
        end
        return false
    end

    if ISWorldObjectContextMenu.doFluidContainerMenu and not EPR.VanillaOverrides.originalDoFluidContainerMenu then
        EPR.VanillaOverrides.originalDoFluidContainerMenu = ISWorldObjectContextMenu.doFluidContainerMenu
        ISWorldObjectContextMenu.doFluidContainerMenu = function(context, object, player)
            local menu = EPR.VanillaOverrides.originalDoFluidContainerMenu(context, object, player)
            if object and object.getSquare and not IsNaturalWaterSource(object) then
                local reason = getWaterBlockReasonForSquare(object:getSquare())
                if reason then
                    local options = context and context.options
                    local topOption = options and options[#options] or nil
                    markOptionUnavailable(topOption, reason)
                    if menu then
                        disableWaterOptionsInMenu(menu, reason)
                    end
                end
            end
            return menu
        end
    end

    if ISWorldObjectContextMenu.doRecipeUsingWaterMenu and not EPR.VanillaOverrides.originalDoRecipeUsingWaterMenu then
        EPR.VanillaOverrides.originalDoRecipeUsingWaterMenu = ISWorldObjectContextMenu.doRecipeUsingWaterMenu
        ISWorldObjectContextMenu.doRecipeUsingWaterMenu = function(waterObject, playerNum, context)
            if waterObject and waterObject.getSquare and not IsNaturalWaterSource(waterObject) then
                local reason = getWaterBlockReasonForSquare(waterObject:getSquare())
                if reason then
                    showBlockedTooltip(context, getText("ContextMenu_CleanBandageEtc"), reason)
                    return
                end
            end
            return EPR.VanillaOverrides.originalDoRecipeUsingWaterMenu(waterObject, playerNum, context)
        end
    end

    if ISWorldObjectContextMenu.doDrinkWaterMenu and not EPR.VanillaOverrides.originalDoDrinkWaterMenu then
        EPR.VanillaOverrides.originalDoDrinkWaterMenu = ISWorldObjectContextMenu.doDrinkWaterMenu
        ISWorldObjectContextMenu.doDrinkWaterMenu = function(object, player, context)
            if object and object.getSquare and not IsNaturalWaterSource(object) then
                local reason = getWaterBlockReasonForSquare(object:getSquare())
                if reason then
                    showBlockedTooltip(context, getText("ContextMenu_Drink"), reason)
                    return
                end
            end
            return EPR.VanillaOverrides.originalDoDrinkWaterMenu(object, player, context)
        end
    end

    if ISWorldObjectContextMenu.doFillFluidMenu and not EPR.VanillaOverrides.originalDoFillFluidMenu then
        EPR.VanillaOverrides.originalDoFillFluidMenu = ISWorldObjectContextMenu.doFillFluidMenu
        ISWorldObjectContextMenu.doFillFluidMenu = function(sink, playerNum, context)
            if sink and sink.getSquare and not IsNaturalWaterSource(sink) then
                local reason = getWaterBlockReasonForSquare(sink:getSquare())
                if reason then
                    showBlockedTooltip(context, getText("ContextMenu_Fill"), reason)
                    return
                end
            end
            return EPR.VanillaOverrides.originalDoFillFluidMenu(sink, playerNum, context)
        end
    end

    if ISWorldObjectContextMenu.doWashClothingMenu and not EPR.VanillaOverrides.originalDoWashClothingMenu then
        EPR.VanillaOverrides.originalDoWashClothingMenu = ISWorldObjectContextMenu.doWashClothingMenu
        ISWorldObjectContextMenu.doWashClothingMenu = function(sink, player, context)
            if sink and sink.getSquare and not IsNaturalWaterSource(sink) then
                local reason = getWaterBlockReasonForSquare(sink:getSquare())
                if reason then
                    showBlockedTooltip(context, getText("ContextMenu_Wash"), reason)
                    return
                end
            end
            return EPR.VanillaOverrides.originalDoWashClothingMenu(sink, player, context)
        end
    end

    if ISWorldObjectContextMenu.onDrink and not EPR.VanillaOverrides.originalOnDrink then
        EPR.VanillaOverrides.originalOnDrink = ISWorldObjectContextMenu.onDrink
        ISWorldObjectContextMenu.onDrink = function(worldobjects, waterObject, player)
            if waterObject and waterObject.getSquare and not IsNaturalWaterSource(waterObject) then
                local reason = getWaterBlockReasonForSquare(waterObject:getSquare())
                if reason then
                    local playerObj = getSpecificPlayer(player)
                    if playerObj then
                        playerObj:Say(reason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalOnDrink(worldobjects, waterObject, player)
        end
    end

    if ISWorldObjectContextMenu.onTakeWater and not EPR.VanillaOverrides.originalOnTakeWater then
        EPR.VanillaOverrides.originalOnTakeWater = ISWorldObjectContextMenu.onTakeWater
        ISWorldObjectContextMenu.onTakeWater = function(worldobjects, waterObject, items, item, playerNum)
            if waterObject and waterObject.getSquare and not IsNaturalWaterSource(waterObject) then
                local reason = getWaterBlockReasonForSquare(waterObject:getSquare())
                if reason then
                    local playerObj = getSpecificPlayer(playerNum)
                    if playerObj then
                        playerObj:Say(reason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalOnTakeWater(worldobjects, waterObject, items, item, playerNum)
        end
    end

    if ISWorldObjectContextMenu.onWashClothing and not EPR.VanillaOverrides.originalOnWashClothing then
        EPR.VanillaOverrides.originalOnWashClothing = ISWorldObjectContextMenu.onWashClothing
        ISWorldObjectContextMenu.onWashClothing = function(playerObj, sink, soapList, washList, singleClothing, noSoap)
            if sink and sink.getSquare and not IsNaturalWaterSource(sink) then
                local reason = getWaterBlockReasonForSquare(sink:getSquare())
                if reason then
                    if playerObj then
                        playerObj:Say(reason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalOnWashClothing(playerObj, sink, soapList, washList, singleClothing, noSoap)
        end
    end

    if ISWorldObjectContextMenu.onWashYourself and not EPR.VanillaOverrides.originalOnWashYourself then
        EPR.VanillaOverrides.originalOnWashYourself = ISWorldObjectContextMenu.onWashYourself
        ISWorldObjectContextMenu.onWashYourself = function(playerObj, sink, soapList)
            if sink and sink.getSquare and not IsNaturalWaterSource(sink) then
                local reason = getWaterBlockReasonForSquare(sink:getSquare())
                if reason then
                    if playerObj then
                        playerObj:Say(reason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalOnWashYourself(playerObj, sink, soapList)
        end
    end

    if Events and Events.OnFillWorldObjectContextMenu and not EPR.VanillaOverrides.onFillHookAdded then
        Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
            if test == true then return end
            if not worldobjects then return end
            for _, obj in ipairs(worldobjects) do
                if obj and obj.getSquare and not IsNaturalWaterSource(obj) then
                    local reason = getWaterBlockReasonForSquare(obj:getSquare())
                    if reason then
                        disableWaterOptionsInMenu(context, reason)
                        return
                    end
                end
            end
        end)
        EPR.VanillaOverrides.onFillHookAdded = true
    end

    -- Loot window stove toggle handler
    if ISLootWindowObjectControlHandler_StoveToggle and not EPR.VanillaOverrides.originalStoveHandler then
        local Handler = ISLootWindowObjectControlHandler_StoveToggle
        EPR.VanillaOverrides.originalStoveHandler = {
            shouldBeVisible = Handler.shouldBeVisible,
            perform = Handler.perform,
        }

        Handler.shouldBeVisible = function(self)
            if not EPR.VanillaOverrides.originalStoveHandler.shouldBeVisible(self) then return false end
            if self.object and self.object.getSquare then
                local reason = getPowerBlockReasonForSquare(self.object:getSquare())
                if reason then
                    return false
                end
            end
            return true
        end

        Handler.perform = function(self)
            if self.object and self.object.getSquare then
                local reason = getPowerBlockReasonForSquare(self.object:getSquare())
                if reason then
                    if self.playerObj then
                        self.playerObj:Say(reason)
                    end
                    return
                end
            end
            return EPR.VanillaOverrides.originalStoveHandler.perform(self)
        end
    end

    -- Loot window clothing washer toggle handler
    if ISLootWindowObjectControlHandler_ClothingWasherToggle and not EPR.VanillaOverrides.originalWasherHandler then
        local Handler = ISLootWindowObjectControlHandler_ClothingWasherToggle
        EPR.VanillaOverrides.originalWasherHandler = {
            shouldBeVisible = Handler.shouldBeVisible,
            perform = Handler.perform,
        }

        Handler.shouldBeVisible = function(self)
            if not (self.object and self.object.getSquare) then
                return EPR.VanillaOverrides.originalWasherHandler.shouldBeVisible(self)
            end
            local sq = self.object:getSquare()
            local powerReason = getPowerBlockReasonForSquare(sq)
            local waterReason = getWaterBlockReasonForSquare(sq)
            if powerReason or waterReason then return false end
            -- In active EPR water zone: lazily fill the tank so the vanilla fluid check
            -- passes naturally. Avoids bypassing vanilla shouldBeVisible entirely.
            if EPR.PowerController and EPR.PowerController.globalOverride then
                local zoneName = EPR.Zones and EPR.Zones.GetZoneAt and EPR.Zones.GetZoneAt(sq:getX(), sq:getY())
                if zoneName and EPR.WaterZones and EPR.WaterZones[zoneName] == true then
                    eprFillWasherTankLocal(self.object)
                end
            end
            return EPR.VanillaOverrides.originalWasherHandler.shouldBeVisible(self)
        end

        Handler.perform = function(self)
            if self.object and self.object.getSquare then
                local powerReason = getPowerBlockReasonForSquare(self.object:getSquare())
                local waterReason = getWaterBlockReasonForSquare(self.object:getSquare())
                local reason = powerReason or waterReason
                if reason then
                    if self.playerObj then self.playerObj:Say(reason) end
                    return
                end
            end
            return EPR.VanillaOverrides.originalWasherHandler.perform(self)
        end
    end

    -- Loot window clothing dryer toggle handler
    if ISLootWindowObjectControlHandler_ClothingDryerToggle and not EPR.VanillaOverrides.originalDryerHandler then
        local Handler = ISLootWindowObjectControlHandler_ClothingDryerToggle
        EPR.VanillaOverrides.originalDryerHandler = {
            shouldBeVisible = Handler.shouldBeVisible,
            perform = Handler.perform,
        }

        Handler.shouldBeVisible = function(self)
            if not EPR.VanillaOverrides.originalDryerHandler.shouldBeVisible(self) then return false end
            if self.object and self.object.getSquare then
                if getPowerBlockReasonForSquare(self.object:getSquare()) then return false end
            end
            return true
        end

        Handler.perform = function(self)
            if self.object and self.object.getSquare then
                local reason = getPowerBlockReasonForSquare(self.object:getSquare())
                if reason then
                    if self.playerObj then self.playerObj:Say(reason) end
                    return
                end
            end
            return EPR.VanillaOverrides.originalDryerHandler.perform(self)
        end
    end

    -- Loot window combination washer/dryer toggle handler
    if ISLootWindowObjectControlHandler_CombinationWasherDryerToggle and not EPR.VanillaOverrides.originalComboHandler then
        local Handler = ISLootWindowObjectControlHandler_CombinationWasherDryerToggle
        EPR.VanillaOverrides.originalComboHandler = {
            shouldBeVisible = Handler.shouldBeVisible,
            perform = Handler.perform,
        }

        Handler.shouldBeVisible = function(self)
            if not (self.object and self.object.getSquare) then
                return EPR.VanillaOverrides.originalComboHandler.shouldBeVisible(self)
            end
            local sq = self.object:getSquare()
            local powerReason = getPowerBlockReasonForSquare(sq)
            local waterReason = getWaterBlockReasonForSquare(sq)
            if powerReason or waterReason then return false end
            -- In washer mode inside an active EPR water zone: lazily fill the tank.
            if self.object.isModeWasher and self.object:isModeWasher()
                    and EPR.PowerController and EPR.PowerController.globalOverride then
                local zoneName = EPR.Zones and EPR.Zones.GetZoneAt and EPR.Zones.GetZoneAt(sq:getX(), sq:getY())
                if zoneName and EPR.WaterZones and EPR.WaterZones[zoneName] == true then
                    eprFillWasherTankLocal(self.object)
                end
            end
            return EPR.VanillaOverrides.originalComboHandler.shouldBeVisible(self)
        end

        Handler.perform = function(self)
            if self.object and self.object.getSquare then
                local powerReason = getPowerBlockReasonForSquare(self.object:getSquare())
                local waterReason = getWaterBlockReasonForSquare(self.object:getSquare())
                local reason = powerReason or waterReason
                if reason then
                    if self.playerObj then self.playerObj:Say(reason) end
                    return
                end
            end
            return EPR.VanillaOverrides.originalComboHandler.perform(self)
        end
    end

    EPR.VanillaOverrides.hooksApplied = true
end

applyOverrides()

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(applyOverrides)
end
