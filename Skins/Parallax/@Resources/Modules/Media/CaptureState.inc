; Runtime state of the spectrum drawer's audio capture. Not a preference: only
; MediaOptions.lua's ApplyLease writes this file, and a release install
; replaces it with these zeros. Media.ini and Setup.ini read it before
; InlineQueueGeometry.inc and define the same defaults themselves, so a missing
; or partial file means live capture.
[Variables]
; 0 live capture, 1 capture paused (released after silence while you are
; away), 2 deferred to a loaded Audio Visualizer. While VisualizerDrawer=2 it
; names the drawer variant, Modules\Media\DrawerCapture<n>.inc.
MediaDrawerCapture=0
; Reserved for the idle stand-down; 0 here.
MediaStandby=0
; os.time() and floor(os.clock()) when ApplyLease last reloaded Media for the
; capture lease; MediaLifecycle.lua skips the provider resume for that reload
; only (docs/PERFORMANCE-REVIEW.md MEDIA-08). OnCloseAction writes At=0.
MediaLeaseRefreshAt=0
MediaLeaseRefreshClock=0
