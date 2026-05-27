--[[
    Extensive Power Rework - World Map Coverage Overlay (DISABLED)

    The in-game map overlay has been removed: it rendered poorly and did not
    work reliably across B42 world-map API builds. This file is intentionally
    an inert stub so the mod keeps loading cleanly and the feature can be
    reintroduced later without touching mod packaging or the
    EPR.ShowMapOverlay sandbox option (which is now a no-op, default Off).

    To restore: re-implement EPR.MapOverlay.Draw and re-add the
    ISWorldMap.render hook here. Nothing else in the mod depends on this
    module.
]]--

if isServer() and not isClient() then return end

print("[EPR] EPR_MapOverlay.lua loading (overlay disabled)...")

EPR = EPR or {}
EPR.MapOverlay = EPR.MapOverlay or {}
EPR.MapOverlay.disabled = true
EPR.MapOverlay.hooksApplied = false

-- No-op: kept so any external/legacy call site stays safe. Deliberately does
-- not hook ISWorldMap.render, so nothing is ever drawn on the map.
function EPR.MapOverlay.Draw() end

print("[EPR] EPR_MapOverlay.lua loaded successfully (overlay disabled)")
