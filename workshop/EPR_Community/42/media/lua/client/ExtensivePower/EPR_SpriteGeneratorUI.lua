--[[
    Extensive Power Rework - Sprite Generator UI

    Lightweight UI for sprite generator status and actions.
]]--

if isServer() and not isClient() then return end

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISWorldObjectContextMenu"
require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISAddFuel"
require "TimedActions/ISFixGenerator"

EPR = EPR or {}
EPR.SpriteGeneratorUI = EPR.SpriteGeneratorUI or {}

local function getEprText(key, fallback)
    local ok = getText and getText(key)
    if ok and ok ~= key then return ok end
    return fallback
end

local Colors = {
    background = {r = 0.01, g = 0.02, b = 0.01, a = 0.98},
    panelBg = {r = 0.02, g = 0.04, b = 0.02, a = 0.95},
    border = {r = 0.15, g = 0.6, b = 0.2, a = 1.0},
    textPrimary = {r = 0.2, g = 1.0, b = 0.3, a = 1.0},
    textDim = {r = 0.1, g = 0.5, b = 0.15, a = 1.0},
    textWarning = {r = 1.0, g = 0.8, b = 0.0, a = 1.0},
    glow = {r = 0.08, g = 0.3, b = 0.12, a = 0.25},
    scanline = {r = 0.0, g = 0.0, b = 0.0, a = 0.08},
    noise = {r = 0.06, g = 0.12, b = 0.07, a = 0.05},
    ledOn = {r = 0.2, g = 1.0, b = 0.3, a = 1.0},
    ledOff = {r = 0.2, g = 0.3, b = 0.2, a = 0.6},
}

local function getGeneratorObject(record)
    if EPR.Buildings and EPR.Buildings.FindSpriteGeneratorObject then
        return EPR.Buildings.FindSpriteGeneratorObject(record)
    end
    return nil
end

local function findPetrolItem(player)
    if not player or not player.getInventory then return nil end
    local inv = player:getInventory()
    if not inv or not inv.getAllEvalRecurse then return nil end

    local items = inv:getAllEvalRecurse(function(item)
        local fc = item and item.getFluidContainer and item:getFluidContainer() or nil
        if not fc then return false end
        if not fc.contains then return false end
        return fc:contains(Fluid.Petrol) and fc:getAmount() > 0
    end)
    if not items or items:isEmpty() then return nil end
    return items:get(0)
end

local function canRefuel(player, generator)
    if not generator then return false, "No generator" end
    if generator.getFuelPercentage and generator:getFuelPercentage() >= 100 then
        return false, "Fuel full"
    end
    if not findPetrolItem(player) then
        return false, "No petrol"
    end
    return true
end

local function canMaintain(player, generator)
    if not generator then return false, "No generator" end
    if generator.isActivated and generator:isActivated() then
        return false, "Deactivate first"
    end
    if generator.getCondition and generator:getCondition() >= 100 then
        return false, "No maintenance needed"
    end
    if not player or not player.getInventory then return false, "No inventory" end
    if not player:getInventory():containsTypeRecurse("ElectronicsScrap") then
        return false, "Need electronics scrap"
    end
    return true
end

EPR_SpriteGeneratorPanel = ISPanel:derive("EPR_SpriteGeneratorPanel")

function EPR_SpriteGeneratorPanel:new(x, y, width, height, player, record)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.recordKey = record and record.key or nil
    o.record = record
    o.moveWithMouse = true
    o.backgroundColor = Colors.background
    o.borderColor = Colors.border
    return o
end

function EPR_SpriteGeneratorPanel:initialise()
    ISPanel.initialise(self)
end

function EPR_SpriteGeneratorPanel:createChildren()
    ISPanel.createChildren(self)

    self.title = ISLabel:new(18, 12, 20, getEprText("UI_EPR_SpriteGen_Title", "EPR Generator Console"), 1, 1, 1, 1, UIFont.Medium, true)
    self:addChild(self.title)

    self.statusLabel = ISLabel:new(18, 50, 20, "", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.statusLabel)

    self.modeLabel = ISLabel:new(18, 70, 20, "", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.modeLabel)

    self.fuelLabel = ISLabel:new(18, 90, 20, "", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.fuelLabel)

    self.condLabel = ISLabel:new(18, 110, 20, "", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.condLabel)

    self.infoLabel = ISLabel:new(18, 150, 20, "", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.infoLabel)

    self.toggleBtn = ISButton:new(18, self.height - 80, 200, 26, "", self, EPR_SpriteGeneratorPanel.onToggle)
    self:addChild(self.toggleBtn)

    self.refuelBtn = ISButton:new(18, self.height - 50, 200, 24, getEprText("UI_EPR_SpriteGen_Refuel", "Refuel"), self, EPR_SpriteGeneratorPanel.onRefuel)
    self:addChild(self.refuelBtn)

    self.maintBtn = ISButton:new(18, self.height - 22, 200, 24, getEprText("UI_EPR_SpriteGen_Maintain", "Maintenance"), self, EPR_SpriteGeneratorPanel.onMaintain)
    self:addChild(self.maintBtn)

    self.closeBtn = ISButton:new(self.width - 94, 14, 76, 22, getEprText("UI_EPR_Close", "Close"), self, EPR_SpriteGeneratorPanel.onClose)
    self:addChild(self.closeBtn)

    self:refreshStatus()
