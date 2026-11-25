; Fits a tall settings panel to its screen and scrolls the rest (docs/UTILITY-SETTINGS.md,
; "Tall panels"). Include it right after MeterPanel. Set PanelScrollTop in the panel's own
; [Variables] (logical px from the panel's top to where the scrolling part starts) and
; PanelScrollEditor (its numeric entry measure), and give every meter that scrolls
; Container=MeterScrollBody. Scripts\PanelScroll.lua owns the variables below and, through
; PanelHeightPx and WindowHeight, the panel's height: the designed one, or the work area's
; where that is shorter. On a screen with room nothing here is drawn or moved. Without
; the script these values clip nothing, so the panel shows at its designed height.
[Variables]
PanelScrollY=0
PanelScrollTopPx=0
PanelScrollView=#WindowHeight#
PanelScrollHidden=1
PanelScrollThumbY=0
PanelScrollThumbH=1
PanelScrollUpColor=#MutedColor#
PanelScrollDownColor=#AccentColor#

[MeasurePanelScroll]
Measure=Script
ScriptFile=#@#Scripts\PanelScroll.lua
UpdateDivider=-1

; The scrolling part. Rainmeter draws contained meters relative to this one and clips them
; to its shape, so moving it up and its rectangle down by the same amount scrolls them all;
; clicks outside the rectangle do not reach them. The container itself is never drawn.
[MeterScrollBody]
Meter=Shape
X=0
Y=(-#PanelScrollY#)
Shape=Rectangle 0,(#PanelScrollY#+#PanelScrollTopPx#),#WindowWidth#,#PanelScrollView# | Fill Color 255,255,255,255 | StrokeWidth 0
Group=PanelScroll
DynamicVariables=1
UpdateDivider=-1

; Marks where the scrolled rows end while some are out of sight above.
[MeterScrollEdge]
Meter=Shape
MeterStyle=StyleRule
Y=#PanelScrollTopPx#
Hidden=(#PanelScrollY#=0)
Group=PanelScroll
DynamicVariables=1

; Page up and page down, left of the close button, for a touch screen or a mouse without
; a wheel. Muted at the end they point to.
[MeterScrollUp]
Meter=Shape
X=(#ContentX#+#ContentWidth#-68*#Scale#)
Y=(#TitleRowCenterY#-10*#Scale#)
W=(20*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(20*#Scale#),(20*#Scale#) | Fill Color 0,0,0,1 | StrokeWidth 0
Shape2=Line (6*#Scale#),(12*#Scale#),(10*#Scale#),(8*#Scale#) | Stroke Color #PanelScrollUpColor# | StrokeWidth (1.5*#Scale#)
Shape3=Line (10*#Scale#),(8*#Scale#),(14*#Scale#),(12*#Scale#) | Stroke Color #PanelScrollUpColor# | StrokeWidth (1.5*#Scale#)
Hidden=#PanelScrollHidden#
LeftMouseUpAction=[!CommandMeasure MeasurePanelScroll "Page(-1)"]
MouseActionCursor=1
Group=PanelScroll
DynamicVariables=1
UpdateDivider=-1

[MeterScrollDown]
Meter=Shape
X=(#ContentX#+#ContentWidth#-46*#Scale#)
Y=(#TitleRowCenterY#-10*#Scale#)
W=(20*#Scale#)
H=(20*#Scale#)
Shape=Rectangle 0,0,(20*#Scale#),(20*#Scale#) | Fill Color 0,0,0,1 | StrokeWidth 0
Shape2=Line (6*#Scale#),(8*#Scale#),(10*#Scale#),(12*#Scale#) | Stroke Color #PanelScrollDownColor# | StrokeWidth (1.5*#Scale#)
Shape3=Line (10*#Scale#),(12*#Scale#),(14*#Scale#),(8*#Scale#) | Stroke Color #PanelScrollDownColor# | StrokeWidth (1.5*#Scale#)
Hidden=#PanelScrollHidden#
LeftMouseUpAction=[!CommandMeasure MeasurePanelScroll "Page(1)"]
MouseActionCursor=1
Group=PanelScroll
DynamicVariables=1
UpdateDivider=-1

; Where the visible part is, in the right padding. Passive.
[MeterScrollThumb]
Meter=Shape
X=(#ContentX#+#ContentWidth#+#Padding#/2-#Scale#)
Y=#PanelScrollThumbY#
W=(2*#Scale#)
H=#PanelScrollThumbH#
Shape=Rectangle 0,0,(2*#Scale#),#PanelScrollThumbH#,#Scale# | Fill Color #MutedColor# | StrokeWidth 0
Hidden=#PanelScrollHidden#
Group=PanelScroll
DynamicVariables=1
UpdateDivider=-1
