-- EPR_DebugMenu: admin right-click context menu for EPR_Community.
-- Mirrors ZT_DebugMenu's pattern from The Director.
--
-- Items:
--   * Open EPR Debug Panel       - full Zones/Facilities/World UI
--   * Noise burst here (r=50)    - quick zombie-attract test
--   * Toggle global override     - instant power kill-switch
--   * Request sync (MP)          - re-pull state from server

print("[EPR DebugMenu] loading...")

local function isAuthorized(player)
    if not player then return false end
    if not isClient() then return true end -- host / SP
    local ok, isAdm = pcall(isAdmin)
    if ok and isAdm then return true end
    local lvl; pcall(function() lvl = player:getAccessLevel() end)
    if lvl == "Admin" or lvl == "admin" or lvl == "Moderator" or lvl == "moderator" then
        return true
    end
    local okDbg, dbg = pcall(function() return getCore():getDebug() end)
    if okDbg and dbg then return true end
    return false
end

local function debugEnabled()
    if EPR and EPR.IsDebugMode then return EPR.IsDebugMode() end
    if SandboxVars and SandboxVars.EPR and SandboxVars.EPR.DebugMode then return true end
    return false
end

local function send(command, args)
    if isClient() and sendClientCommand then
        sendClientCommand("EPR", command, args)
        return
    end
    local p = getSpecificPlayer and getSpecificPlayer(0)
    if EPR and EPR.Server and EPR.Server.OnClientCommand and p then
        EPR.Server.OnClientCommand("EPR", command, p, args)
    end
end

local function openPanel()
    if EPR and EPR.Client and EPR.Client.OpenDebugPanel then
        EPR.Client.OpenDebugPanel()
    else
        print("[EPR DebugMenu] ERROR: EPR.Client.OpenDebugPanel not defined - panel file failed to load")
    end
end

local function addEprDebugMenu(playerIndex, context, worldObjects, test)
    if test then return true end
    local player = getSpecificPlayer(playerIndex or 0)
    if not isAuthorized(player) then return end

    local parent = context:addOption("EPR Debug", nil, nil)
    local sub    = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    sub:addOption("Open EPR Debug Panel", nil, openPanel)

    sub:addOption("Noise burst here (r=50)", nil, function()
        if not player then return end
        send("DebugNoiseBurst", {
            x = math.floor(player:getX()),
            y = math.floor(player:getY()),
            z = math.floor(player:getZ()),
            radius = 50, volume = 120,
        })
    end)

    sub:addOption("Toggle global override", nil, function()
        local cur = EPR and EPR.PowerController and EPR.PowerController.globalOverride == true
        send("DebugGlobalOverride", { enabled = not cur })
    end)

    sub:addOption("Request sync", nil, function()
        if EPR and EPR.Client and EPR.Client.RequestSync then EPR.Client.RequestSync() end
    end)
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(addEprDebugMenu)
    print("[EPR DebugMenu] context menu hook registered (right-click world)")
else
    print("[EPR DebugMenu] ERROR: OnFillWorldObjectContextMenu unavailable")
end

-- Console fallback
function EPRDebug()
    if EPR and EPR.Client and EPR.Client.OpenDebugPanel then
        EPR.Client.OpenDebugPanel()
    else
        print("[EPR DebugMenu] ERROR: panel not loaded; EPR.Client.OpenDebugPanel is nil")
    end
end

print("[EPR DebugMenu] loaded")
