# Changelog

## Additional Features (Community Fork additions)

Everything in this section is **new** in the Community fork on top of
Hunter's `EPR_B42` v1.0.3 / `EPR_B42_RB` v1.0.4 baseline. Original
authorship remains Hunter's; this list tracks only what the fork adds.

### Gameplay
- **Storm Blackouts** (v0.3.0) - during thunderstorms, online
  substations have a configurable chance to be knocked offline by
  lightning, forcing repair. Server-side, sandbox-gated. Three sandbox
  options (`StormBlackoutsEnabled`, `StormBlackoutChancePerCheck`,
  `StormBlackoutRequireThunder`).

### Admin tooling
- **EPR Debug Panel** (v0.3.0) - admin / SP / -debug-only right-click
  submenu with a tabbed window: Zones (per-zone power+water toggles),
  Facilities (Teleport, Flicker, Repair, Activate, Deactivate per
  substation + water plant), World (global override, noise burst,
  Force vanilla shutoff, Lightning strike random / ALL online).

---

## [0.4.1] - 2026-06-09 - Sprite-generator grid-power opt-in

Workshop user reports flagged that "the entire KY power grid gets power
the moment any building has EPR power" - the immovable industrial-site
generator sprites (sprite IDs `industry_02_52`, `_53`, `_67`, `_71`)
were being treated as alternate EPR power sources, so activating any
of them flipped the global grid override and powered the whole map.

The underlying issue is architectural: EPR's grid-restoration system
operates on the GLOBAL `SandboxVars.ElecShutModifier` rather than per-
building, and fixing that properly is a larger v0.5 effort (likely
requires a Java-side override of `IsoObject.isPowered`). This v0.4.1
ships the simpler workaround the bug-report community asked for:

- **New sandbox option `EPR.EnableSpriteGenerators`** (page = EPR,
  default = **off**). When OFF, the four hardcoded industrial-site
  generator sprites have no effect on EPR's global grid override -
  the only way to restore the grid is repairing Louisville Plant via
  the substation chain, as originally intended.
- When ON, behaviour matches v0.4.0 (any sprite generator restores
  the whole grid). Toggle is exposed for server admins who prefer the
  old behaviour.
- **Vanilla portable generators are untouched.** This option only
  controls EPR's sprite-source grid-override path. Vanilla portable
  generators (the moveable item you find/craft, place down, and
  connect to wires) continue to power buildings via wires exactly as
  PZ ships them.

Single change in `EPR_PowerController.IsAnySpriteGeneratorActive()`:
returns `false` immediately when the option is off, short-circuiting
the global-override trigger. Plus the option declaration in
`sandbox-options.txt` and the Sandbox.json translation.

## [0.4.0] - 2026-05-29 - Water-shutoff bugfix + indestructible-after-repair option

Bug fixes:
- **Water no longer cuts after day 1.** `UpdateZoneStatus()` in `EPR_Zones.lua`
  was conflating water-zone state with Louisville Power Plant status: when
  Louisville (the *power* prereq) was offline (its default state pre-repair),
  the function early-returned after setting `WaterZones[*] = false` for every
  zone. This killed water in-world on day 0 the moment the first periodic
  `UpdateZoneStatus` ran. Now the water side is driven only by water-facility
  status (Rosewood Water Treatment Plant), unaffected by Louisville Plant.
- Power zones still honour the Louisville Plant prereq; only water is
  decoupled.

New config:
- **`DegradationRate` minimum is now 0** (was 0.25). Set to 0 to fully disable
  facility wear after repair - repaired stations stay healthy indefinitely.
  Combined with `RandomBreakdownEnabled = false`, gives a fully
  "fix-it-and-forget-it" mode.

## [0.3.0] - 2026-05-27 - Storm Blackouts + Debug Panel

New features:
- **Storm Blackouts** (server-side, sandbox-gated): during thunderstorms,
  any online substation has a configurable chance per 10-minute tick of
  being knocked offline by a lightning strike. Reuses EPR's existing
  breakdown flow so the player must repair the facility to restore power.
  Three sandbox options: `StormBlackoutsEnabled` (default on),
  `StormBlackoutChancePerCheck` (default 25), `StormBlackoutRequireThunder`
  (default on; if off, heavy rain also counts).
- **EPR Debug Panel** (admin/SP/-debug only): right-click world ->
  "EPR Debug" submenu. Tabs: Zones (per-zone power/water toggles),
  Facilities (Teleport / Flicker / Repair / Activate / Deactivate per
  substation + water plant), World (global override, noise burst, Force
  vanilla shutoff, Lightning strike random / ALL online).
- **Force vanilla shutoff NOW** button: poisons EPR's three cached
  "original ElecShutModifier" values and clears Louisville's offline-grace
  flag so the vanilla grid actually dies during testing. Destructive to
  the save's sandbox state - only for testing.

## [0.1.0] - 2026-05-21 - Initial fork

- Forked from `EPR_B42_RB` v1.0.4 (community continuation of Hainrich's
  original `EPR_B42` v1.0.3). Includes the bug-fix delta accumulated in
  that intermediate fork.
- Renamed: `EPR_B42_RB` -> `EPR_Community`. Display name: "Extensive
  Power Rework (Community fork)" to preserve the original mod name.
- mod.info `author=Hunter` (original creator). README and Workshop
  description credit Hunter exclusively, per their public invitation
  to community forks.
- No code changes versus the baseline; this release is the rebrand +
  documentation pass that sets the project up for ongoing maintenance.
- Lua + sandbox only; no Java patches.
- Initial release ships as unlisted on Steam Workshop for soft-launch
  testing.
