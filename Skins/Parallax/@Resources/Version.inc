; The installed Parallax release and where the Welcome panel looks for newer ones.
; Package-Parallax.ps1 refuses to build when ParallaxVersion differs from the
; version in packaging\release.json, so the running suite always knows which
; release it is. Not a Variables file: an upgrade replaces it with the new values.
[Variables]
ParallaxVersion=0.1.0-alpha
; One small JSON manifest attached to the newest GitHub release. The latest/download
; form always resolves to the release GitHub marks as Latest; pre-releases are skipped.
UpdateFeedURL=https://github.com/davideAurum/Parallax/releases/latest/download/parallax-update.json
; Packages and release notes are accepted only below this prefix.
UpdateReleaseBase=https://github.com/davideAurum/Parallax/releases/
