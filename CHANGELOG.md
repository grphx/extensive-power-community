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
