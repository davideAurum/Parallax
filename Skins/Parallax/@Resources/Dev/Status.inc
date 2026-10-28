; Result of the last comparison between a developer copy and the release.
; Written by @Resources\Dev\DevMode.ps1 (Compare) inside the developer copy only and
; read by DevStatus.lua; a release never reads it. Not a preference: the comparison
; ignores this file and a release install replaces it with these blanks.
[Variables]
DevComparedAt=0
DevReleaseVersion=
DevDiffTotal=0
DevDiffShared=0
DevDiffSuite=0
DevDiffChronometer=0
DevDiffCPU=0
DevDiffGPU=0
DevDiffIO=0
DevDiffMedia=0
DevDiffNetwork=0
DevDiffRAM=0
DevDiffVisualizer=0
