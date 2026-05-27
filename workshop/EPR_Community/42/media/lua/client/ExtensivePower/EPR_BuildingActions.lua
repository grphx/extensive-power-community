--[[
    Extensive Power Rework - Building Actions
]]--

if isServer() and not isClient() then return end

print("[EPR] EPR_BuildingActions.lua loading...")

require "TimedActions/ISBaseTimedAction"

EPR = EPR or {}
EPR.Actions = EPR.Actions or {}

EPR_BuildingConnectAction = ISBaseTimedAction:derive("EPR_BuildingConnectAction")

function EPR_BuildingConnectAction:new(player, square, zoneName)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = player
    o.square = square
    o.x = square and square.getX and square:getX() or nil
    o.y = square and square.getY and square:getY() or nil
    o.z = square and square.getZ and square:getZ() or 0
    o.zoneName = zoneName
    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = true
    o.caloriesModifier = 2

    local minutes = (EPR.Config and EPR.Config.BuildingConnectTimeMinutes) or 5
    o.maxTime = minutes * 60

    return o
end

function EPR_BuildingConnectAction:isValid()
    if not self.character then return false end
    if (not self.square) and (self.x ~= nil and self.y ~= nil) then
        self.square = getSquare(self.x, self.y, self.z or 0)
    end
    if not self.square then return false end
    local px = self.character:getX()
    local py = self.character:getY()
    local sx = self.square.getX and self.square:getX() or self.x
    local sy = self.square.getY and self.square:getY() or self.y
    if sx == nil or sy == nil then return false end
    local dx = sx - px
    local dy = sy - py
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist <= 2
end

function EPR_BuildingConnectAction:start()
    self:setActionAnim("Loot")
    self.character:Say("Connecting to the grid...")
end

function EPR_BuildingConnectAction:stop()
    self.character:Say("Stopped.")
    ISBaseTimedAction.stop(self)
end

function EPR_BuildingConnectAction:perform()
    if (not self.square) and (self.x ~= nil and self.y ~= nil) then
        self.square = getSquare(self.x, self.y, self.z or 0)
    end
    if EPR.ContextMenu and EPR.ContextMenu.PerformConnectBuilding and self.square then
        local ok, err = pcall(EPR.ContextMenu.PerformConnectBuilding, self.character, self.square, self.zoneName)
        if not ok then
            if EPR.LogDebug then EPR.LogDebug("[EPR] ConnectBuilding failed: " .. tostring(err)) end
            self.character:Say("Can't connect right now.")
        end
    end
    ISBaseTimedAction.perform(self)
end

print("[EPR] EPR_BuildingActions.lua loaded successfully")
