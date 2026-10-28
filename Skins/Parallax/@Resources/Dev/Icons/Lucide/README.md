# Lucide developer-copy status icons

The user selected two [Lucide](https://lucide.dev) icons on 2026-10-28 for the
developer copy's per-utility status readout:

| Icon | Used for | Retained source | Source SHA256 |
| --- | --- | --- | --- |
| [git-branch-plus](https://lucide.dev/icons/git-branch-plus) | red: the utility, or a shared file, differs from the release | `git-branch-plus.svg` (414 bytes) | `830099E8CF1D3E061A748555BEDA7948D9F9C1AA966505963F6C6B49BB4F1880` |
| [git-compare-arrows](https://lucide.dev/icons/git-compare-arrows) | green: it matches the release; muted: not compared yet or the comparison could not run | `git-compare-arrows.svg` (412 bytes) | `1EF65F69D07E6D4A7A79B28F597001DAD2FE6C4D9B0888446540F49044D6D3CE` |

Each file is the SVG text of the icon as read from the `main` branch of the
upstream [lucide-icons/lucide](https://github.com/lucide-icons/lucide) repository on
2026-10-28, without a byte-order mark or trailing newline. It is retained for
provenance, not loaded by Rainmeter, and is not claimed to be byte-for-byte
identical to a particular upstream revision.

Both icons share a 24-by-24 viewBox, no fill, a 2-unit `currentColor` stroke and
round caps and joins. `../../Hook1.inc` adapts them to native Rainmeter Shape
meters: every coordinate, radius and the stroke width scale uniformly by
`TitleIconSize / 24` (`ParallaxDevU`), SVG arcs become `ArcTo` with the same sweep
and size flags, and `currentColor` maps to `DangerColor`, `GoodColor` or
`MutedColor` by state. The canvas is the shared `TitleIconSize`, centered on the
title row. The adaptation adds no plugin, icon font, runtime network access, asset
dependency or polling, and it exists only in a developer copy: a release loads the
comment-only `Hook0.inc`.

## License and provenance

Lucide is ISC-licensed. The complete upstream notice, including its additional
Feather MIT section, is retained in [LICENSE](LICENSE). It was copied
byte-for-byte from the notice already preserved under
`../../../Modules/RAM/Icons/Lucide/`, which was checked against the official
[LICENSE at Lucide revision a79b2d131dab2bf20cb224bd0937b439a9c4fa99](https://github.com/lucide-icons/lucide/blob/a79b2d131dab2bf20cb224bd0937b439a9c4fa99/LICENSE).
Neither git-branch-plus nor git-compare-arrows is listed among the Feather-derived
icons in that notice.

LICENSE SHA256: `B495047BD93A9B06913511076F504DABA17D5BBEB3E0650F3BB53A4220329C57`
