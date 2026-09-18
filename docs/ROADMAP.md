# Parallax milestones

## Foundation and initial instruments

Implemented: shared Default theme, scale/gutter geometry, independent utility configs, variable preservation, baseline native metrics, timer/event controls, optional-provider setup and validated source staging. Global Settings now includes two accents, title/header/body typography, rounding, background transparency and border/divider controls with a reusable color picker.

## Customization and integrations

Module settings now cover several visibility and layout choices, with dedicated settings utilities where implemented. Continue with ordering, graph ranges, warning thresholds and module launch controls. Extend countdown list lengths and dated-event behavior beyond the current slots. Expand real-hardware acceptance for sensor selection and device discovery.

Media includes optional WebNowPlaying controls and an authenticated Spotify queue provider. Initial live queue authorization and refresh passed; wider player/API failure cases and performance remain acceptance work. Network is independently loadable with connection information; process traffic attribution or connection tracing remains an opt-in extension only if overhead justifies it.

## Integration and distribution

Run every utility alone and together, check settings refresh without losing countdowns, reload persistence, missing sources, long strings, scaled snapping and mixed-DPI layouts. Record Rainmeter plus provider CPU/memory at idle, normal activity and visualizer load. Establish budgets from measurements on documented hardware, then tune defaults.

Build the `.rmskin` with `tools/Package-Parallax.ps1` (or the official Skin Packager) from a fresh stage, review dependencies and attribution, verify clean install and settings-preserving upgrades with that package, then publish a versioned artifact only after acceptance. A validated stage or a structurally verified package is useful development output but is not an installation test or a release-readiness claim.
