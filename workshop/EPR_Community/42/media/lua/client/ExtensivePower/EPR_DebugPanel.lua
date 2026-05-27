--[[
    EPR Debug Panel - admin verification tool.

    Lets an admin (or SP host) drive every visible EPR feature manually:
      * Zones tab     - toggle power/water for each zone
      * Facilities tab - list every substation/water plant, teleport to it,
                         flicker its startup, force-repair, force-activate,
                         force-deactivate
      * World tab     - toggle global power override; trigger a noise burst
                         (zombie attraction) at the player's location

    Gating: SandboxVars.EPR.DebugMode must be true AND the player must be admin
    (or be in SP). The server enforces the same gate on every command.

    Open with chat command:  /eprdebug
]]

print("[EPR DebugPanel] loading...")

if isServer() and not isClient() then return end

EPR = EPR or {}
EPR.Client = EPR.Client or {}

-- ============================================================
-- Helpers
-- ============================================================

local function isAdminOrSp()
    local p = getSpecificPlayer and getSpecificPlayer(0)
    if not p then return false end
    if not isClient() then return true end -- host / SP
    if p.getAccessLevel then
        local lvl = p:getAccessLevel()
        if lvl and lvl ~= "" and lvl ~= "None" then return true end
    end
    return false
end

local function debugEnabled()
    if EPR.IsDebugMode then return EPR.IsDebugMode() end
    if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.DebugMode then return true end
    return false
end

local function send(command, args)
    -- In MP, sendClientCommand goes to server. In SP, also dispatch the
    -- server-side handler directly so the panel works offline too.
    if isClient() and sendClientCommand then
        sendClientCommand("EPR", command, args)
        return
    end
    -- SP path
    local p = getSpecificPlayer and getSpecificPlayer(0)
    if EPR.Server and EPR.Server.OnClientCommand and p then
        EPR.Server.OnClientCommand("EPR", command, p, args)
    end
end

local function sortedKeys(t)
    local out = {}
    if not t then return out end
    for k, _ in pairs(t) do table.insert(out, k) end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

-- ============================================================
-- Panel class
-- ============================================================

EPR_DebugPanel = ISCollapsableWindow:derive("EPR_DebugPanel")
EPR_DebugPanel.instance = nil

local TAB_ZONES = 1
local TAB_FACILITIES = 2
local TAB_WORLD = 3

