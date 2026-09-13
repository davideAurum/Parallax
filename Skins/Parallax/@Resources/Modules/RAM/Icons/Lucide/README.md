# Lucide RAM title icon

The user selected [Lucide memory-stick](https://lucide.dev/icons/memory-stick)
for the main RAM title on 2026-09-12 and supplied its SVG as a data URL.
`memory-stick.svg` preserves those exact decoded bytes, without reformatting,
a byte-order mark or an added trailing newline. It is the user-supplied source,
not a claim of byte-for-byte identity with an upstream repository serialization.

Source SHA256: `385F9921AE53804E1F6EABE4BFE026047BCB7C80F36180C0A4878CFBE5751A5B`

The 480-byte source has a 24-by-24 viewBox, ten paths and one rounded rectangle,
with no fill, a 2-unit `currentColor` stroke, and round caps and joins.
`../../Meters.inc` adapts that geometry to native Rainmeter Shape meters:
all coordinates and rectangle radii scale uniformly by `TitleIconSize / 24`,
the stroke width is `2 * TitleIconSize / 24`, and `currentColor` maps to
`RAMColor`. The existing canvas remains `TitleIconSize = 14 * TitleIconScale`,
where `TitleIconScale = Scale * TitleFontSize / 10`, centered on the shared
title row. The artwork uses all ten paths and the rounded rectangle.

The SVG is retained for provenance, not loaded by Rainmeter. The adaptation
adds no plugin, icon font, runtime network access, extra asset dependency or
polling. Its native rendering still needs visual validation at small sizes.

## License and provenance

The official [memory-stick page](https://lucide.dev/icons/memory-stick)
identifies the icon and the ISC license. The complete upstream notice is
retained in [LICENSE](LICENSE), including Lucide's ISC terms and its additional
Feather MIT section. That notice identifies the copyright as
`Copyright (c) 2026 Lucide Icons and Contributors`; its listed Feather-derived
icons do not include memory-stick. The full notice is retained without edits
rather than removing sections from the upstream license.

The notice was copied byte-for-byte from the already preserved Media Lucide
notice and checked against the official [LICENSE at Lucide revision
a79b2d131dab2bf20cb224bd0937b439a9c4fa99](https://github.com/lucide-icons/lucide/blob/a79b2d131dab2bf20cb224bd0937b439a9c4fa99/LICENSE).
No Media file was changed.

LICENSE SHA256: `B495047BD93A9B06913511076F504DABA17D5BBEB3E0650F3BB53A4220329C57`

Source preservation checks confirm an exact base64 round trip, valid XML,
the ten paths and rectangle, the viewBox, and the stroke/cap/join attributes.
These checks establish the retained source only; production geometry checks
and native appearance are separate validation steps.
