# Extensive Power Rework (Community fork)

A community continuation of **Extensive Power Rework** for Project Zomboid Build 42.

The original mod was authored by **Hainrich**, who publicly opened it for community forks when stepping back from PZ modding. This fork carries the work forward with a fix-only maintenance posture (Option A in the brainstorm): drop-in compatibility patches when TIS ships engine updates, no feature creep unless the community asks for it.

## What it does

Power and water infrastructure overhaul: substations and water treatment facilities are real, repairable objects. Players restore utilities to zones by completing repair tasks at the right locations.

## Status

- v0.1.0 baseline forked from `EPR_B42_RB` v1.0.4 (which itself was a community continuation of `EPR_B42` v1.0.3 by Hainrich).
- B42.18 compatible.
- No Java patches.
- Server-friendly: Lua + sandbox options only.

## Compatibility

- No item-script overrides (won't orphan inventory on uninstall).
- Uses ModData on world objects. Removing mid-save = previously-repaired zones revert to non-functional but no save corruption.
- Sandbox options grouped under "Extensive Power Rework (Community fork)".

## Credits

Original concept, codebase, and the vast majority of the work: **Hainrich**.

This fork: **Grphx**.

## License / intent

Continuation under Hainrich's public invitation to community forks. If Hainrich returns to PZ modding, this fork will defer back.
