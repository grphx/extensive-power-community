--[[
    Extensive Power Rework - Facility UI Panel (Version 2.0)

    Comprehensive tabbed interface for facility management.
    Features:
    - 3 tabs: Overview, Repairs, Status
    - Rich header with health bar and status icons
    - Visual component grid with power flow lines
    - Enhanced CRT effects with LED indicators
    - Real-time updates and state memory
    - Keyboard navigation (1, 2, 3 for tabs)
]]--

if isServer() and not isClient() then return end

print("[EPR] EPR_FacilityUI_New.lua loading...")

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"

EPR = EPR or {}
EPR.FacilityUI = EPR.FacilityUI or {}

local function saveIfAuthoritative()
    if EPR and EPR.IsServerContext and EPR.IsServerContext() then
        EPR.SaveData()
    end
end

local function getEprText(key, fallback)
    local ok = getText and getText(key)
    if ok and ok ~= key then return ok end
    return fallback
end

local function getZoneDisplayName(zone)
    if not zone or zone == "" then return "" end
    return getEprText("UI_EPR_Zone_" .. zone, zone)
end

local function getFacilityDisplayName(facility)
    if not facility then return "UNKNOWN FACILITY" end
    if facility.key and facility.key ~= "" then
        return getEprText("UI_EPR_Facility_" .. facility.key, facility.name or facility.key)
    end
    return facility.name or "UNKNOWN FACILITY"
end

-- State memory for UI persistence
EPR.FacilityUI.StateMemory = {
    currentTab = 1,
    scrollPositions = {},
    selectedComponent = nil,
}

-- ============================================
-- COLOR PALETTE (Enhanced Terminal Theme)
-- ============================================

local Colors = {
    -- Backgrounds
    background = {r = 0.01, g = 0.02, b = 0.01, a = 0.98},
    backgroundDark = {r = 0.005, g = 0.01, b = 0.005, a = 1.0},
    panelBg = {r = 0.02, g = 0.04, b = 0.02, a = 0.95},
    headerBg = {r = 0.03, g = 0.06, b = 0.03, a = 1.0},
    scanline = {r = 0.0, g = 0.0, b = 0.0, a = 0.12},
    glow = {r = 0.1, g = 0.4, b = 0.15, a = 0.08},

    -- Text colors
    textPrimary = {r = 0.2, g = 1.0, b = 0.3, a = 1.0},
    textDim = {r = 0.1, g = 0.5, b = 0.15, a = 1.0},
    textHighlight = {r = 0.4, g = 1.0, b = 0.5, a = 1.0},
    textWarning = {r = 1.0, g = 0.8, b = 0.0, a = 1.0},
    textDanger = {r = 1.0, g = 0.2, b = 0.2, a = 1.0},
    textSuccess = {r = 0.3, g = 1.0, b = 0.4, a = 1.0},
    textMuted = {r = 0.15, g = 0.4, b = 0.2, a = 0.8},

    -- Border
    border = {r = 0.15, g = 0.6, b = 0.2, a = 1.0},
    borderDim = {r = 0.1, g = 0.3, b = 0.12, a = 0.6},
    borderHighlight = {r = 0.3, g = 0.9, b = 0.4, a = 1.0},

    -- LED Indicators
    ledOnline = {r = 0.2, g = 1.0, b = 0.3, a = 1.0},
    ledOffline = {r = 0.4, g = 0.4, b = 0.4, a = 1.0},
    ledRepairing = {r = 1.0, g = 0.8, b = 0.0, a = 1.0},
    ledBroken = {r = 1.0, g = 0.2, b = 0.2, a = 1.0},
    ledReady = {r = 0.3, g = 0.8, b = 1.0, a = 1.0},
    ledStarting = {r = 1.0, g = 0.6, b = 0.0, a = 1.0},

    -- Tab colors
    tabActive = {r = 0.05, g = 0.15, b = 0.08, a = 1.0},
    tabInactive = {r = 0.02, g = 0.05, b = 0.03, a = 0.8},
    tabBorder = {r = 0.2, g = 0.7, b = 0.3, a = 1.0},

    -- Button colors
    buttonBg = {r = 0.04, g = 0.12, b = 0.06, a = 1.0},
    buttonBgHover = {r = 0.06, g = 0.18, b = 0.09, a = 1.0},
    buttonBorder = {r = 0.2, g = 0.8, b = 0.3, a = 1.0},
    buttonText = {r = 0.2, g = 1.0, b = 0.3, a = 1.0},

    -- Flow lines
    flowLine = {r = 0.1, g = 0.4, b = 0.15, a = 0.6},
    flowLineActive = {r = 0.2, g = 0.8, b = 0.3, a = 0.8},

    -- Health bar gradients
    healthHigh = {r = 0.2, g = 1.0, b = 0.3, a = 1.0},
    healthMid = {r = 1.0, g = 0.8, b = 0.0, a = 1.0},
    healthLow = {r = 1.0, g = 0.2, b = 0.2, a = 1.0},
}

-- ============================================
-- MAIN PANEL CLASS
-- ============================================

EPR_FacilityPanelNew = ISPanel:derive("EPR_FacilityPanelNew")

function EPR_FacilityPanelNew:new(x, y, width, height, player, facility, status)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.player = player
    o.facility = facility
    o.status = status or {}

    o.backgroundColor = Colors.background
    o.borderColor = Colors.border

    o.moveWithMouse = true
    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = true
    o.anchorBottom = false

    -- Tab system
    o.tabs = {
        getEprText("UI_EPR_Tab_Overview", "OVERVIEW"),
        getEprText("UI_EPR_Tab_Repairs", "REPAIRS"),
        getEprText("UI_EPR_Tab_Status", "STATUS"),
    }
    o.currentTab = EPR.FacilityUI.StateMemory.currentTab or 1
    o.tabButtons = {}

    -- CRT effects
    o.blinkTimer = 0
    o.blinkOn = true
    o.flickerAlpha = 1.0
    o.staticTimer = 0
    o.staticIntensity = 0
    o.glowPulse = 0

    -- Update timer
    o.updateTimer = 0
    o.updateInterval = 30  -- Update every 30 ticks (~0.5 seconds)

    -- Selected component for grid
    o.selectedComponent = EPR.FacilityUI.StateMemory.selectedComponent

    -- Scroll positions
    o.scrollY = EPR.FacilityUI.StateMemory.scrollPositions[o.currentTab] or 0
    o.componentListScrollY = 0  -- Separate scroll for component list

    -- Alert system
    o.alerts = {}
    o.alertTimer = 0

    return o
end

function EPR_FacilityPanelNew:initialise()
    ISPanel.initialise(self)
end