end

function EPR_SpriteGeneratorPanel:getRecord()
    if self.recordKey and EPR.SpriteGenerators then
        return EPR.SpriteGenerators[self.recordKey]
    end
    return self.record
end

function EPR_SpriteGeneratorPanel:refreshStatus()
    local record = self:getRecord()
    if not record then return end
    self.record = record

    local active = (EPR.Buildings and EPR.Buildings.IsSpriteGeneratorActive and EPR.Buildings.IsSpriteGeneratorActive(record)) or record.active == true
    local statusText = active and getEprText("UI_EPR_SpriteGen_StatusActive", "Status: Active")
        or getEprText("UI_EPR_SpriteGen_StatusInactive", "Status: Inactive")
    self.statusLabel:setName(statusText)
    local statusColor = active and Colors.textPrimary or Colors.textWarning
    self.statusLabel:setColor(statusColor.r, statusColor.g, statusColor.b, statusColor.a)

    local virtualOnly = EPR.Buildings and EPR.Buildings.SpriteGeneratorsUseVirtualOnly and EPR.Buildings.SpriteGeneratorsUseVirtualOnly()
    local modeText = virtualOnly
        and getEprText("UI_EPR_SpriteGen_ModeVirtual", "Mode: Virtual Only")
        or getEprText("UI_EPR_SpriteGen_ModePhysical", "Mode: Generator Object")
    self.modeLabel:setName(modeText)

    local gen = getGeneratorObject(record)
    local fuelText = getEprText("UI_EPR_SpriteGen_FuelNA", "Fuel: N/A")
    local condText = getEprText("UI_EPR_SpriteGen_ConditionNA", "Condition: N/A")
    if virtualOnly then
        local fuel = EPR.Buildings and EPR.Buildings.GetSpriteGeneratorFuel and EPR.Buildings.GetSpriteGeneratorFuel(record) or 0
        local condition = EPR.Buildings and EPR.Buildings.GetSpriteGeneratorCondition and EPR.Buildings.GetSpriteGeneratorCondition(record) or 0
        fuelText = string.format(getEprText("UI_EPR_SpriteGen_FuelPct", "Fuel: %d%%"), math.floor(fuel))
        condText = string.format(getEprText("UI_EPR_SpriteGen_ConditionPct", "Condition: %d%%"), math.floor(condition))
    elseif gen then
        if gen.getFuelPercentage then
            fuelText = string.format(getEprText("UI_EPR_SpriteGen_FuelPct", "Fuel: %d%%"), math.floor(gen:getFuelPercentage()))
        end
        if gen.getCondition then
            condText = string.format(getEprText("UI_EPR_SpriteGen_ConditionPct", "Condition: %d%%"), math.floor(gen:getCondition()))
        end
    end
    self.fuelLabel:setName(fuelText)
    self.condLabel:setName(condText)

    local infoText = getEprText("UI_EPR_SpriteGen_Info", "Powering building-level electricity.")
    self.infoLabel:setName(infoText)

    local toggleText = active
        and getEprText("UI_EPR_SpriteGen_Deactivate", "Deactivate Generator")
        or getEprText("UI_EPR_SpriteGen_Activate", "Activate Generator")
    self.toggleBtn:setTitle(toggleText)

    if virtualOnly then
        self.refuelBtn:setEnable(true)
        self.maintBtn:setEnable(true)
    elseif gen then
        self.refuelBtn:setEnable(true)
        self.maintBtn:setEnable(true)
    else
        self.refuelBtn:setEnable(false)
        self.maintBtn:setEnable(false)
    end
end

function EPR_SpriteGeneratorPanel:update()
    ISPanel.update(self)
    self:refreshStatus()
end

function EPR_SpriteGeneratorPanel:prerender()
    ISPanel.prerender(self)
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawRect(10, 36, self.width - 20, 2, Colors.glow.a, Colors.glow.r, Colors.glow.g, Colors.glow.b)

    local now = getGameTime and getGameTime():getWorldAgeHours() or 0
    local flicker = 0.03 + (math.sin(now * 6) * 0.02)
    self:drawRect(8, 8, self.width - 16, 30, 0.12 + flicker, Colors.glow.r, Colors.glow.g, Colors.glow.b)
end

