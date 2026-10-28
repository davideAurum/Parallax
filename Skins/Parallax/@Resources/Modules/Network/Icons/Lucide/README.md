# Network link-capacity icons

The user selected Lucide [phone-incoming](https://lucide.dev/icons/phone-incoming) and [phone-outgoing](https://lucide.dev/icons/phone-outgoing) on 2026-10-28 to lead the receive and transmit link-capacity values in the identity panel. `phone-incoming.svg` and `phone-outgoing.svg` are the upstream files at [Lucide revision a79b2d131dab2bf20cb224bd0937b439a9c4fa99](https://github.com/lucide-icons/lucide/tree/a79b2d131dab2bf20cb224bd0937b439a9c4fa99/icons), unmodified, with the original 24-unit canvas and 2-unit stroke.

Lucide uses the [ISC license](https://lucide.dev/license). The full upstream license is retained in `LICENSE` (identical to the copy under `Modules/IO/Icons/Lucide`).

`ConnectionMeters.inc` adapts each SVG into native Rainmeter Shape paths (`MeterConnectionRxIcon`, `MeterConnectionTxIcon`): coordinates, radii and the stroke scale by `NetworkPhoneScale` (14 logical pixels / 24 units, times `Scale`); `currentColor` maps to `NetworkInColor` / `NetworkOutColor`. Round caps and joins are preserved. SVG arc sweep 0 maps to Rainmeter sweep 1 and sweep 1 to 0, as in the Disk meter's icon. The SVGs are retained for provenance, not loaded at runtime. No plugin, font, raster asset or runtime download is added.

SHA256:
- phone-incoming.svg: `FA7260E90F84023819161F90DF54DD6979A5185AE7412DDD90E3C4607EEDB8FB`
- phone-outgoing.svg: `79697BCE1CA9E1C5499CA24B5A9B1346D195FD5984691E7BD1826314BF272E7B`
- LICENSE: `B495047BD93A9B06913511076F504DABA17D5BBEB3E0650F3BB53A4220329C57`