function EPR_FacilityPanelNew:createChildren()
    ISPanel.createChildren(self)

    local padX = 15
    local headerHeight = 80
    local tabHeight = 35

    -- Close button (top right)
    self.closeBtn = ISButton:new(self.width - 50, 12, 40, 30, "[X]", self, EPR_FacilityPanelNew.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self.closeBtn.backgroundColor = Colors.buttonBg
    self.closeBtn.borderColor = Colors.textDanger
    self.closeBtn.textColor = Colors.textDanger
    self.closeBtn:setFont(UIFont.Medium)
    self:addChild(self.closeBtn)

    -- Tab buttons
    local tabWidth = math.floor((self.width - padX * 2 - 20) / #self.tabs)
    local tabY = headerHeight + 5

    for i, tabName in ipairs(self.tabs) do
        local tabX = padX + (i - 1) * (tabWidth + 5)
        local btn = ISButton:new(tabX, tabY, tabWidth, tabHeight, tabName, self, EPR_FacilityPanelNew.onTabClick)
        btn:initialise()
        btn:instantiate()
        btn.internal = i
        btn.backgroundColor = i == self.currentTab and Colors.tabActive or Colors.tabInactive
        btn.borderColor = Colors.tabBorder
        btn.textColor = i == self.currentTab and Colors.textHighlight or Colors.textDim
        btn:setFont(UIFont.Medium)
        self:addChild(btn)
        self.tabButtons[i] = btn
    end
end

-- ============================================
-- TAB SWITCHING
-- ============================================

function EPR_FacilityPanelNew:onTabClick(button)
    local tabIndex = button.internal
    self:switchTab(tabIndex)
end

function EPR_FacilityPanelNew:switchTab(tabIndex)
    if tabIndex < 1 or tabIndex > #self.tabs then return end

    -- Save current scroll position
    EPR.FacilityUI.StateMemory.scrollPositions[self.currentTab] = self.scrollY

    self.currentTab = tabIndex
    EPR.FacilityUI.StateMemory.currentTab = tabIndex

    -- Restore scroll position for new tab
    self.scrollY = EPR.FacilityUI.StateMemory.scrollPositions[tabIndex] or 0

    -- Update tab button colors
    for i, btn in ipairs(self.tabButtons) do
        btn.backgroundColor = i == tabIndex and Colors.tabActive or Colors.tabInactive
        btn.textColor = i == tabIndex and Colors.textHighlight or Colors.textDim
    end

    -- Play tab switch sound (subtle click)
    -- getSoundManager():PlayWorldSound("UITabClick", false, nil, 0, 0, 0, 0, 0.3)
end

-- ============================================
-- KEYBOARD HANDLING
-- ============================================

function EPR_FacilityPanelNew:onKeyRelease(key)
    -- ESC to close
    if key == Keyboard.KEY_ESCAPE then
        self:onClose()
        return true
    end

    -- Number keys for tabs (1, 2, 3)
    if key == Keyboard.KEY_1 then
        self:switchTab(1)
        return true
    elseif key == Keyboard.KEY_2 then
        self:switchTab(2)
        return true
    elseif key == Keyboard.KEY_3 then
        self:switchTab(3)
        return true
    end

    return false
end

-- ============================================
-- PRERENDER - CRT EFFECTS
-- ============================================

function EPR_FacilityPanelNew:prerender()
    ISPanel.prerender(self)

    -- Draw outer glow effect
    self:drawScreenGlow()

    -- Draw scanlines
    self:drawScanlines()

    -- Draw static noise (occasional)
    if self.staticIntensity > 0 then
        self:drawStaticNoise()
    end

    -- Draw terminal border
    self:drawTerminalBorder()
end

function EPR_FacilityPanelNew:drawScreenGlow()
    local c = Colors.glow
    local glowAlpha = c.a * (0.8 + math.sin(self.glowPulse) * 0.2)

    -- Inner glow around edges
    for i = 1, 8 do
        local alpha = glowAlpha * (1 - i / 10)
        self:drawRect(i, i, self.width - i * 2, 1, alpha, c.r, c.g, c.b)
        self:drawRect(i, self.height - i - 1, self.width - i * 2, 1, alpha, c.r, c.g, c.b)
        self:drawRect(i, i, 1, self.height - i * 2, alpha, c.r, c.g, c.b)
        self:drawRect(self.width - i - 1, i, 1, self.height - i * 2, alpha, c.r, c.g, c.b)
    end
end

function EPR_FacilityPanelNew:drawScanlines()
    local c = Colors.scanline
    for y = 0, self.height, 2 do
        self:drawRect(0, y, self.width, 1, c.a, c.r, c.g, c.b)
    end
end

function EPR_FacilityPanelNew:drawStaticNoise()
    -- Use pre-calculated positions from update() for performance
    if not self.staticNoisePositions then return end
    for _, pos in ipairs(self.staticNoisePositions) do
        self:drawRect(pos.x, pos.y, pos.size, pos.size, pos.alpha * self.staticIntensity, 0.8, 1.0, 0.8)
    end
end

function EPR_FacilityPanelNew:drawTerminalBorder()
    local c = Colors.border
    local w = self.width
    local h = self.height

    -- Main border
    self:drawRect(0, 0, w, 3, 1, c.r, c.g, c.b)
    self:drawRect(0, h - 3, w, 3, 1, c.r, c.g, c.b)
    self:drawRect(0, 0, 3, h, 1, c.r, c.g, c.b)
    self:drawRect(w - 3, 0, 3, h, 1, c.r, c.g, c.b)

    -- Corner accents (rounded effect)
    local cornerSize = 12
    self:drawRect(0, 0, cornerSize, cornerSize, 0.5, c.r, c.g, c.b)
    self:drawRect(w - cornerSize, 0, cornerSize, cornerSize, 0.5, c.r, c.g, c.b)
    self:drawRect(0, h - cornerSize, cornerSize, cornerSize, 0.5, c.r, c.g, c.b)
    self:drawRect(w - cornerSize, h - cornerSize, cornerSize, cornerSize, 0.5, c.r, c.g, c.b)

    -- Soften corners (creates rounded appearance)
    local bg = Colors.background
    self:drawRect(0, 0, 4, 4, 1, bg.r, bg.g, bg.b)
    self:drawRect(w - 4, 0, 4, 4, 1, bg.r, bg.g, bg.b)
    self:drawRect(0, h - 4, 4, 4, 1, bg.r, bg.g, bg.b)
    self:drawRect(w - 4, h - 4, 4, 4, 1, bg.r, bg.g, bg.b)
end

-- ============================================
-- RENDER - MAIN CONTENT
-- ============================================

function EPR_FacilityPanelNew:render()
    ISPanel.render(self)

    -- Reset action buttons before rendering (fix memory leak)
    self.actionButtons = {}

    local padX = 15
    local y = 12

    -- Render header
    y = self:renderHeader(padX, y)

    -- Content area starts after tabs
    local contentY = 130
    local contentHeight = self.height - contentY - 20

    -- Store content area info for click handling
    self.contentY = contentY
    self.contentPadX = padX

    -- Render current tab content
    if self.currentTab == 1 then
        self:renderOverviewTab(padX, contentY, self.width - padX * 2, contentHeight)
    elseif self.currentTab == 2 then
        self:renderRepairsTab(padX, contentY, self.width - padX * 2, contentHeight)
    elseif self.currentTab == 3 then
        self:renderStatusTab(padX, contentY, self.width - padX * 2, contentHeight)
    end

    -- Render alerts (on top of everything)
    self:renderAlerts()

    -- Render startup warning if active
    if self.status.status == "starting" then
        self:renderStartupWarning()
    end
end

-- ============================================
-- HEADER RENDERING
-- ============================================

function EPR_FacilityPanelNew:renderHeader(padX, y)
    -- Facility name (large)
    local title = string.upper(getFacilityDisplayName(self.facility))
    self:drawText(title, padX + 5, y, Colors.textHighlight.r, Colors.textHighlight.g, Colors.textHighlight.b, 1, UIFont.Large)
    y = y + 28

    -- Type and status row
    local typeText = self:getTypeText()
    self:drawText(typeText, padX + 5, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.9, UIFont.Small)

    -- Status LED and text (right side)
    local statusText, statusColor, ledColor = self:getStatusDisplay(self.status.status or "offline")
    local statusX = self.width - 200

    -- LED indicator (circle)
    self:drawLED(statusX, y + 2, 10, ledColor)
    self:drawText(statusText, statusX + 18, y, statusColor.r, statusColor.g, statusColor.b, 1, UIFont.Small)
    y = y + 22

    -- Health/Progress bar (inline layout: label, bar, percentage on same row)
    local health = self.status.health or 0
    local facilityStatus = self.status.status or "offline"

    if facilityStatus == "online" or facilityStatus == "starting" then
        -- Health label
        self:drawText(getEprText("UI_EPR_Panel_HealthLabel", "HEALTH:"), padX + 5, y + 2, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)
        -- Health bar (inline, after label)
        local barX = padX + 70
        local barWidth = self.width - barX - 80
        self:drawHealthBar(barX, y, barWidth, 16, health, 100)
        -- Health percentage (at end)
        local healthText = string.format("%d%%", math.floor(health))
        self:drawText(healthText, self.width - 60, y + 2, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 1, UIFont.Small)
    else
        -- Repair progress (inline layout)
        local progress = self:calculateOverallProgress()
        local progressColor = progress >= 100 and Colors.textSuccess or Colors.textWarning
        -- Progress label
        self:drawText(getEprText("UI_EPR_Panel_ProgressLabel", "PROGRESS:"), padX + 5, y + 2, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)
        -- Progress bar (inline, after label)
        local barX = padX + 80
        local barWidth = self.width - barX - 80
        self:drawASCIIProgressBar(barX, y, barWidth, progress, 100, progressColor)
        -- Progress percentage (at end)
        local progressText = string.format("%d%%", math.floor(progress))
        self:drawText(progressText, self.width - 60, y + 2, progressColor.r, progressColor.g, progressColor.b, 1, UIFont.Small)
    end

    return y + 25
end

-- ============================================
-- OVERVIEW TAB
-- ============================================

function EPR_FacilityPanelNew:renderOverviewTab(x, y, width, height)
    local halfWidth = math.floor((width - 15) / 2)
    local facilityStatus = self.status.status or "offline"
    local debugMode = EPR.IsDebugMode and EPR.IsDebugMode() or false

    -- Left column: Component LIST (vertical layout)
    local listHeight = height - 80
    self:drawSectionBox(x, y, halfWidth, listHeight, getEprText("UI_EPR_Panel_Components", "COMPONENTS"))
    self:renderComponentList(x + 10, y + 25, halfWidth - 20, listHeight - 40)

    -- Right column layout depends on facility status
    local rightX = x + halfWidth + 15
    local rightHeight = height - 80

    if facilityStatus == "ready" then
        -- When ready: Selected component (40%), Quick Stats (25%), Actions (35%)
        local detailHeight = math.floor(rightHeight * 0.40)
        local statsHeight = math.floor(rightHeight * 0.25)
        local actionsHeight = rightHeight - detailHeight - statsHeight - 30

        -- Selected component details
        local detailTitle = self.selectedComponent and "SELECTED: " .. string.upper(self:getComponentDisplayName(self.selectedComponent)) or "SELECT A COMPONENT"
        self:drawSectionBox(rightX, y, halfWidth, detailHeight, detailTitle)
        self:renderSelectedComponentDetails(rightX + 10, y + 25, halfWidth - 20, detailHeight - 40)

        -- Quick stats
        local statsY = y + detailHeight + 15
        self:drawSectionBox(rightX, statsY, halfWidth, statsHeight, getEprText("UI_EPR_Panel_QuickStats", "QUICK STATS"))
        self:renderQuickStats(rightX + 10, statsY + 25, halfWidth - 20)

        -- Actions section with START button
        local actionsY = statsY + statsHeight + 15
            self:drawSectionBox(rightX, actionsY, halfWidth, actionsHeight, getEprText("UI_EPR_Panel_Actions", "ACTIONS"))
        self:renderActions(rightX + 10, actionsY + 25, halfWidth - 20, actionsHeight - 40)
    else
        -- Normal mode: Selected component (55%), Quick Stats (45%)
        local detailHeight = math.floor(rightHeight * 0.55)
        local actionsHeight = debugMode and math.floor(rightHeight * 0.28) or 0
        local statsHeight = rightHeight - detailHeight - actionsHeight - 15

        -- Selected component details
        local detailTitle = self.selectedComponent and "SELECTED: " .. string.upper(self:getComponentDisplayName(self.selectedComponent)) or "SELECT A COMPONENT"
        self:drawSectionBox(rightX, y, halfWidth, detailHeight, detailTitle)
        self:renderSelectedComponentDetails(rightX + 10, y + 25, halfWidth - 20, detailHeight - 40)

        -- Quick stats
        local statsY = y + detailHeight + 15
        self:drawSectionBox(rightX, statsY, halfWidth, statsHeight, getEprText("UI_EPR_Panel_QuickStats", "QUICK STATS"))
        self:renderQuickStats(rightX + 10, statsY + 25, halfWidth - 20)

        if debugMode then
            local actionsY = statsY + statsHeight + 15
        self:drawSectionBox(rightX, actionsY, halfWidth, actionsHeight, getEprText("UI_EPR_Panel_Actions", "ACTIONS"))
            self:renderActions(rightX + 10, actionsY + 25, halfWidth - 20, actionsHeight - 40)
        end
    end

    -- Distance indicator at bottom (spanning full width)
    local distY = y + height - 70
    self:renderDistanceIndicator(x, distY, width)
end

function EPR_FacilityPanelNew:renderComponentList(x, y, width, height)
    if not self.status.components then
        self:drawText("[?] No component data", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Small)
        return
    end

    -- Vertical list layout
    local componentOrder = self.status.componentOrder or EPR.ComponentOrder or {"ControlPanel"}
    local rowHeight = 65  -- Increased for T/S/P indicators
    local gap = 6

    -- Calculate total content height
    local totalContentHeight = #componentOrder * (rowHeight + gap) - gap
    local maxScrollY = math.max(0, totalContentHeight - height)

    -- Clamp scroll position
    self.componentListScrollY = math.max(0, math.min(self.componentListScrollY or 0, maxScrollY))

    -- Store list bounds for scroll handling
    self.componentListBounds = {x = x, y = y, w = width, h = height, maxScroll = maxScrollY}

    -- Store clickable areas for component selection
    self.componentListAreas = {}

    -- Apply clipping (draw background to clip scrolled content)
    self:setStencilRect(x - 5, y - 5, width + 10, height + 10)

    for i, compType in ipairs(componentOrder) do
        local compState = self.status.components[compType]
        if compState then
            local rowY = y + (i - 1) * (rowHeight + gap) - self.componentListScrollY

            -- Only render if visible (within bounds)
            if rowY + rowHeight > y - rowHeight and rowY < y + height + rowHeight then
                -- Draw component row
                self:renderComponentRow(x, rowY, width, rowHeight, compType, compState, i)

                -- Store clickable area (with actual screen position)
                table.insert(self.componentListAreas, {
                    x = x, y = rowY, w = width, h = rowHeight, compType = compType
                })
            end
        end
    end

    self:clearStencilRect()

    -- Draw scroll bar if needed
    if maxScrollY > 0 then
        local scrollBarWidth = 8
        local scrollBarX = x + width - scrollBarWidth - 2
        local scrollBarHeight = height
        local thumbHeight = math.max(30, (height / totalContentHeight) * scrollBarHeight)
        local thumbY = y + (self.componentListScrollY / maxScrollY) * (scrollBarHeight - thumbHeight)

        -- Scroll track
        self:drawRect(scrollBarX, y, scrollBarWidth, scrollBarHeight, 0.3, 0.1, 0.2, 0.1)

        -- Scroll thumb
        self:drawRect(scrollBarX, thumbY, scrollBarWidth, thumbHeight, 0.8, Colors.border.r, Colors.border.g, Colors.border.b)
    end
end

-- Render a single component as a full-width row
function EPR_FacilityPanelNew:renderComponentRow(x, y, width, height, compType, compState, priority)
    local compDef = EPR.Components and EPR.Components[compType] or {}
    local compName = compDef.name or compType
    local isSelected = self.selectedComponent == compType
    local isComplete = compState.status == "functional" or compState.status == "repaired"

    -- Background based on status
    local bgColor = Colors.panelBg
    local borderColor = Colors.borderDim

    if isComplete then
        bgColor = {r = 0.02, g = 0.08, b = 0.03, a = 0.9}
        borderColor = Colors.ledOnline
    elseif compState.status == "repairing" then
        bgColor = {r = 0.08, g = 0.06, b = 0.02, a = 0.9}
        borderColor = Colors.ledRepairing
    elseif compState.status == "damaged" then
        bgColor = {r = 0.06, g = 0.02, b = 0.02, a = 0.9}
        borderColor = Colors.ledBroken
    end

    if isSelected then
        borderColor = Colors.borderHighlight
        bgColor = {r = bgColor.r * 1.5, g = bgColor.g * 1.5, b = bgColor.b * 1.5, a = 0.95}
    end

    -- Draw row background
    self:drawRect(x, y, width, height, bgColor.a, bgColor.r, bgColor.g, bgColor.b)
    self:drawRectBorder(x, y, width, height, borderColor.a, borderColor.r, borderColor.g, borderColor.b)

    -- LED indicator (left side)
    local ledColor = self:getLEDColorForStatus(compState.status)
    self:drawLED(x + 8, y + 8, 10, ledColor)

    -- Priority number
    self:drawText("[" .. priority .. "]", x + 25, y + 5, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.Small)

    -- Full component name (not truncated)
    self:drawText(compName, x + 55, y + 5, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 1, UIFont.Small)

    -- Status/Stage text
    local stageText = self:getComponentStageText(compState)
    self:drawText(stageText, x + 25, y + 24, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.9, UIFont.NewSmall)

    -- Tool/Part/Skill indicators (only if not complete)
    if not isComplete then
        local indicatorX = x + 25
        local indicatorY = y + 38

        -- Check tools
        local hasAllTools = true
        local currentStage = compState.currentStage or "Assessment"
        local stageDef = EPR.Repair and EPR.Repair.Stages and EPR.Repair.Stages[currentStage]
        if stageDef and stageDef.tools then
            for _, toolKey in ipairs(stageDef.tools) do
                if not self:playerHasTool(toolKey) then
                    hasAllTools = false
                    break
                end
            end
        end
        local toolColor = hasAllTools and Colors.textSuccess or Colors.textDanger
        self:drawText("T", indicatorX, indicatorY, toolColor.r, toolColor.g, toolColor.b, 0.9, UIFont.NewSmall)
        indicatorX = indicatorX + 15

        -- Check skills
        local hasAllSkills = true
        if compState.skillRequirements then
            local elecReq = compState.skillRequirements.Electricity or 0
            local weldReq = compState.skillRequirements.Welding or 0
            if self:getPlayerSkillLevel("Electricity") < elecReq or self:getPlayerSkillLevel("Welding") < weldReq then
                hasAllSkills = false
            end
        end
        local skillColor = hasAllSkills and Colors.textSuccess or Colors.textDanger
        self:drawText("S", indicatorX, indicatorY, skillColor.r, skillColor.g, skillColor.b, 0.9, UIFont.NewSmall)
        indicatorX = indicatorX + 15

        -- Check parts (only relevant for PartReplacement stage)
        if currentStage == "PartReplacement" then
            local hasAllParts = true
            if EPR.Repair and EPR.Repair.CheckStageParts then
                hasAllParts = EPR.Repair.CheckStageParts(self.player, compState, currentStage)
            end
            local partColor = hasAllParts and Colors.textSuccess or Colors.textDanger
            self:drawText("P", indicatorX, indicatorY, partColor.r, partColor.g, partColor.b, 0.9, UIFont.NewSmall)
        end

        -- Progress bar (if repairing)
        if compState.status == "repairing" or (compState.stageProgress and compState.stageProgress > 0) then
            local progress = compState.stageProgress or 0
            self:drawMiniProgressBar(indicatorX + 20, indicatorY, 100, 8, progress)
        end
    end

    -- Coordinates on the right
    local coordText = string.format("@%d,%d", compState.x or 0, compState.y or 0)
    local coordWidth = getTextManager():MeasureStringX(UIFont.NewSmall, coordText)
    self:drawText(coordText, x + width - coordWidth - 10, y + 5, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.6, UIFont.NewSmall)

    -- Click hint if selected
    if isSelected then
        self:drawText(">> SELECTED", x + width - 90, y + height - 18, Colors.textHighlight.r, Colors.textHighlight.g, Colors.textHighlight.b, 0.8, UIFont.NewSmall)
    end
end

-- Render details for the selected component
function EPR_FacilityPanelNew:renderSelectedComponentDetails(x, y, width, height)
    if not self.selectedComponent then
        -- No component selected - show instruction
        self:drawText("Click a component from the list", x, y + 20, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Medium)
        self:drawText("to view details", x, y + 45, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Medium)
        return
    end

    local compState = self.status.components and self.status.components[self.selectedComponent]
    if not compState then
        self:drawText("Component data not found", x, y, Colors.textDanger.r, Colors.textDanger.g, Colors.textDanger.b, 0.8, UIFont.Medium)
        return
    end

    local compDef = EPR.Components and EPR.Components[self.selectedComponent] or {}
    local lineY = y

    -- Status line
    local statusText = self:getComponentStageText(compState)
    local statusColor = (compState.status == "functional" or compState.status == "repaired") and Colors.textSuccess or
                       (compState.status == "repairing" and Colors.textWarning or Colors.textDanger)
    self:drawText("Status: " .. statusText, x, lineY, statusColor.r, statusColor.g, statusColor.b, 1, UIFont.Medium)
    lineY = lineY + 28

    -- Location
    local coordText = string.format("Location: %d, %d", compState.x or 0, compState.y or 0)
    self:drawText(coordText, x, lineY, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.9, UIFont.Small)
    lineY = lineY + 22

    -- If component is complete
    if compState.status == "functional" or compState.status == "repaired" then
        self:drawText("Fully repaired!", x, lineY, Colors.textSuccess.r, Colors.textSuccess.g, Colors.textSuccess.b, 1, UIFont.Medium)
        return
    end

    -- Current stage info
    local currentStage = compState.currentStage or "Assessment"
    self:drawText("Current Stage: " .. currentStage, x, lineY, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.9, UIFont.Small)
    lineY = lineY + 22

    -- Progress
    if compState.stageProgress then
        self:drawText("Progress: " .. math.floor(compState.stageProgress) .. "%", x, lineY, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.9, UIFont.Small)
        lineY = lineY + 22
    end

    -- Repair button
    lineY = lineY + 10
    local canRepair, reason = self:canRepairComponent(self.selectedComponent, compState)
    local btnText = compState.status == "repairing" and "[ CONTINUE ]" or "[ REPAIR ]"
    local btnColor = canRepair and Colors.textSuccess or Colors.textDanger

    self:drawActionButton(x, lineY, width - 20, 30, btnText, btnColor, function()
        if canRepair and EPR.Repair and EPR.Repair.StartComponentRepair then
            EPR.Repair.StartComponentRepair(self.player, self.facility, self.selectedComponent)
            self:onClose()
        else
            self:addAlert(reason or "Cannot repair", 3)
        end
    end)

    if not canRepair and reason then
        lineY = lineY + 35
        self:drawText(reason, x, lineY, Colors.textDanger.r, Colors.textDanger.g, Colors.textDanger.b, 0.8, UIFont.NewSmall)
    end
end

-- Helper to get component display name
function EPR_FacilityPanelNew:getComponentDisplayName(compType)
    local compDef = EPR.Components and EPR.Components[compType] or {}
    return compDef.name or compType
end

function EPR_FacilityPanelNew:renderComponentCell(x, y, width, height, compType, compState, priority)
    local compDef = EPR.Components and EPR.Components[compType] or {}
    local compName = compDef.name or compType

    -- Background based on status
    local bgColor = Colors.panelBg
    local borderColor = Colors.borderDim
    local isSelected = self.selectedComponent == compType

    if compState.status == "functional" or compState.status == "repaired" then
        bgColor = {r = 0.02, g = 0.08, b = 0.03, a = 0.9}
        borderColor = Colors.ledOnline
    elseif compState.status == "repairing" then
        bgColor = {r = 0.08, g = 0.06, b = 0.02, a = 0.9}
        borderColor = Colors.ledRepairing
    elseif compState.status == "damaged" then
        bgColor = {r = 0.06, g = 0.02, b = 0.02, a = 0.9}
        borderColor = Colors.ledBroken
    end

    if isSelected then
        borderColor = Colors.borderHighlight
    end

    -- Draw cell background
    self:drawRect(x, y, width, height, bgColor.a, bgColor.r, bgColor.g, bgColor.b)

    -- Draw cell border (rounded corners effect)
    self:drawRectBorder(x, y, width, height, borderColor.a, borderColor.r, borderColor.g, borderColor.b)

    -- Priority number
    self:drawText(tostring(priority), x + 5, y + 3, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.6, UIFont.NewSmall)

    -- LED indicator
    local ledColor = self:getLEDColorForStatus(compState.status)
    self:drawLED(x + width - 15, y + 5, 8, ledColor)

    -- Component name (truncated)
    local displayName = #compName > 12 and string.sub(compName, 1, 10) .. ".." or compName
    self:drawText(displayName, x + 5, y + 15, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 1, UIFont.NewSmall)

    -- Status/Stage
    local stageText = self:getComponentStageText(compState)
    self:drawText(stageText, x + 5, y + 30, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)

    -- Progress bar (if repairing)
    if compState.status == "repairing" then
        local progress = compState.stageProgress or 0
        self:drawMiniProgressBar(x + 5, y + 48, width - 10, 8, progress)
    end

    -- Damage indicator (visual degradation) - deterministic pattern based on position
    if compState.damageLevel and compState.status ~= "functional" and compState.status ~= "repaired" then
        local damageAlpha = compState.damageLevel == "heavy" and 0.3 or (compState.damageLevel == "medium" and 0.15 or 0.05)
        local damageCount = compState.damageLevel == "heavy" and 6 or (compState.damageLevel == "medium" and 4 or 2)

        -- Use deterministic pattern based on cell position
        for i = 1, damageCount do
            local dx = x + 5 + ((i * 17 + priority * 7) % (width - 10))
            local dy = y + 20 + ((i * 13 + priority * 11) % (height - 30))
            self:drawRect(dx, dy, 2, 2, damageAlpha, 0.5, 0.2, 0.1)
        end
    end
end

function EPR_FacilityPanelNew:drawFlowLine(x1, y1, x2, y2, status)
    local c = (status == "functional" or status == "repaired") and Colors.flowLineActive or Colors.flowLine
    self:drawRect(x1, y1 - 1, x2 - x1, 3, c.a, c.r, c.g, c.b)
end

function EPR_FacilityPanelNew:renderQuickStats(x, y, width)
    local lineHeight = 22

    -- Components status
    local total, repaired, repairing, damaged = self:countComponentStatus()
    self:drawText("Components:", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Small)
    local compText = string.format("%d/%d complete", repaired, total)
    self:drawText(compText, x + 100, y, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 1, UIFont.Small)
    y = y + lineHeight

    -- Damage level
    local damageLevel = self.status.initialDamageLevel or 0
    self:drawText("Damage Level:", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Small)
    local damageColor = damageLevel > 60 and Colors.textDanger or (damageLevel > 30 and Colors.textWarning or Colors.textSuccess)
    self:drawText(damageLevel .. "%", x + 100, y, damageColor.r, damageColor.g, damageColor.b, 1, UIFont.Small)
    y = y + lineHeight

    -- Time estimate
    local timeEstimate = self:calculateTimeEstimate()
    self:drawText("Est. Time:", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Small)
    self:drawText(timeEstimate, x + 100, y, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 1, UIFont.Small)
    y = y + lineHeight

    -- Zone coverage
    local zones = 0
    if self.facility.powersZones then zones = zones + #self.facility.powersZones end
    if self.facility.watersZones then zones = zones + #self.facility.watersZones end
    self:drawText("Zones:", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Small)
    self:drawText(zones .. " affected", x + 100, y, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 1, UIFont.Small)
    y = y + lineHeight

    -- Fuel (if applicable)
    if self.status.fuelLevel ~= nil then
        self:drawText("Fuel:", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Small)
        local fuelColor = self.status.fuelLevel > 50 and Colors.textSuccess or (self.status.fuelLevel > 20 and Colors.textWarning or Colors.textDanger)
        self:drawFuelGauge(x + 100, y, 100, 14, self.status.fuelLevel)
    end
end

function EPR_FacilityPanelNew:renderActions(x, y, width, height)
    local lineHeight = 40
    local facilityStatus = self.status.status or "offline"

    -- Debug mode check
    local debugMode = EPR.IsDebugMode and EPR.IsDebugMode() or false

    -- Action buttons based on status
    if facilityStatus == "ready" then
        -- Start facility button
        self:drawActionButton(x, y, width, 35, "[ START FACILITY ]", Colors.textWarning, function()
            if EPR.Repair and EPR.Repair.StartFacilityStartup then
                EPR.Repair.StartFacilityStartup(self.player, self.facility, self.status)
                self:onClose()
            end
        end)
        y = y + lineHeight

        self:drawText("WARNING: 5-min defense phase!", x, y, Colors.textDanger.r, Colors.textDanger.g, Colors.textDanger.b, 0.8, UIFont.NewSmall)
    elseif facilityStatus == "online" then
        -- Maintenance button
        self:drawActionButton(x, y, width, 35, "[ PERFORM MAINTENANCE ]", Colors.textSuccess, function()
            if EPR.Repair and EPR.Repair.StartMaintenance then
                EPR.Repair.StartMaintenance(self.player, self.facility)
                self:onClose()
            end
        end)
    else
        -- Info text
        self:drawText("Select component to repair", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Small)
        y = y + 20
        self:drawText("Click grid or use Repairs tab", x, y, Colors.textMuted.r, Colors.textMuted.g, Colors.textMuted.b, 0.7, UIFont.NewSmall)
    end

    -- Debug mode: Always show debug buttons when enabled
    if debugMode then
        y = y + lineHeight + 10

        -- Debug separator
        self:drawRect(x, y, width, 1, 0.5, 1.0, 0.5, 0.2)
        y = y + 5
        self:drawText("[DEBUG MODE]", x, y, 1.0, 0.5, 0.0, 0.8, UIFont.NewSmall)
        y = y + 18

        if facilityStatus == "online" then
            -- Facility is online - show deactivate option
            self:drawActionButton(x, y, width, 35, "[ DEBUG: DEACTIVATE FACILITY ]", {r = 1.0, g = 0.2, b = 0.2, a = 1.0}, function()
                self:debugDeactivateFacility()
            end)
        else
            -- Facility is not online - show repair and activate options
            -- Instant repair all button
            self:drawActionButton(x, y, width, 35, "[ DEBUG: INSTANT REPAIR ALL ]", {r = 1.0, g = 0.5, b = 0.0, a = 1.0}, function()
                self:debugInstantRepairAll()
            end)
            y = y + lineHeight

            -- Instant activate button
            self:drawActionButton(x, y, width, 35, "[ DEBUG: ACTIVATE NOW ]", {r = 1.0, g = 0.3, b = 0.0, a = 1.0}, function()
                self:debugActivateFacility()
            end)
        end
    end
end

-- Debug: Instantly repair all components
function EPR_FacilityPanelNew:debugInstantRepairAll()
    if not self.facility or not self.status then return end

    print("[EPR DEBUG] Instant repairing all components for: " .. self.facility.name)

    local facilityId = self.facility.id
    local facilityType = self.facility.type

    -- In MP, send command to server
    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        if sendClientCommand then
            local player = getPlayer()
            if player then
                sendClientCommand(player, "EPR", "DebugRepairAll", { facilityId = facilityId })
                print("[EPR DEBUG] Sent DebugRepairAll to server")
            end
        end
        return
    end

    -- SP: Do it locally
    -- Mark all components as repaired
    if self.status.components then
        for compType, compState in pairs(self.status.components) do
            compState.status = "repaired"
            compState.progress = 100
            compState.currentStage = nil
            compState.stageProgress = nil
            print("[EPR DEBUG] Repaired component: " .. compType)
        end
    end

    -- Update facility status
    self.status.status = "ready"
    self.status.health = 100

    -- Save to global state
    if facilityType == "power" or facilityType == "combined" then
        EPR.Substations = EPR.Substations or {}
        EPR.Substations[facilityId] = self.status
    end
    if facilityType == "water" or facilityType == "combined" then
        EPR.WaterPlants = EPR.WaterPlants or {}
        EPR.WaterPlants[facilityId] = self.status
    end

    -- Save data
    if EPR.SaveData then
        EPR.SaveData()
    end

    print("[EPR DEBUG] All components repaired. Facility ready for activation.")
end

-- Debug: Instantly activate facility
function EPR_FacilityPanelNew:debugActivateFacility()
    if not self.facility or not self.status then return end

    print("[EPR DEBUG] Instantly activating facility: " .. self.facility.name)

    local facilityId = self.facility.id

    -- In MP, send command to server
    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        if sendClientCommand then
            local player = getPlayer()
            if player then
                sendClientCommand(player, "EPR", "DebugActivate", { facilityId = facilityId })
                print("[EPR DEBUG] Sent DebugActivate to server")
            end
        end
        self:onClose()
        return
    end

    -- SP: Do it locally
    -- First ensure all components are repaired
    self:debugInstantRepairAll()

    -- Bring facility online
    if EPR.Repair and EPR.Repair.BringFacilityOnline then
        EPR.Repair.BringFacilityOnline(self.player, self.facility, self.status)
    else
        -- Manual activation fallback
        self.status.status = "online"
        self.status.health = 100

        -- Save facility state
        if EPR.Substations then
            EPR.Substations[self.facility.id] = self.status
        end

        -- Notify PowerController to check network status
        if EPR.PowerController and EPR.PowerController.OnFacilityOnline then
            EPR.PowerController.OnFacilityOnline(self.facility.id)
        end

        -- Save
        if EPR.SaveData then
            saveIfAuthoritative()
        end
    end

    print("[EPR DEBUG] Facility activated!")
    self:onClose()
end

-- Debug: Instantly deactivate facility (for testing)
function EPR_FacilityPanelNew:debugDeactivateFacility()
    if not self.facility or not self.status then return end

    print("[EPR DEBUG] Deactivating facility: " .. self.facility.name)

    local facilityId = self.facility.id
    local facilityType = self.facility.type

    -- Set facility to offline
    self.status.status = "offline"
    self.status.health = 0

    -- Reset all components to damaged
    if self.status.components then
        for compType, compState in pairs(self.status.components) do
            compState.status = "damaged"
            compState.progress = 0
            compState.stagesCompleted = {}
            compState.currentStage = "Assessment"
            compState.stageProgress = 0
            print("[EPR DEBUG] Reset component: " .. compType)
        end
    end

    -- Save to global state
    if facilityType == "power" or facilityType == "combined" then
        EPR.Substations = EPR.Substations or {}
        EPR.Substations[facilityId] = self.status
    end
    if facilityType == "water" or facilityType == "combined" then
        EPR.WaterPlants = EPR.WaterPlants or {}
        EPR.WaterPlants[facilityId] = self.status
    end

    -- Notify PowerController to check network status
    if EPR.PowerController and EPR.PowerController.OnFacilityOffline then
        EPR.PowerController.OnFacilityOffline(facilityId)
    end

    -- Save data
    if EPR.SaveData then
        saveIfAuthoritative()
    end

    -- In MP, notify server
    if EPR.Client and EPR.Client.IsMultiplayer and EPR.Client.IsMultiplayer() then
        if sendClientCommand then
            local player = getPlayer()
            if player then
                sendClientCommand(player, "EPR", "DebugDeactivate", { facilityId = facilityId })
            end
        end
    end

    print("[EPR DEBUG] Facility deactivated!")
end

function EPR_FacilityPanelNew:renderDistanceIndicator(x, y, width)
    self:drawText(getEprText("UI_EPR_Panel_DistanceToComponents", "DISTANCE TO COMPONENTS:"), x + 5, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
    y = y + 16

    local componentOrder = self.status.componentOrder or EPR.ComponentOrder or {"ControlPanel"}
    local px, py = self.player:getX(), self.player:getY()
    local distX = x + 5

    for _, compType in ipairs(componentOrder) do
        local compState = self.status.components and self.status.components[compType]
        if compState and compState.x and compState.y then
            local dist = math.floor(math.sqrt((compState.x - px)^2 + (compState.y - py)^2))
            local compDef = EPR.Components and EPR.Components[compType] or {}
            local fullName = compDef.name or compType

            local distColor = dist <= 10 and Colors.textSuccess or (dist <= 30 and Colors.textWarning or Colors.textDim)
            local text = fullName .. ": " .. dist .. "m"
            local textWidth = getTextManager():MeasureStringX(UIFont.NewSmall, text) + 15

            -- Wrap to next line if needed
            if distX + textWidth > x + width - 10 then
                distX = x + 5
                y = y + 14
            end

            self:drawText(text, distX, y, distColor.r, distColor.g, distColor.b, 0.8, UIFont.NewSmall)
            distX = distX + textWidth
        end
    end
end

-- ============================================
-- REPAIRS TAB
-- ============================================

function EPR_FacilityPanelNew:renderRepairsTab(x, y, width, height)
    local componentOrder = self.status.componentOrder or EPR.ComponentOrder or {"ControlPanel"}
    local padX = 10

    -- Title
    self:drawText("COMPONENT REPAIR DETAILS", x + padX, y, Colors.textHighlight.r, Colors.textHighlight.g, Colors.textHighlight.b, 1, UIFont.Medium)
    y = y + 30

    -- Calculate entry height based on content (larger entries with more info)
    local entryHeight = 210  -- Increased to fit all content + button

    -- Scroll support for repairs tab
    if not self.repairsTabScrollY then self.repairsTabScrollY = 0 end
    local totalContentHeight = #componentOrder * (entryHeight + 10)
    local maxScrollY = math.max(0, totalContentHeight - height + 30)
    self.repairsTabScrollY = math.max(0, math.min(self.repairsTabScrollY, maxScrollY))

    -- Store bounds for scroll handling
    self.repairsTabBounds = {x = x, y = y, w = width, h = height - 30, maxScroll = maxScrollY}

    -- Set clipping
    self:setStencilRect(x, y, width, height - 30)

    for i, compType in ipairs(componentOrder) do
        local compState = self.status.components and self.status.components[compType]
        if compState then
            local entryY = y + (i - 1) * (entryHeight + 10) - self.repairsTabScrollY

            -- Only render if visible
            if entryY + entryHeight > y - entryHeight and entryY < y + height then
                self:renderRepairEntryDetailed(x + padX, entryY, width - padX * 2, entryHeight, compType, compState, i)
            end
        end
    end

    self:clearStencilRect()

    -- Draw scroll bar if needed
    if maxScrollY > 0 then
        local scrollBarWidth = 8
        local scrollBarX = x + width - scrollBarWidth - 5
        local scrollBarHeight = height - 30
        local thumbHeight = math.max(30, (scrollBarHeight / totalContentHeight) * scrollBarHeight)
        local thumbY = y + (self.repairsTabScrollY / maxScrollY) * (scrollBarHeight - thumbHeight)

        self:drawRect(scrollBarX, y, scrollBarWidth, scrollBarHeight, 0.3, 0.1, 0.2, 0.1)
        self:drawRect(scrollBarX, thumbY, scrollBarWidth, thumbHeight, 0.8, Colors.border.r, Colors.border.g, Colors.border.b)
    end
end

function EPR_FacilityPanelNew:renderRepairEntryDetailed(x, y, width, height, compType, compState, priority)
    local compDef = EPR.Components and EPR.Components[compType] or {}
    local compName = compDef.name or compType
    local isComplete = compState.status == "functional" or compState.status == "repaired"

    -- Entry box background
    local bgColor = Colors.panelBg
    if isComplete then
        bgColor = {r = 0.02, g = 0.06, b = 0.02, a = 0.7}
    elseif compState.status == "repairing" then
        bgColor = {r = 0.06, g = 0.05, b = 0.01, a = 0.7}
    end

    self:drawRect(x, y, width, height, bgColor.a, bgColor.r, bgColor.g, bgColor.b)
    self:drawRectBorder(x, y, width, height, Colors.borderDim.a, Colors.borderDim.r, Colors.borderDim.g, Colors.borderDim.b)

    local lineY = y + 8
    local leftCol = x + 10
    local rightCol = x + width / 2

    -- Header row: LED, Priority, Name, Coordinates
    local ledColor = self:getLEDColorForStatus(compState.status)
    self:drawLED(leftCol, lineY, 12, ledColor)
    self:drawText("[" .. priority .. "] " .. compName, leftCol + 20, lineY - 2, Colors.textHighlight.r, Colors.textHighlight.g, Colors.textHighlight.b, 1, UIFont.Medium)

    local coordText = string.format("Location: %d, %d", compState.x or 0, compState.y or 0)
    self:drawText(coordText, rightCol + 50, lineY, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.Small)

    -- Distance
    local px, py = self.player:getX(), self.player:getY()
    local dist = math.floor(math.sqrt((compState.x - px)^2 + (compState.y - py)^2))
    local distColor = dist <= 10 and Colors.textSuccess or (dist <= 30 and Colors.textWarning or Colors.textDim)
    self:drawText("(" .. dist .. "m away)", rightCol + 180, lineY, distColor.r, distColor.g, distColor.b, 0.8, UIFont.Small)

    lineY = lineY + 22

    -- Status row
    local statusText = self:getComponentStageText(compState)
    local statusColor = isComplete and Colors.textSuccess or (compState.status == "repairing" and Colors.textWarning or Colors.textDanger)
    self:drawText("Status: " .. statusText, leftCol, lineY, statusColor.r, statusColor.g, statusColor.b, 1, UIFont.Small)

    if not isComplete then
        -- Time estimate
        local timeText = self:getStageTimeEstimate(compState)
        if timeText ~= "" then
            self:drawText("Est. Time: " .. timeText, rightCol, lineY, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.9, UIFont.Small)
        end
    end

    lineY = lineY + 20

    if isComplete then
        self:drawText("All repair stages completed successfully.", leftCol, lineY, Colors.textSuccess.r, Colors.textSuccess.g, Colors.textSuccess.b, 0.9, UIFont.Small)
        return
    end

    -- Progress bar
    local progress = compState.stageProgress or 0
    self:drawText("Progress:", leftCol, lineY, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)
    self:drawMiniProgressBar(leftCol + 60, lineY + 2, 200, 10, progress)
    self:drawText(math.floor(progress) .. "%", leftCol + 270, lineY, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.9, UIFont.NewSmall)

    lineY = lineY + 20

    -- Stage info
    local currentStage = compState.currentStage or "Assessment"
    local stageDef = EPR.Repair and EPR.Repair.Stages and EPR.Repair.Stages[currentStage]
    local stageDisplayName = stageDef and stageDef.name or currentStage

    self:drawText("Current Stage: " .. stageDisplayName, leftCol, lineY, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.9, UIFont.Small)
    lineY = lineY + 18

    -- TOOLS section
    self:drawText("TOOLS:", leftCol, lineY, Colors.textHighlight.r, Colors.textHighlight.g, Colors.textHighlight.b, 0.9, UIFont.Small)
    local toolX = leftCol + 50
    if stageDef and stageDef.tools and #stageDef.tools > 0 then
        for _, toolKey in ipairs(stageDef.tools) do
            local toolDef = EPR.Repair and EPR.Repair.Tools and EPR.Repair.Tools[toolKey]
            local hasTool = self:playerHasTool(toolKey)
            local color = hasTool and Colors.textSuccess or Colors.textDanger
            local toolName = toolDef and toolDef.displayName or toolKey
            local icon = hasTool and "[OK]" or "[X]"
            self:drawText(icon .. " " .. toolName, toolX, lineY, color.r, color.g, color.b, 0.9, UIFont.NewSmall)
            toolX = toolX + getTextManager():MeasureStringX(UIFont.NewSmall, icon .. " " .. toolName) + 15
        end
    else
        self:drawText("None required", toolX, lineY, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
    end
    lineY = lineY + 18

    -- PARTS section
    self:drawText("PARTS:", leftCol, lineY, Colors.textHighlight.r, Colors.textHighlight.g, Colors.textHighlight.b, 0.9, UIFont.Small)
    local partX = leftCol + 50
    if currentStage == "PartReplacement" and compState.partsNeeded and #compState.partsNeeded > 0 then
        local partCounts = {}
        for _, part in ipairs(compState.partsNeeded) do
            partCounts[part] = (partCounts[part] or 0) + 1
        end
        local partsInstalled = compState.partsInstalled or {}

        for partKey, needed in pairs(partCounts) do
            local installed = partsInstalled[partKey] or 0
            local remaining = needed - installed
            if remaining > 0 then
                local inInventory = 0
                if EPR.Repair and EPR.Repair.CountPart then
                    inInventory = EPR.Repair.CountPart(self.player, partKey)
                end
                local partName = EPR.Repair and EPR.Repair.GetPartDisplayName and EPR.Repair.GetPartDisplayName(partKey) or partKey
                local hasEnough = inInventory >= remaining
                local color = hasEnough and Colors.textSuccess or Colors.textDanger
                local icon = hasEnough and "[OK]" or "[X]"
                local countText = hasEnough and ("x" .. remaining) or ("(" .. inInventory .. "/" .. remaining .. ")")
                local text = icon .. " " .. partName .. " " .. countText
                self:drawText(text, partX, lineY, color.r, color.g, color.b, 0.9, UIFont.NewSmall)
                partX = partX + getTextManager():MeasureStringX(UIFont.NewSmall, text) + 15
            end
        end
    else
        local msg = currentStage ~= "PartReplacement" and "Needed at Part Replacement stage" or "None required"
        self:drawText(msg, partX, lineY, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
    end
    lineY = lineY + 18

    -- SKILLS section
    self:drawText("SKILLS:", leftCol, lineY, Colors.textHighlight.r, Colors.textHighlight.g, Colors.textHighlight.b, 0.9, UIFont.Small)
    local skillX = leftCol + 50
    if compState.skillRequirements then
        local elecReq = compState.skillRequirements.Electricity or 0
        local weldReq = compState.skillRequirements.Welding or 0
        local elecLevel = self:getPlayerSkillLevel("Electricity")
        local weldLevel = self:getPlayerSkillLevel("Welding")

        local elecOk = elecLevel >= elecReq
        local weldOk = weldLevel >= weldReq
        local elecColor = elecOk and Colors.textSuccess or Colors.textDanger
        local weldColor = weldOk and Colors.textSuccess or Colors.textDanger

        self:drawText((elecOk and "[OK]" or "[X]") .. " Elec " .. elecLevel .. "/" .. elecReq, skillX, lineY, elecColor.r, elecColor.g, elecColor.b, 0.9, UIFont.NewSmall)
        skillX = skillX + 100
        self:drawText((weldOk and "[OK]" or "[X]") .. " Weld " .. weldLevel .. "/" .. weldReq, skillX, lineY, weldColor.r, weldColor.g, weldColor.b, 0.9, UIFont.NewSmall)
    else
        self:drawText("None required", skillX, lineY, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
    end

    -- Repair button (bottom right)
    local btnText = compState.status == "repairing" and "[ CONTINUE ]" or "[ REPAIR ]"
    local btnWidth = 100
    local btnHeight = 25
    local btnX = x + width - btnWidth - 15
    local btnY = y + height - btnHeight - 10

    local canRepair, reason = self:canRepairComponent(compType, compState)
    local btnColor = canRepair and Colors.textSuccess or Colors.textDanger

    self:drawActionButton(btnX, btnY, btnWidth, btnHeight, btnText, btnColor, function()
        if canRepair and EPR.Repair and EPR.Repair.StartComponentRepair then
            EPR.Repair.StartComponentRepair(self.player, self.facility, compType)
            self:onClose()
        else
            self:addAlert(reason or "Cannot repair", 3)
        end
    end)

    if not canRepair and reason then
        local reasonWidth = getTextManager():MeasureStringX(UIFont.NewSmall, reason)
        self:drawText(reason, btnX + (btnWidth - reasonWidth) / 2, btnY - 15, Colors.textDanger.r, Colors.textDanger.g, Colors.textDanger.b, 0.8, UIFont.NewSmall)
    end
end

function EPR_FacilityPanelNew:renderInlineRequirements(x, y, width, compState)
    if compState.status == "functional" or compState.status == "repaired" then
        self:drawText("[COMPLETE]", x, y, Colors.textSuccess.r, Colors.textSuccess.g, Colors.textSuccess.b, 0.8, UIFont.NewSmall)
        return
    end

    local currentStage = compState.currentStage or "Assessment"
    local stageDef = EPR.Repair and EPR.Repair.Stages and EPR.Repair.Stages[currentStage]
    local playerInv = self.player and self.player:getInventory()

    local reqX = x

    -- Tools
    if stageDef and stageDef.tools and #stageDef.tools > 0 then
        for _, toolKey in ipairs(stageDef.tools) do
            local toolDef = EPR.Repair and EPR.Repair.Tools and EPR.Repair.Tools[toolKey]
            local hasTool = self:playerHasTool(toolKey)
            local color = hasTool and Colors.textSuccess or Colors.textDanger
            local icon = hasTool and "[OK]" or "[X]"
            local name = toolDef and string.sub(toolDef.displayName or toolKey, 1, 6) or string.sub(toolKey, 1, 6)

            local text = icon .. name
            self:drawText(text, reqX, y, color.r, color.g, color.b, 0.8, UIFont.NewSmall)
            reqX = reqX + getTextManager():MeasureStringX(UIFont.NewSmall, text) + 8

            if reqX > x + width - 50 then break end
        end
    end

    -- Skills
    if compState.skillRequirements then
        local elecReq = compState.skillRequirements.Electricity or 0
        local weldReq = compState.skillRequirements.Welding or 0
        local elecLevel = self:getPlayerSkillLevel("Electricity")
        local weldLevel = self:getPlayerSkillLevel("Welding")

        local elecColor = elecLevel >= elecReq and Colors.textSuccess or Colors.textDanger
        local weldColor = weldLevel >= weldReq and Colors.textSuccess or Colors.textDanger

        self:drawText("E:" .. elecLevel .. "/" .. elecReq, reqX, y, elecColor.r, elecColor.g, elecColor.b, 0.7, UIFont.NewSmall)
        reqX = reqX + 45
        self:drawText("W:" .. weldLevel .. "/" .. weldReq, reqX, y, weldColor.r, weldColor.g, weldColor.b, 0.7, UIFont.NewSmall)
    end
end

-- ============================================
-- STATUS TAB
-- ============================================

function EPR_FacilityPanelNew:renderStatusTab(x, y, width, height)
    local halfWidth = math.floor((width - 15) / 2)
    local sectionHeight = math.floor((height - 30) / 2)

    -- Technical details (left top)
    self:drawSectionBox(x, y, halfWidth, sectionHeight, getEprText("UI_EPR_Panel_TechnicalDetails", "TECHNICAL DETAILS"))
    self:renderTechnicalDetails(x + 10, y + 25, halfWidth - 20)

    -- Zone coverage (right top)
    self:drawSectionBox(x + halfWidth + 15, y, halfWidth, sectionHeight, getEprText("UI_EPR_Panel_ZoneCoverage", "ZONE COVERAGE"))
    self:renderZoneCoverage(x + halfWidth + 25, y + 25, halfWidth - 20)

    -- Maintenance history (left bottom)
    local bottomY = y + sectionHeight + 15
    self:drawSectionBox(x, bottomY, halfWidth, sectionHeight, getEprText("UI_EPR_Panel_Maintenance", "MAINTENANCE"))
    self:renderMaintenanceInfo(x + 10, bottomY + 25, halfWidth - 20)

    -- Repair quality (right bottom)
    self:drawSectionBox(x + halfWidth + 15, bottomY, halfWidth, sectionHeight, getEprText("UI_EPR_Panel_RepairQuality", "REPAIR QUALITY"))
    self:renderRepairQuality(x + halfWidth + 25, bottomY + 25, halfWidth - 20)
end

function EPR_FacilityPanelNew:renderTechnicalDetails(x, y, width)
    local lineHeight = 18

    -- Facility ID
    self:drawText("ID: " .. (self.facility.id or "N/A"), x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)
    y = y + lineHeight

    -- Type
    self:drawText("Type: " .. (self.facility.type or "unknown"), x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)
    y = y + lineHeight

    -- Initial damage
    local damageLevel = self.status.initialDamageLevel or 0
    local damageColor = damageLevel > 60 and Colors.textDanger or (damageLevel > 30 and Colors.textWarning or Colors.textSuccess)
    self:drawText("Initial Damage: " .. damageLevel .. "%", x, y, damageColor.r, damageColor.g, damageColor.b, 0.9, UIFont.NewSmall)
    y = y + lineHeight

    -- Components count
    local total, repaired, _, _ = self:countComponentStatus()
    self:drawText("Components: " .. repaired .. "/" .. total, x, y, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.9, UIFont.NewSmall)
    y = y + lineHeight

    -- Phase
    local phase = self.status.phase or 1
    local phaseText = phase == 1 and "Control Panel" or (phase == 2 and "Field Components" or "Startup")
    self:drawText("Phase: " .. phaseText, x, y, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.9, UIFont.NewSmall)
end

function EPR_FacilityPanelNew:renderZoneCoverage(x, y, width)
    local lineHeight = 18

    if self.facility.powersZones and #self.facility.powersZones > 0 then
        self:drawText("POWER ZONES:", x, y, Colors.textWarning.r, Colors.textWarning.g, Colors.textWarning.b, 0.9, UIFont.NewSmall)
        y = y + lineHeight
        for _, zone in ipairs(self.facility.powersZones) do
            local isPowered = EPR.IsZonePowered and EPR.IsZonePowered(zone)
            local color = isPowered and Colors.textSuccess or Colors.textDim
            self:drawText("  " .. getZoneDisplayName(zone), x, y, color.r, color.g, color.b, 0.8, UIFont.NewSmall)
            y = y + lineHeight - 4
        end
        y = y + 5
    end

    if self.facility.watersZones and #self.facility.watersZones > 0 then
        self:drawText("WATER ZONES:", x, y, Colors.ledReady.r, Colors.ledReady.g, Colors.ledReady.b, 0.9, UIFont.NewSmall)
        y = y + lineHeight
        for _, zone in ipairs(self.facility.watersZones) do
            local isWatered = EPR.IsZoneWatered and EPR.IsZoneWatered(zone)
            local color = isWatered and Colors.textSuccess or Colors.textDim
            self:drawText("  " .. getZoneDisplayName(zone), x, y, color.r, color.g, color.b, 0.8, UIFont.NewSmall)
            y = y + lineHeight - 4
        end
    end

    if (not self.facility.powersZones or #self.facility.powersZones == 0) and
       (not self.facility.watersZones or #self.facility.watersZones == 0) then
        self:drawText("No zones configured", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
    end
end

function EPR_FacilityPanelNew:renderMaintenanceInfo(x, y, width)
    local lineHeight = 18
    local facilityStatus = self.status.status or "offline"

    if facilityStatus == "online" then
        -- Last maintenance
        local lastMaint = self.status.lastMaintenance or 0
        local currentHour = getGameTime():getWorldAgeHours()
        local hoursSince = math.floor(currentHour - lastMaint)

        self:drawText("Last Maintenance:", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)
        y = y + lineHeight

        local timeText = hoursSince < 24 and (hoursSince .. " hours ago") or (math.floor(hoursSince / 24) .. " days ago")
        self:drawText("  " .. timeText, x, y, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.9, UIFont.NewSmall)
        y = y + lineHeight + 5

        -- Health trend
        local health = self.status.health or 100
        local healthColor = health > 70 and Colors.textSuccess or (health > 40 and Colors.textWarning or Colors.textDanger)
        self:drawText("Health: " .. math.floor(health) .. "%", x, y, healthColor.r, healthColor.g, healthColor.b, 0.9, UIFont.NewSmall)
        y = y + lineHeight

        -- Degradation rate
        local degradeRate = EPR.Config and EPR.Config.BaseDegradationPerDay or 1.0
        self:drawText("Degradation: " .. degradeRate .. "%/day", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)
    else
        self:drawText("Facility offline", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
        y = y + lineHeight
        self:drawText("Maintenance available", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
        y = y + lineHeight
        self:drawText("when facility is online", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
    end
end

function EPR_FacilityPanelNew:renderRepairQuality(x, y, width)
    local lineHeight = 18
    local facilityStatus = self.status.status or "offline"

    if facilityStatus == "online" then
        local quality = self.status.repairQuality or 1.0
        local qualityPct = math.floor(quality * 100)
        local qualityColor = qualityPct >= 100 and Colors.textSuccess or (qualityPct >= 80 and Colors.textWarning or Colors.textDanger)

        self:drawText("Repair Quality:", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.8, UIFont.NewSmall)
        y = y + lineHeight

        self:drawText("  " .. qualityPct .. "%", x, y, qualityColor.r, qualityColor.g, qualityColor.b, 1, UIFont.Small)
        y = y + lineHeight + 5

        -- Quality effects
        local effectText = qualityPct >= 100 and "Optimal performance" or
                          (qualityPct >= 80 and "Minor efficiency loss" or "Significant issues")
        self:drawText(effectText, x, y, qualityColor.r, qualityColor.g, qualityColor.b, 0.8, UIFont.NewSmall)
    else
        self:drawText("Quality determined", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
        y = y + lineHeight
        self:drawText("after startup based on", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
        y = y + lineHeight
        self:drawText("repair skill levels", x, y, Colors.textDim.r, Colors.textDim.g, Colors.textDim.b, 0.7, UIFont.NewSmall)
    end
end

-- ============================================
-- ALERTS & WARNINGS
-- ============================================

function EPR_FacilityPanelNew:renderAlerts()
    if #self.alerts == 0 then return end

    local alertY = self.height - 80
    for i, alert in ipairs(self.alerts) do
        local alpha = math.min(1, (alert.lifetime or 3) / 3)
        self:drawRect(20, alertY, self.width - 40, 25, 0.9 * alpha, 0.1, 0.02, 0.02)
        self:drawRectBorder(20, alertY, self.width - 40, 25, alpha, 1, 0.2, 0.2)
        self:drawText(alert.message, 30, alertY + 5, 1, 0.9, 0.9, alpha, UIFont.Small)
        alertY = alertY - 30
    end
end

function EPR_FacilityPanelNew:addAlert(message, duration)
    table.insert(self.alerts, {message = message, lifetime = duration or 3})
    -- Play alert sound
    -- getSoundManager():PlayWorldSound("UIAlert", false, nil, 0, 0, 0, 0, 0.5)
end

function EPR_FacilityPanelNew:renderStartupWarning()
    -- Full width warning banner
    local bannerHeight = 60
    local bannerY = (self.height - bannerHeight) / 2

    -- Flashing background
    local flashAlpha = self.blinkOn and 0.95 or 0.8
    self:drawRect(0, bannerY, self.width, bannerHeight, flashAlpha, 0.15, 0.02, 0.02)
    self:drawRectBorder(0, bannerY, self.width, bannerHeight, 1, 1, 0.2, 0.2)

    -- Warning text
    local warningText = "!!! STARTUP IN PROGRESS - DEFEND THE AREA !!!"
    local textWidth = getTextManager():MeasureStringX(UIFont.Large, warningText)
    self:drawText(warningText, (self.width - textWidth) / 2, bannerY + 8, 1, 0.9, 0.1, 1, UIFont.Large)

    -- Timer (if available)
    -- TODO: Get actual countdown from repair action
    local timerText = "Stay alert for zombie attacks!"
    local timerWidth = getTextManager():MeasureStringX(UIFont.Medium, timerText)
    self:drawText(timerText, (self.width - timerWidth) / 2, bannerY + 35, 1, 0.8, 0.0, 1, UIFont.Medium)
end

-- ============================================
-- DRAWING HELPERS
-- ============================================

function EPR_FacilityPanelNew:drawLED(x, y, size, color)
    -- Outer glow
    self:drawRect(x - 2, y - 2, size + 4, size + 4, 0.3, color.r, color.g, color.b)
    -- Main LED
    self:drawRect(x, y, size, size, color.a, color.r, color.g, color.b)
    -- Highlight (top-left)
    self:drawRect(x + 1, y + 1, size / 3, size / 3, 0.5, 1, 1, 1)
end

function EPR_FacilityPanelNew:drawHealthBar(x, y, width, height, current, max)
    local ratio = current / max
    local fillWidth = math.floor(width * ratio)

    -- Background
    self:drawRect(x, y, width, height, 0.8, 0.1, 0.1, 0.1)

    -- Fill with gradient color based on health
    local color = ratio > 0.7 and Colors.healthHigh or (ratio > 0.4 and Colors.healthMid or Colors.healthLow)
    self:drawRect(x, y, fillWidth, height, color.a, color.r, color.g, color.b)

    -- Border
    self:drawRectBorder(x, y, width, height, 0.8, Colors.border.r, Colors.border.g, Colors.border.b)
end

function EPR_FacilityPanelNew:drawASCIIProgressBar(x, y, width, current, max, color)
    local barChars = 30
    local ratio = current / max
    local filled = math.floor(barChars * ratio)
    local empty = barChars - filled

    local bar = "[" .. string.rep("#", filled) .. string.rep(".", empty) .. "]"
    self:drawText(bar, x, y, color.r, color.g, color.b, color.a, UIFont.Small)
end

function EPR_FacilityPanelNew:drawMiniProgressBar(x, y, width, height, progress)
    local ratio = progress / 100
    local fillWidth = math.floor(width * ratio)

    -- Background
    self:drawRect(x, y, width, height, 0.6, 0.05, 0.05, 0.05)

    -- Fill
    local color = progress >= 100 and Colors.textSuccess or Colors.textWarning
    self:drawRect(x, y, fillWidth, height, 0.9, color.r, color.g, color.b)

    -- Border
    self:drawRectBorder(x, y, width, height, 0.5, Colors.borderDim.r, Colors.borderDim.g, Colors.borderDim.b)
end

function EPR_FacilityPanelNew:drawFuelGauge(x, y, width, height, level)
    local ratio = level / 100
    local fillWidth = math.floor(width * ratio)

    -- Background
    self:drawRect(x, y, width, height, 0.7, 0.1, 0.05, 0.0)

    -- Fill (amber/orange for fuel)
    local color = level > 50 and {r=0.2, g=0.8, b=0.3} or (level > 20 and {r=1, g=0.7, b=0} or {r=1, g=0.2, b=0.2})
    self:drawRect(x, y, fillWidth, height, 0.9, color.r, color.g, color.b)

    -- Border
    self:drawRectBorder(x, y, width, height, 0.6, Colors.border.r, Colors.border.g, Colors.border.b)

    -- Percentage
    local text = level .. "%"
    self:drawText(text, x + width + 5, y - 1, Colors.textPrimary.r, Colors.textPrimary.g, Colors.textPrimary.b, 0.9, UIFont.NewSmall)
end

function EPR_FacilityPanelNew:drawSectionBox(x, y, width, height, title)
    -- Background
    self:drawRect(x, y, width, height, Colors.panelBg.a, Colors.panelBg.r, Colors.panelBg.g, Colors.panelBg.b)

    -- Border with rounded corners effect
    self:drawRectBorder(x, y, width, height, 0.8, Colors.border.r, Colors.border.g, Colors.border.b)

    -- Corner accents
    local cornerSize = 8
    self:drawRect(x, y, cornerSize, cornerSize, 0.4, Colors.border.r, Colors.border.g, Colors.border.b)
    self:drawRect(x + width - cornerSize, y, cornerSize, cornerSize, 0.4, Colors.border.r, Colors.border.g, Colors.border.b)
    self:drawRect(x, y + height - cornerSize, cornerSize, cornerSize, 0.4, Colors.border.r, Colors.border.g, Colors.border.b)
    self:drawRect(x + width - cornerSize, y + height - cornerSize, cornerSize, cornerSize, 0.4, Colors.border.r, Colors.border.g, Colors.border.b)

    -- Title
    if title then
        local titleWidth = getTextManager():MeasureStringX(UIFont.Small, " " .. title .. " ") + 8
        self:drawRect(x + 12, y - 2, titleWidth, 5, 1, Colors.background.r, Colors.background.g, Colors.background.b)
        self:drawText(" " .. title .. " ", x + 15, y - 9, Colors.textHighlight.r, Colors.textHighlight.g, Colors.textHighlight.b, 1, UIFont.Small)
    end
end

function EPR_FacilityPanelNew:drawActionButton(x, y, width, height, text, color, callback)
    -- Store callback for click handling (table is reset in render())
    table.insert(self.actionButtons, {x = x, y = y, w = width, h = height, callback = callback})

    self:drawRect(x, y, width, height, Colors.buttonBg.a, Colors.buttonBg.r, Colors.buttonBg.g, Colors.buttonBg.b)
    self:drawRectBorder(x, y, width, height, color.a, color.r, color.g, color.b)

    -- Center text both horizontally and vertically
    local textWidth = getTextManager():MeasureStringX(UIFont.Medium, text)
    local textHeight = getTextManager():MeasureStringY(UIFont.Medium, text)
    local textY = y + (height - textHeight) / 2
    self:drawText(text, x + (width - textWidth) / 2, textY, color.r, color.g, color.b, 1, UIFont.Medium)
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

function EPR_FacilityPanelNew:getTypeText()
    local types = {
        power = getEprText("UI_EPR_Panel_TypePower", "TYPE: POWER SUBSTATION"),
        water = getEprText("UI_EPR_Panel_TypeWater", "TYPE: WATER TREATMENT"),
        combined = getEprText("UI_EPR_Panel_TypeCombined", "TYPE: COMBINED UTILITY PLANT"),
    }
    return types[self.facility.type] or getEprText("UI_EPR_Panel_TypeUnknown", "TYPE: UNKNOWN")
end

function EPR_FacilityPanelNew:getStatusDisplay(status)
    local displays = {
        offline = {"OFFLINE", Colors.textDim, Colors.ledOffline},
        online = {"ONLINE", Colors.textSuccess, Colors.ledOnline},
        repairing = {"UNDER REPAIR", Colors.textWarning, Colors.ledRepairing},
        starting = {"STARTING UP...", Colors.textWarning, Colors.ledStarting},
        ready = {"READY FOR STARTUP", Colors.textSuccess, Colors.ledReady},
        broken = {"CRITICAL FAILURE", Colors.textDanger, Colors.ledBroken},
    }
    local d = displays[status] or displays.offline
    return d[1], d[2], d[3]
end

function EPR_FacilityPanelNew:getLEDColorForStatus(status)
    local colors = {
        functional = Colors.ledOnline,
        repaired = Colors.ledOnline,
        repairing = Colors.ledRepairing,
        damaged = Colors.ledBroken,
    }
    return colors[status] or Colors.ledOffline
end

function EPR_FacilityPanelNew:getComponentStageText(compState)
    if compState.status == "functional" or compState.status == "repaired" then
        return "COMPLETE"
    elseif compState.status == "repairing" then
        local stageName = compState.currentStage or "Assessment"
        local stageDef = EPR.Repair and EPR.Repair.Stages and EPR.Repair.Stages[stageName]
        local stageDisplay = stageDef and stageDef.name or stageName
        local progress = compState.stageProgress or 0
        return stageDisplay .. " " .. math.floor(progress) .. "%"
    elseif compState.status == "damaged" then
        local stageName = compState.currentStage or "Assessment"
        local stageDef = EPR.Repair and EPR.Repair.Stages and EPR.Repair.Stages[stageName]
        return "Needs " .. (stageDef and stageDef.name or stageName)
    end
    return "UNKNOWN"
end

function EPR_FacilityPanelNew:calculateOverallProgress()
    if not self.status or not self.status.components then return 0 end

    local totalComponents = 0
    local completedComponents = 0
    local partialProgress = 0

    local componentOrder = self.status.componentOrder or EPR.ComponentOrder or {"ControlPanel"}

    for _, compType in ipairs(componentOrder) do
        local compState = self.status.components[compType]
        if compState then
            totalComponents = totalComponents + 1

            if compState.status == "functional" or compState.status == "repaired" then
                completedComponents = completedComponents + 1
            elseif compState.status == "repairing" then
                local stagesCompleted = 0
                local totalStages = compState.requiredStages and #compState.requiredStages or 3
                if compState.stagesCompleted then
                    for _ in pairs(compState.stagesCompleted) do
                        stagesCompleted = stagesCompleted + 1
                    end
                end
                local stageProgress = (compState.stageProgress or 0) / 100
                local componentProgress = (stagesCompleted + stageProgress) / totalStages
                partialProgress = partialProgress + componentProgress
            end
        end
    end

    if totalComponents == 0 then return 0 end

    local progress = ((completedComponents + partialProgress) / totalComponents) * 100
    return math.floor(progress)
end

function EPR_FacilityPanelNew:countComponentStatus()
    local total, repaired, repairing, damaged = 0, 0, 0, 0

    if not self.status or not self.status.components then
        return total, repaired, repairing, damaged
    end

    for _, compState in pairs(self.status.components) do
        total = total + 1
        if compState.status == "functional" or compState.status == "repaired" then
            repaired = repaired + 1
        elseif compState.status == "repairing" then
            repairing = repairing + 1
        else
            damaged = damaged + 1
        end
    end

    return total, repaired, repairing, damaged
end

function EPR_FacilityPanelNew:calculateTimeEstimate()
    -- Calculate total estimated time remaining
    local totalMinutes = 0

    if not self.status or not self.status.components then
        return "N/A"
    end

    if self.status.components then
        for _, compState in pairs(self.status.components) do
            if compState.status ~= "functional" and compState.status ~= "repaired" then
                local stagesToGo = 0
                local requiredStages = compState.requiredStages or {"Assessment", "PartReplacement", "Calibration"}

                for _, stageName in ipairs(requiredStages) do
                    if not compState.stagesCompleted or not compState.stagesCompleted[stageName] then
                        local stageDef = EPR.Repair and EPR.Repair.Stages and EPR.Repair.Stages[stageName]
                        if stageDef then
                            totalMinutes = totalMinutes + (stageDef.baseTimeMinutes or 30)
                        end
                    end
                end

                -- Subtract current progress
                if compState.currentStage and compState.stageProgress then
                    local currentStageDef = EPR.Repair and EPR.Repair.Stages and EPR.Repair.Stages[compState.currentStage]
                    if currentStageDef then
                        local stageMinutes = currentStageDef.baseTimeMinutes or 30
                        totalMinutes = totalMinutes - (stageMinutes * compState.stageProgress / 100)
                    end
                end
            end
        end
    end

    if totalMinutes <= 0 then return "Complete" end
    if totalMinutes < 60 then return math.floor(totalMinutes) .. " min" end

    local hours = math.floor(totalMinutes / 60)
    local mins = math.floor(totalMinutes % 60)
    return hours .. "h " .. mins .. "m"
end

function EPR_FacilityPanelNew:getStageTimeEstimate(compState)
    if not compState.currentStage then return "" end

    local stageDef = EPR.Repair and EPR.Repair.Stages and EPR.Repair.Stages[compState.currentStage]
    if not stageDef then return "" end

    local baseMinutes = stageDef.baseTimeMinutes or 30
    local progress = compState.stageProgress or 0
    local remaining = baseMinutes * (1 - progress / 100)

    if remaining < 1 then return "<1 min" end
    if remaining < 60 then return math.floor(remaining) .. " min" end

    return math.floor(remaining / 60) .. "h " .. math.floor(remaining % 60) .. "m"
end

function EPR_FacilityPanelNew:playerHasTool(toolKey)
    if not EPR.Repair or not EPR.Repair.HasTool then return false end
    return EPR.Repair.HasTool(self.player, toolKey)
end

function EPR_FacilityPanelNew:getPlayerSkillLevel(skillName)
    if not self.player then
        return 0
    end

    if not Perks then
        return 0
    end

    local perk = Perks[skillName]
    if not perk then
        -- Try fallbacks for different naming conventions
        if skillName == "Electricity" then perk = Perks.Electrical end
        if skillName == "Welding" then perk = Perks.MetalWelding end
    end

    if perk and self.player.getPerkLevel then
        local success, level = pcall(function()
            return self.player:getPerkLevel(perk)
        end)
        if success then
            return level or 0
        end
    end
    return 0
end

function EPR_FacilityPanelNew:canRepairComponent(compType, compState)
    -- Check skills
    if EPR.Repair and EPR.Repair.CheckPlayerSkills then
        local meetsSkills = EPR.Repair.CheckPlayerSkills(self.player, self.facility, compState)
        if not meetsSkills then
            return false, "Insufficient skills"
        end
    end

    -- Check tools
    local currentStage = compState.currentStage or "Assessment"
    if EPR.Repair and EPR.Repair.CheckStageTools then
        local hasTools, missingTool = EPR.Repair.CheckStageTools(self.player, currentStage)
        if not hasTools then
            return false, "Missing " .. (missingTool or "tools")
        end
    end

    -- Check parts (for Part Replacement stage)
    if currentStage == "PartReplacement" then
        if EPR.Repair and EPR.Repair.CheckStageParts then
            local hasParts = EPR.Repair.CheckStageParts(self.player, compState, currentStage)
            if not hasParts then
                return false, "Missing parts"
            end
        end
    end

    return true, nil
end

-- ============================================
-- UPDATE & EVENTS
-- ============================================

function EPR_FacilityPanelNew:update()
    ISPanel.update(self)

    -- CRT effects timing
    self.blinkTimer = self.blinkTimer + 0.016
    if self.blinkTimer >= 0.5 then
        self.blinkTimer = 0
        self.blinkOn = not self.blinkOn
    end

    -- Glow pulse
    self.glowPulse = self.glowPulse + 0.02
    if self.glowPulse > math.pi * 2 then
        self.glowPulse = 0
    end

    -- Random flicker
    if ZombRand(100) < 2 then
        self.flickerAlpha = 0.85 + (ZombRand(15) / 100)
    else
        self.flickerAlpha = math.min(1.0, self.flickerAlpha + 0.05)
    end

    -- Random static burst
    if ZombRand(500) < 1 then
        self.staticIntensity = 0.5 + (ZombRand(50) / 100)
        -- Pre-calculate static noise positions for render
        self.staticNoisePositions = {}
        for i = 1, math.floor(self.staticIntensity * 50) do
            table.insert(self.staticNoisePositions, {
                x = ZombRand(self.width),
                y = ZombRand(self.height),
                size = ZombRand(1, 4),
                alpha = ZombRand(10, 30) / 100
            })
        end
    else
        self.staticIntensity = math.max(0, self.staticIntensity - 0.02)
        if self.staticIntensity <= 0 then
            self.staticNoisePositions = nil
        end
    end

    -- Live status refresh
    self.updateTimer = self.updateTimer + 1
    if self.updateTimer >= self.updateInterval then
        self.updateTimer = 0
        self:refreshStatus()
    end

    -- Update alerts
    for i = #self.alerts, 1, -1 do
        self.alerts[i].lifetime = self.alerts[i].lifetime - 0.016
        if self.alerts[i].lifetime <= 0 then
            table.remove(self.alerts, i)
        end
    end
end

function EPR_FacilityPanelNew:refreshStatus()
    if self.facility then
        local facilityId = self.facility.id
        local facilityType = self.facility.type

        local newStatus = nil
        if facilityType == "power" or facilityType == "combined" then
            newStatus = EPR.Substations and EPR.Substations[facilityId]
        elseif facilityType == "water" then
            newStatus = EPR.WaterPlants and EPR.WaterPlants[facilityId]
        end

        if newStatus then
            self.status = newStatus
        end
    end
end

function EPR_FacilityPanelNew:onClose()
    -- Save state
    EPR.FacilityUI.StateMemory.currentTab = self.currentTab
    EPR.FacilityUI.StateMemory.scrollPositions[self.currentTab] = self.scrollY
    EPR.FacilityUI.StateMemory.selectedComponent = self.selectedComponent

    self:setVisible(false)
    self:removeFromUIManager()
    EPR.FacilityUI.instance = nil
end

function EPR_FacilityPanelNew:onMouseDown(x, y)
    ISPanel.onMouseDown(self, x, y)

    -- Check action button clicks
    if self.actionButtons then
        for _, btn in ipairs(self.actionButtons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if btn.callback then
                    btn.callback()
                end
                return true
            end
        end
    end

    -- Check component grid clicks (Overview tab)
    if self.currentTab == 1 then
        if self:handleGridClick(x, y) then
            return true
        end
    end

    -- Check repair button clicks (Repairs tab)
    if self.currentTab == 2 then
        if self:handleRepairButtonClick(x, y) then
            return true
        end
    end

    return false
end

function EPR_FacilityPanelNew:handleGridClick(x, y)
    -- Use stored component list areas from renderComponentList
    if not self.componentListAreas then return false end

    -- Check if click is within the component list bounds
    local bounds = self.componentListBounds
    if bounds and (x < bounds.x or x > bounds.x + bounds.w or y < bounds.y or y > bounds.y + bounds.h) then
        return false
    end

    -- Check each component row
    for _, area in ipairs(self.componentListAreas) do
        if x >= area.x and x <= area.x + area.w and y >= area.y and y <= area.y + area.h then
            -- Select this component (don't start repair)
            self.selectedComponent = area.compType
            EPR.FacilityUI.StateMemory.selectedComponent = area.compType
            return true
        end
    end

    return false
end

function EPR_FacilityPanelNew:handleRepairButtonClick(x, y)
    -- Note: Button clicks are now handled by the actionButtons system via drawActionButton
    -- This function is kept for backwards compatibility but should not be needed
    -- The actionButtons table is populated in renderRepairEntryDetailed and clicked in onMouseDown

    -- Calculate positions matching renderRepairsTab and renderRepairEntryDetailed
    local padX = self.contentPadX or 15
    local contentY = self.contentY or 130
    local width = self.width - padX * 2

    local componentOrder = self.status.componentOrder or EPR.ComponentOrder or {"ControlPanel"}
    local entryHeight = 210 + 10  -- Match renderRepairsTab (210 + 10 gap)
    local innerPadX = 10

    -- Match renderRepairsTab: title at y, then y + 30 for entries
    local startY = contentY + 30 - (self.repairsTabScrollY or 0)
    local entryWidth = width - innerPadX * 2

    for i, compType in ipairs(componentOrder) do
        local entryY = startY + (i - 1) * entryHeight
        local btnWidth = 130
        local btnHeight = 25
        local btnX = padX + innerPadX + entryWidth - btnWidth - 15
        local btnY = entryY + 210 - btnHeight - 10  -- Match renderRepairEntryDetailed

        if x >= btnX and x <= btnX + btnWidth and y >= btnY and y <= btnY + btnHeight then
            local compState = self.status.components and self.status.components[compType]
            if compState and compState.status ~= "functional" and compState.status ~= "repaired" then
                if EPR.Repair and EPR.Repair.StartComponentRepair then
                    local canRepair, reason = self:canRepairComponent(compType, compState)
                    if canRepair then
                        EPR.Repair.StartComponentRepair(self.player, self.facility, compType)
                        self:onClose()
                    else
                        self:addAlert(reason or "Cannot repair this component", 3)
                    end
                end
            end
            return true
        end
    end
    return false
end

-- Mouse wheel for scrolling component list
function EPR_FacilityPanelNew:onMouseWheel(delta)
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local scrollAmount = 40  -- pixels per scroll tick

    -- Overview tab: Component list scroll
    if self.currentTab == 1 then
        local bounds = self.componentListBounds
        if bounds and mouseX >= bounds.x and mouseX <= bounds.x + bounds.w and
           mouseY >= bounds.y and mouseY <= bounds.y + bounds.h then
            self.componentListScrollY = self.componentListScrollY - (delta * scrollAmount)
            self.componentListScrollY = math.max(0, math.min(self.componentListScrollY, bounds.maxScroll or 0))
            return true
        end
    end

    -- Repairs tab: Entry list scroll
    if self.currentTab == 2 then
        local bounds = self.repairsTabBounds
        if bounds and mouseX >= bounds.x and mouseX <= bounds.x + bounds.w and
           mouseY >= bounds.y and mouseY <= bounds.y + bounds.h then
            self.repairsTabScrollY = (self.repairsTabScrollY or 0) - (delta * scrollAmount)
            self.repairsTabScrollY = math.max(0, math.min(self.repairsTabScrollY, bounds.maxScroll or 0))
            return true
        end
    end

    return false
end

-- Click outside to close (verify click is actually outside panel bounds)
function EPR_FacilityPanelNew:onMouseDownOutside(x, y)
    -- Convert to screen coordinates and check if truly outside
    local screenX = self:getX()
    local screenY = self:getY()
    local mouseX = getMouseX()
    local mouseY = getMouseY()

    -- Only close if click is truly outside the panel
    if mouseX < screenX or mouseX > screenX + self.width or
       mouseY < screenY or mouseY > screenY + self.height then
        self:onClose()
    end
end

-- ============================================
-- PUBLIC API
-- ============================================

function EPR.FacilityUI.Open(player, facility, status)
    -- Close existing panel
    if EPR.FacilityUI.instance then
        EPR.FacilityUI.instance:onClose()
    end

    -- Get or generate facility state
    if EPR.Repair and EPR.Repair.GetFacilityState then
        status = EPR.Repair.GetFacilityState(facility)
    end

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()

    -- Large centered panel (~80% of screen)
    local panelW = math.min(1100, math.floor(screenW * 0.75))
    local panelH = math.min(900, math.floor(screenH * 0.85))

    local panel = EPR_FacilityPanelNew:new(
        (screenW - panelW) / 2,
        (screenH - panelH) / 2,
        panelW,
        panelH,
        player,
        facility,
        status
    )
    panel:initialise()
    panel:instantiate()
    panel:addToUIManager()
    panel:setVisible(true)

    EPR.FacilityUI.instance = panel
    return panel
end

function EPR.FacilityUI.Close()
    if EPR.FacilityUI.instance then
        EPR.FacilityUI.instance:onClose()
    end
end

function EPR.FacilityUI.IsOpen()
    return EPR.FacilityUI.instance ~= nil and EPR.FacilityUI.instance:isVisible()
end

function EPR.FacilityUI.RefreshIfOpen()
    if EPR.FacilityUI.IsOpen() then
        EPR.FacilityUI.instance:refreshStatus()
    end
end

-- Keep old component panel API for backwards compatibility
function EPR.FacilityUI.OpenComponent(player, facility, status, componentType)
    -- Just open the main panel - it handles components now
    EPR.FacilityUI.Open(player, facility, status)
end

print("[EPR] EPR_FacilityUI_New.lua loaded successfully")
