# Facility Map

The mod ships with **6 facilities** scattered across Knox County. Each one
must be repaired (or activated via the [Debug Panel](../README.md)) to
restore power or water to its zones.

Coordinates are PZ world tiles. Click any facility name to open it on the
official [map.projectzomboid.com](https://map.projectzomboid.com) viewer.

## Power facilities

| Facility | Coords | Powers zones | Prereq? |
|---|---|---|---|
| [Louisville Power Plant](https://map.projectzomboid.com/#12120x1617x250) | 12120, 1617 | Louisville | Yes (master prereq) |
| [Louisville South Substation](https://map.projectzomboid.com/#14732x4083x250) | 14732, 4083 | WestPoint, ValleyStation, LouisvilleAirport | needs Louisville Plant |
| [Muldraugh Electrical Substation](https://map.projectzomboid.com/#10389x10060x250) | 10389, 10060 | Muldraugh, Rosewood, MarchRidge, FallasLake | needs Louisville Plant |
| [Riverside Relay Station](https://map.projectzomboid.com/#4832x6279x250) | 4832, 6279 | Riverside | needs Louisville Plant |
| [Irvington Substation](https://map.projectzomboid.com/#2210x13914x250) | 2210, 13914 | Irvington, EchoCreek, Ekron, Brandenburg | needs Louisville Plant |

## Water facilities

| Facility | Coords | Waters zones |
|---|---|---|
| [Rosewood Water Treatment Plant](https://map.projectzomboid.com/#8044x15360x250) | 8044, 15360 | Everywhere (Louisville, WestPoint, Muldraugh, Rosewood, Riverside, MarchRidge, ValleyStation, LouisvilleAirport, EchoCreek, Ekron, Irvington, Brandenburg, FallasLake) |

## Overview map

See [facilities-overview.svg](./facilities-overview.svg) for a single
schematic showing relative positions and which substation serves which
zone(s).

## Prerequisite chain

The **Louisville Power Plant is the master prereq**: every other power
substation requires Louisville to be online before its zones will receive
power. If `RequirePrerequisite` (sandbox) is on (default), this chain is
enforced. Turn that option off in sandbox to allow each substation to
operate independently.

The Rosewood Water Plant has no prereq.
