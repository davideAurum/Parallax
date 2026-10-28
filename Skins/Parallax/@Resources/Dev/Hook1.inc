; Developer copy (User\Settings.inc ParallaxDevBuild=1, written when Global Settings >
; Developer mode creates the copy). Utility entrypoints include
; @Resources\Dev\Hook#ParallaxDevBuild#.inc as their [ParallaxDevHookInclude]; each names
; its utility (ParallaxDevModule) and title meter (ParallaxDevTitle, plus
; ParallaxDevTitleMeasure when the title text comes from a measure).
;
; One small icon after the title shows whether this utility differs from the release:
;   red   git-branch-plus     it, or a shared file, differs
;   green git-compare-arrows  it matches the release
;   muted git-compare-arrows  not compared yet, or the comparison could not run
; The icons are the user-selected Lucide vectors in @Resources\Dev\Icons\Lucide\ (ISC),
; adapted to native Shapes on their 24-unit grid with 2-unit round strokes, scaled into
; the shared TitleIconSize. DevStatus.lua shows one of them and places it after the
; title text; nothing updates on a timer. Click compares once and opens the report.
[Variables]
ParallaxDevU=(#TitleIconSize#/24)
ParallaxDevDifferColor=#DangerColor#
ParallaxDevSameColor=#GoodColor#
ParallaxDevUnknownColor=#MutedColor#

[MeasureParallaxDev]
Measure=Script
ScriptFile=#@#Dev\DevStatus.lua
UpdateDivider=-1

; One hidden PowerShell launch per click, as in the update helper (Update\Install.inc).
[MeasureParallaxDevRun]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
Parameter=-NoProfile -NonInteractive
State=Hide
OutputType=UTF8
Timeout=120000
FinishAction=[!UpdateMeasure MeasureParallaxDevRun][!CommandMeasure MeasureParallaxDev "Finished()"]
UpdateDivider=-1
DynamicVariables=1

; The title's typography with a transparent face and no W/H, so it sizes itself to the
; text (StyleTitle would give it the full content width): the script reads its width to
; place the icon after the title.
[MeterParallaxDevProbe]
Meter=String
FontFace=#FontFace#
FontSize=(#TitleFontSize#*#Scale#)
FontWeight=600
AntiAlias=1
X=#ContentX#
Y=#TitleRowCenterY#
StringAlign=LeftCenter
FontColor=0,0,0,0
Text=
UpdateDivider=-1

; Lucide git-branch-plus.
[MeterParallaxDevDiffer]
Meter=Shape
X=#ContentX#
Y=(#TitleRowCenterY#-#TitleIconSize#/2)
W=#TitleIconSize#
H=#TitleIconSize#
Shape=Line (6*#ParallaxDevU#),(3*#ParallaxDevU#),(6*#ParallaxDevU#),(15*#ParallaxDevU#) | Stroke Color #ParallaxDevDifferColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape2=Ellipse (18*#ParallaxDevU#),(6*#ParallaxDevU#),(3*#ParallaxDevU#) | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevDifferColor# | StrokeWidth (2*#ParallaxDevU#)
Shape3=Ellipse (6*#ParallaxDevU#),(18*#ParallaxDevU#),(3*#ParallaxDevU#) | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevDifferColor# | StrokeWidth (2*#ParallaxDevU#)
Shape4=Path DifferArc | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevDifferColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
DifferArc=(15*#ParallaxDevU#),(6*#ParallaxDevU#) | ArcTo (6*#ParallaxDevU#),(15*#ParallaxDevU#),(9*#ParallaxDevU#),(9*#ParallaxDevU#),0,0,0
Shape5=Line (18*#ParallaxDevU#),(15*#ParallaxDevU#),(18*#ParallaxDevU#),(21*#ParallaxDevU#) | Stroke Color #ParallaxDevDifferColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
Shape6=Line (21*#ParallaxDevU#),(18*#ParallaxDevU#),(15*#ParallaxDevU#),(18*#ParallaxDevU#) | Stroke Color #ParallaxDevDifferColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
AntiAlias=1
Hidden=1
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureParallaxDev "Click()"]

; Lucide git-compare-arrows, green when the copy matches.
[MeterParallaxDevSame]
Meter=Shape
X=#ContentX#
Y=(#TitleRowCenterY#-#TitleIconSize#/2)
W=#TitleIconSize#
H=#TitleIconSize#
Shape=Ellipse (5*#ParallaxDevU#),(6*#ParallaxDevU#),(3*#ParallaxDevU#) | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevSameColor# | StrokeWidth (2*#ParallaxDevU#)
Shape2=Path SameUpper | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevSameColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
SameUpper=(12*#ParallaxDevU#),(6*#ParallaxDevU#) | LineTo (17*#ParallaxDevU#),(6*#ParallaxDevU#) | ArcTo (19*#ParallaxDevU#),(8*#ParallaxDevU#),(2*#ParallaxDevU#),(2*#ParallaxDevU#),0,1,0 | LineTo (19*#ParallaxDevU#),(15*#ParallaxDevU#)
Shape3=Path SameUpperHead | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevSameColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
SameUpperHead=(15*#ParallaxDevU#),(9*#ParallaxDevU#) | LineTo (12*#ParallaxDevU#),(6*#ParallaxDevU#) | LineTo (15*#ParallaxDevU#),(3*#ParallaxDevU#)
Shape4=Ellipse (19*#ParallaxDevU#),(18*#ParallaxDevU#),(3*#ParallaxDevU#) | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevSameColor# | StrokeWidth (2*#ParallaxDevU#)
Shape5=Path SameLower | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevSameColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
SameLower=(12*#ParallaxDevU#),(18*#ParallaxDevU#) | LineTo (7*#ParallaxDevU#),(18*#ParallaxDevU#) | ArcTo (5*#ParallaxDevU#),(16*#ParallaxDevU#),(2*#ParallaxDevU#),(2*#ParallaxDevU#),0,1,0 | LineTo (5*#ParallaxDevU#),(9*#ParallaxDevU#)
Shape6=Path SameLowerHead | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevSameColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
SameLowerHead=(9*#ParallaxDevU#),(15*#ParallaxDevU#) | LineTo (12*#ParallaxDevU#),(18*#ParallaxDevU#) | LineTo (9*#ParallaxDevU#),(21*#ParallaxDevU#)
AntiAlias=1
Hidden=1
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureParallaxDev "Click()"]

; The same git-compare-arrows in the muted color: not compared yet or unavailable.
[MeterParallaxDevUnknown]
Meter=Shape
X=#ContentX#
Y=(#TitleRowCenterY#-#TitleIconSize#/2)
W=#TitleIconSize#
H=#TitleIconSize#
Shape=Ellipse (5*#ParallaxDevU#),(6*#ParallaxDevU#),(3*#ParallaxDevU#) | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevUnknownColor# | StrokeWidth (2*#ParallaxDevU#)
Shape2=Path UnknownUpper | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevUnknownColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
UnknownUpper=(12*#ParallaxDevU#),(6*#ParallaxDevU#) | LineTo (17*#ParallaxDevU#),(6*#ParallaxDevU#) | ArcTo (19*#ParallaxDevU#),(8*#ParallaxDevU#),(2*#ParallaxDevU#),(2*#ParallaxDevU#),0,1,0 | LineTo (19*#ParallaxDevU#),(15*#ParallaxDevU#)
Shape3=Path UnknownUpperHead | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevUnknownColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
UnknownUpperHead=(15*#ParallaxDevU#),(9*#ParallaxDevU#) | LineTo (12*#ParallaxDevU#),(6*#ParallaxDevU#) | LineTo (15*#ParallaxDevU#),(3*#ParallaxDevU#)
Shape4=Ellipse (19*#ParallaxDevU#),(18*#ParallaxDevU#),(3*#ParallaxDevU#) | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevUnknownColor# | StrokeWidth (2*#ParallaxDevU#)
Shape5=Path UnknownLower | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevUnknownColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
UnknownLower=(12*#ParallaxDevU#),(18*#ParallaxDevU#) | LineTo (7*#ParallaxDevU#),(18*#ParallaxDevU#) | ArcTo (5*#ParallaxDevU#),(16*#ParallaxDevU#),(2*#ParallaxDevU#),(2*#ParallaxDevU#),0,1,0 | LineTo (5*#ParallaxDevU#),(9*#ParallaxDevU#)
Shape6=Path UnknownLowerHead | Fill Color 0,0,0,0 | Stroke Color #ParallaxDevUnknownColor# | StrokeWidth (2*#ParallaxDevU#) | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round
UnknownLowerHead=(9*#ParallaxDevU#),(15*#ParallaxDevU#) | LineTo (12*#ParallaxDevU#),(18*#ParallaxDevU#) | LineTo (9*#ParallaxDevU#),(21*#ParallaxDevU#)
AntiAlias=1
Hidden=1
UpdateDivider=-1
MouseActionCursor=1
LeftMouseUpAction=[!CommandMeasure MeasureParallaxDev "Click()"]