function EPR_SpriteGeneratorPanel:render()
    ISPanel.render(self)

    -- Scanlines
    for y = 42, self.height - 10, 4 do
        self:drawRect(2, y, self.width - 4, 1, Colors.scanline.a, Colors.scanline.r, Colors.scanline.g, Colors.scanline.b)
    end

    -- Noise specks
    for i = 1, 18 do
        local x = ZombRand(self.width - 6) + 3
        local y = ZombRand(self.height - 6) + 3
        self:drawRect(x, y, 1, 1, Colors.noise.a, Colors.noise.r, Colors.noise.g, Colors.noise.b)
    end

    -- Status LED
    local record = self:getRecord()
    local active = record and ((EPR.Buildings and EPR.Buildings.IsSpriteGeneratorActive and EPR.Buildings.IsSpriteGeneratorActive(record)) or record.active == true)
    local led = active and Colors.ledOn or Colors.ledOff
    self:drawRect(self.width - 26, 16, 6, 6, led.a, led.r, led.g, led.b)
end

function EPR_SpriteGeneratorPanel:onToggle()
    local record = self:getRecord()
    if not record then return end
    local active = (EPR.Buildings and EPR.Buildings.IsSpriteGeneratorActive and EPR.Buildings.IsSpriteGeneratorActive(record)) or record.active == true
    if EPR.ContextMenu and EPR.ContextMenu.OnToggleSpriteGenerator then
        EPR.ContextMenu.OnToggleSpriteGenerator(self.player, record.key, not active)
    end
end

function EPR_SpriteGeneratorPanel:onRefuel()
    local record = self:getRecord()
    if not record then return end
    local gen = getGeneratorObject(record)
    local virtualOnly = EPR.Buildings and EPR.Buildings.SpriteGeneratorsUseVirtualOnly and EPR.Buildings.SpriteGeneratorsUseVirtualOnly()
    if virtualOnly then
        if EPR.ContextMenu and EPR.ContextMenu.OnSpriteGeneratorRefuel then
            EPR.ContextMenu.OnSpriteGeneratorRefuel(self.player, record.key)
        end
        return
    end
    local ok, reason = canRefuel(self.player, gen)
    if not ok then
        if self.player and self.player.Say then
            self.player:Say(reason or "Unable to refuel")
        end
        return
    end

    local petrol = findPetrolItem(self.player)
    if not petrol then return end

    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.transferIfNeeded then
        ISInventoryPaneContextMenu.transferIfNeeded(self.player, petrol)
    end
    if ISWorldObjectContextMenu and ISWorldObjectContextMenu.equip then
        ISWorldObjectContextMenu.equip(self.player, self.player:getPrimaryHandItem(), petrol, true, false)
    end
    if luautils and luautils.walkAdj and gen and gen.getSquare then
        if not luautils.walkAdj(self.player, gen:getSquare()) then
            return
        end
    end
    ISTimedActionQueue.add(ISAddFuel:new(self.player, gen, petrol))
end

function EPR_SpriteGeneratorPanel:onMaintain()
    local record = self:getRecord()
    if not record then return end
    local gen = getGeneratorObject(record)
    local virtualOnly = EPR.Buildings and EPR.Buildings.SpriteGeneratorsUseVirtualOnly and EPR.Buildings.SpriteGeneratorsUseVirtualOnly()
    if virtualOnly then
        if EPR.ContextMenu and EPR.ContextMenu.OnSpriteGeneratorMaintain then
            EPR.ContextMenu.OnSpriteGeneratorMaintain(self.player, record.key)
        end
        return
    end
    local ok, reason = canMaintain(self.player, gen)
    if not ok then
        if self.player and self.player.Say then
            self.player:Say(reason or "Unable to maintain")
        end
        return
    end
    if luautils and luautils.walkAdj and gen and gen.getSquare then
        if not luautils.walkAdj(self.player, gen:getSquare()) then
            return
        end
    end
    ISTimedActionQueue.add(ISFixGenerator:new(self.player, gen))
end

function EPR_SpriteGeneratorPanel:onClose()
    if EPR.SpriteGeneratorUI and EPR.SpriteGeneratorUI.Close then
        EPR.SpriteGeneratorUI.Close()
    end
end

function EPR.SpriteGeneratorUI.Open(player, record)
    if not record then return end
    if EPR.SpriteGeneratorUI.instance then
        EPR.SpriteGeneratorUI.instance:onClose()
    end

    local width, height = 420, 260
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)
    local panel = EPR_SpriteGeneratorPanel:new(x, y, width, height, player, record)
    panel:initialise()
    panel:addToUIManager()
    EPR.SpriteGeneratorUI.instance = panel
end

function EPR.SpriteGeneratorUI.Close()
    if EPR.SpriteGeneratorUI.instance then
        EPR.SpriteGeneratorUI.instance:removeFromUIManager()
        EPR.SpriteGeneratorUI.instance = nil
    end
end

function EPR.SpriteGeneratorUI.IsOpen()
    return EPR.SpriteGeneratorUI.instance ~= nil
end

function EPR.SpriteGeneratorUI.RefreshIfOpen()
    if EPR.SpriteGeneratorUI.IsOpen() and EPR.SpriteGeneratorUI.instance then
        EPR.SpriteGeneratorUI.instance:refreshStatus()
    end
end