function EPR_DebugPanel:new(x, y)
    local w, h = 760, 560
    local o = ISCollapsableWindow:new(x or 80, y or 80, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = "EPR Debug Panel"
    o.resizable = false
    o.activeTab = TAB_ZONES
    o.zoneScrollY = 0
    o.facScrollY = 0
    o.burstRadius = 50
    o.burstVolume = 120
    return o
end

function EPR_DebugPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local topY = self:titleBarHeight() + 8
    local btnW, btnH, pad = 120, 24, 6

    self.tabZones = ISButton:new(10, topY, btnW, btnH, "Zones", self, EPR_DebugPanel.onTab)
    self.tabZones.internal = TAB_ZONES
    self.tabZones:initialise(); self:addChild(self.tabZones)

    self.tabFac = ISButton:new(10 + (btnW + pad), topY, btnW, btnH, "Facilities", self, EPR_DebugPanel.onTab)
    self.tabFac.internal = TAB_FACILITIES
    self.tabFac:initialise(); self:addChild(self.tabFac)

    self.tabWorld = ISButton:new(10 + (btnW + pad) * 2, topY, btnW, btnH, "World", self, EPR_DebugPanel.onTab)
    self.tabWorld.internal = TAB_WORLD
    self.tabWorld:initialise(); self:addChild(self.tabWorld)

    self.refreshBtn = ISButton:new(self.width - 90, topY, 80, btnH, "Refresh", self, EPR_DebugPanel.onRefresh)
    self.refreshBtn:initialise(); self:addChild(self.refreshBtn)

    -- World-tab buttons (kept off-screen until that tab is active)
    self.overrideOnBtn = ISButton:new(0, 0, 180, btnH, "Global override ON", self, EPR_DebugPanel.onOverride)
    self.overrideOnBtn.internal = true
    self.overrideOnBtn:initialise(); self:addChild(self.overrideOnBtn)

    self.overrideOffBtn = ISButton:new(0, 0, 180, btnH, "Global override OFF", self, EPR_DebugPanel.onOverride)
    self.overrideOffBtn.internal = false
    self.overrideOffBtn:initialise(); self:addChild(self.overrideOffBtn)

    self.noiseBtn = ISButton:new(0, 0, 220, btnH, "Noise burst at me", self, EPR_DebugPanel.onNoiseBurst)
    self.noiseBtn:initialise(); self:addChild(self.noiseBtn)

    self.radiusMinus = ISButton:new(0, 0, 24, 24, "-", self, EPR_DebugPanel.onRadius); self.radiusMinus.internal = -10
    self.radiusMinus:initialise(); self:addChild(self.radiusMinus)
    self.radiusPlus  = ISButton:new(0, 0, 24, 24, "+", self, EPR_DebugPanel.onRadius); self.radiusPlus.internal = 10
    self.radiusPlus:initialise(); self:addChild(self.radiusPlus)
    self.volMinus = ISButton:new(0, 0, 24, 24, "-", self, EPR_DebugPanel.onVolume); self.volMinus.internal = -20
    self.volMinus:initialise(); self:addChild(self.volMinus)
    self.volPlus  = ISButton:new(0, 0, 24, 24, "+", self, EPR_DebugPanel.onVolume); self.volPlus.internal = 20
    self.volPlus:initialise(); self:addChild(self.volPlus)

    self.shutoffBtn = ISButton:new(0, 0, 240, btnH, "Force vanilla shutoff NOW", self, EPR_DebugPanel.onForceShutoff)
    self.shutoffBtn:initialise(); self:addChild(self.shutoffBtn)

    self.lightningBtn = ISButton:new(0, 0, 240, btnH, "Lightning strike (random)", self, EPR_DebugPanel.onLightning)
    self.lightningBtn:initialise(); self:addChild(self.lightningBtn)

    self.lightningAllBtn = ISButton:new(0, 0, 240, btnH, "Lightning strike ALL online", self, EPR_DebugPanel.onLightningAll)
    self.lightningAllBtn:initialise(); self:addChild(self.lightningAllBtn)

    self:layoutWorldTab()
    self:applyTab()
end

function EPR_DebugPanel:layoutWorldTab()
    local x = 20
    local y = self:titleBarHeight() + 50
    self.overrideOnBtn:setX(x);   self.overrideOnBtn:setY(y)
    self.overrideOffBtn:setX(x + 190); self.overrideOffBtn:setY(y)
    y = y + 40
    self.radiusMinus:setX(x + 140); self.radiusMinus:setY(y)
    self.radiusPlus:setX(x + 200);  self.radiusPlus:setY(y)
    y = y + 30
    self.volMinus:setX(x + 140); self.volMinus:setY(y)
    self.volPlus:setX(x + 200);  self.volPlus:setY(y)
    y = y + 36
    self.noiseBtn:setX(x); self.noiseBtn:setY(y)
    y = y + 36
    self.shutoffBtn:setX(x); self.shutoffBtn:setY(y)
    y = y + 36
    self.lightningBtn:setX(x); self.lightningBtn:setY(y)
    y = y + 30
    self.lightningAllBtn:setX(x); self.lightningAllBtn:setY(y)
end

function EPR_DebugPanel:applyTab()
    local world = (self.activeTab == TAB_WORLD)
    self.overrideOnBtn:setVisible(world)
    self.overrideOffBtn:setVisible(world)
    self.noiseBtn:setVisible(world)
    self.radiusMinus:setVisible(world)
    self.radiusPlus:setVisible(world)
    self.volMinus:setVisible(world)
    self.volPlus:setVisible(world)
    self.shutoffBtn:setVisible(world)
    self.lightningBtn:setVisible(world)
    self.lightningAllBtn:setVisible(world)
end

-- ============================================================
-- Tab buttons
-- ============================================================

function EPR_DebugPanel:onTab(btn)
    self.activeTab = btn.internal
    self:applyTab()
end

function EPR_DebugPanel:onRefresh()
    if EPR.Client and EPR.Client.RequestSync then EPR.Client.RequestSync() end
end

-- ============================================================
-- Zone actions
-- ============================================================

function EPR_DebugPanel:onZonePower(btn)
    send("AdminSetPower", { zone = btn.internal.zone, powered = btn.internal.state })
    self.rowsDirty = true
end

function EPR_DebugPanel:onZoneWater(btn)
    send("AdminSetWater", { zone = btn.internal.zone, watered = btn.internal.state })
end

-- ============================================================
-- Facility actions
-- ============================================================

function EPR_DebugPanel:onFacRepair(btn)
    send("DebugRepairAll", { facilityId = btn.internal })
    self.rowsDirty = true
end
function EPR_DebugPanel:onFacActivate(btn)
    send("DebugActivate", { facilityId = btn.internal })
    self.rowsDirty = true
end
function EPR_DebugPanel:onFacDeactivate(btn)
    send("DebugDeactivate", { facilityId = btn.internal })
    self.rowsDirty = true
end
function EPR_DebugPanel:onFacFlicker(btn)
    send("DebugFlicker", { facilityId = btn.internal })
end
function EPR_DebugPanel:onFacTeleport(btn)
    local f = btn.internal
    local p = getSpecificPlayer and getSpecificPlayer(0)
    if not (p and f and f.x and f.y) then return end
    local z = f.z or 0
    local cell = getCell and getCell()
    local sq = cell and cell.getOrCreateGridSquare and cell:getOrCreateGridSquare(f.x, f.y, z)
    if not sq then return end
    if p.teleportTo then
        pcall(function() p:teleportTo(f.x + 0.5, f.y + 0.5, z) end)
    else
        if p.setX  then p:setX(f.x + 0.5) end
        if p.setY  then p:setY(f.y + 0.5) end
        if p.setZ  then p:setZ(z) end
    end
    if p.setLx then p:setLx(f.x + 0.5) end
    if p.setLy then p:setLy(f.y + 0.5) end
    if p.setLz then p:setLz(z) end
    if p.setCurrent then p:setCurrent(sq) end
end

-- ============================================================
-- World actions
-- ============================================================

function EPR_DebugPanel:onOverride(btn)
    send("DebugGlobalOverride", { enabled = btn.internal == true })
end

function EPR_DebugPanel:onRadius(btn)
    self.burstRadius = math.max(5, math.min(200, self.burstRadius + btn.internal))
end

function EPR_DebugPanel:onVolume(btn)
    self.burstVolume = math.max(10, math.min(200, self.burstVolume + btn.internal))
end

function EPR_DebugPanel:onForceShutoff()
    send("DebugForceShutoff", {})
end

function EPR_DebugPanel:onLightning()
    send("DebugLightningStrike", {})
    self.rowsDirty = true
end

function EPR_DebugPanel:onLightningAll()
    send("DebugLightningStrike", { all = true })
    self.rowsDirty = true
end

function EPR_DebugPanel:onNoiseBurst()
    local p = getSpecificPlayer and getSpecificPlayer(0)
    if not p then return end
    send("DebugNoiseBurst", {
        x = math.floor(p:getX()), y = math.floor(p:getY()), z = math.floor(p:getZ()),
        radius = self.burstRadius, volume = self.burstVolume,
    })
end

-- ============================================================
-- Rendering - we draw rows manually each frame and create
-- per-row buttons lazily under a child container per tab so
-- the layout stays simple and refreshes when data changes.
-- ============================================================

function EPR_DebugPanel:prerender()
    ISCollapsableWindow.prerender(self)
    self:rebuildRowsIfNeeded()
end

function EPR_DebugPanel:rebuildRowsIfNeeded()
    if self.rowsTab == self.activeTab and self.rowsDirty ~= true then return end
    self.rowsTab = self.activeTab
    self.rowsDirty = false

    -- Tear down old row widgets.
    if self.rowWidgets then
        for _, w in ipairs(self.rowWidgets) do self:removeChild(w) end
    end
    self.rowWidgets = {}

    if self.activeTab == TAB_ZONES then
        self:buildZoneRows()
    elseif self.activeTab == TAB_FACILITIES then
        self:buildFacilityRows()
    end
end

local function addBtn(self, x, y, w, h, text, fn, internal)
    local b = ISButton:new(x, y, w, h, text, self, fn)
    b.internal = internal
    b:initialise(); b:instantiate()
    self:addChild(b)
    table.insert(self.rowWidgets, b)
    return b
end

local function addLabel(self, x, y, text)
    local lbl = ISLabel:new(x, y, 18, text, 1, 1, 1, 1, UIFont.Small, true)
    lbl:initialise(); lbl:instantiate()
    self:addChild(lbl)
    table.insert(self.rowWidgets, lbl)
    return lbl
end

function EPR_DebugPanel:buildZoneRows()
    local startY = self:titleBarHeight() + 42
    local rowH = 26
    -- Union of power + water zones
    local union = {}
    for k, _ in pairs(EPR.PoweredZones or {}) do union[k] = true end
    for k, _ in pairs(EPR.WaterZones or {}) do union[k] = true end
    local zones = {}
    for k, _ in pairs(union) do table.insert(zones, k) end
    table.sort(zones)

    addLabel(self, 10, startY - 18, "Zone (" .. #zones .. ")        Power           Water")
    for i, z in ipairs(zones) do
        local y = startY + (i - 1) * rowH
        if y > self.height - rowH then break end
        local pw = (EPR.PoweredZones or {})[z] and "ON" or "off"
        local wt = (EPR.WaterZones or {})[z] and "ON" or "off"
        addLabel(self, 14, y + 4, z .. "  [" .. pw .. "/" .. wt .. "]")
        addBtn(self, 320, y, 50, 22, "P on",  EPR_DebugPanel.onZonePower, { zone = z, state = true })
        addBtn(self, 374, y, 50, 22, "P off", EPR_DebugPanel.onZonePower, { zone = z, state = false })
        addBtn(self, 440, y, 50, 22, "W on",  EPR_DebugPanel.onZoneWater, { zone = z, state = true })
        addBtn(self, 494, y, 50, 22, "W off", EPR_DebugPanel.onZoneWater, { zone = z, state = false })
    end
end

function EPR_DebugPanel:buildFacilityRows()
    local startY = self:titleBarHeight() + 42
    local rowH = 28
    local list = {}
    local function collect(tbl, kind)
        if not tbl then return end
        for fid, state in pairs(tbl) do
            local fac = EPR.Zones and EPR.Zones.GetFacility and EPR.Zones.GetFacility(fid) or nil
            table.insert(list, {
                id = fid,
                kind = kind,
                status = state and state.status or "?",
                x = fac and fac.x, y = fac and fac.y, z = fac and fac.z,
                name = fac and fac.name or fid,
            })
        end
    end
    collect(EPR.Substations, "power")
    collect(EPR.WaterPlants, "water")
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)

    addLabel(self, 10, startY - 18, "Facilities (" .. #list .. ")")
    for i, f in ipairs(list) do
        local y = startY + (i - 1) * rowH
        if y > self.height - rowH then break end
        addLabel(self, 14, y + 5, "[" .. f.kind .. "] " .. f.id .. "  (" .. f.status .. ")")
        local bx = 360
        if f.x and f.y then
            addBtn(self, bx, y, 56, 22, "TP", EPR_DebugPanel.onFacTeleport, f); bx = bx + 60
        end
        addBtn(self, bx, y, 60, 22, "Flicker",    EPR_DebugPanel.onFacFlicker,    f.id); bx = bx + 64
        addBtn(self, bx, y, 60, 22, "Repair",     EPR_DebugPanel.onFacRepair,     f.id); bx = bx + 64
        addBtn(self, bx, y, 70, 22, "Activate",   EPR_DebugPanel.onFacActivate,   f.id); bx = bx + 74
        addBtn(self, bx, y, 80, 22, "Deactivate", EPR_DebugPanel.onFacDeactivate, f.id)
    end
end

function EPR_DebugPanel:render()
    ISCollapsableWindow.render(self)
    if self.activeTab == TAB_WORLD then
        local x = 20
        local y = self:titleBarHeight() + 50
        self:drawText("Global power override", x, y + 4, 1, 1, 1, 1, UIFont.Small)
        y = y + 40
        self:drawText("Noise burst radius:  " .. self.burstRadius, x, y + 4, 1, 1, 1, 1, UIFont.Small)
        y = y + 30
        self:drawText("Noise burst volume:  " .. self.burstVolume, x, y + 4, 1, 1, 1, 1, UIFont.Small)
        y = y + 60
        local gOv = EPR.PowerController and EPR.PowerController.globalOverride
        self:drawText("Current global override: " .. tostring(gOv == true), x, y, 1, 1, 1, 1, UIFont.Small)
    end
end

-- ============================================================
-- Open/close
-- ============================================================

function EPR.Client.OpenDebugPanel()
    if not isAdminOrSp() then
        if getSpecificPlayer and getSpecificPlayer(0) then
            getSpecificPlayer(0):Say("EPR Debug Panel: admin only.")
        end
        return
    end
    if not debugEnabled() then
        if getSpecificPlayer and getSpecificPlayer(0) then
            getSpecificPlayer(0):Say("EPR Debug Panel: enable EPR.DebugMode in sandbox.")
        end
        return
    end
    if EPR_DebugPanel.instance and EPR_DebugPanel.instance:getIsVisible() then
        EPR_DebugPanel.instance:close()
        EPR_DebugPanel.instance = nil
        return
    end
    local p = EPR_DebugPanel:new(120, 120)
    p:initialise(); p:instantiate()
    p:addToUIManager()
    p:setVisible(true)
    EPR_DebugPanel.instance = p
end

print("[EPR DebugPanel] loaded - EPR.Client.OpenDebugPanel ready")
