# Extensive Power Rework (Community fork)

A community continuation of **Extensive Power Rework** for Project Zomboid Build 42.

The original mod was created by **Hunter**, who publicly opened it for community forks when stepping back from PZ modding. This fork carries the work forward.

## What it does

Power and water infrastructure overhaul: substations and water treatment facilities are real, repairable objects. Players restore utilities to zones by completing repair tasks at the right locations.

## Status

- v0.1.0 baseline forked from `EPR_B42_RB` v1.0.4 (which was a prior community continuation of Hunter's `EPR_B42` v1.0.3).
- B42.18 compatible.
- No Java patches.
- Server-friendly: Lua + sandbox options only.

## Compatibility

- No item-script overrides (won't orphan inventory on uninstall).
- Uses ModData on world objects. Removing mid-save = previously-repaired zones revert to non-functional but no save corruption.
- Sandbox options grouped under "Extensive Power Rework (Community fork)".

## Credits

Original concept, codebase, and all of the work: **Hunter**.

## License / intent

Continuation under Hunter's public invitation to community forks. If Hunter returns to PZ modding, this fork will defer back.
