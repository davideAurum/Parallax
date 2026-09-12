; Use the hover gear for section visibility, clock/date and timer controls.
; For names or custom formats, use Edit names / advanced, save, then Apply saved edits.
; Labels are plain text. Durations are whole seconds from 1 to 604800 (7 days).
; Slots keep their state when renamed; changing Seconds resets just that slot.
; Running timers continue while Rainmeter is closed or the computer is asleep.
[Variables]
Columns=1
PanelHeight=356
; 1 shows a section; 0 hides it and closes its space. Countdown state is retained.
ChronometerShowClock=1
ChronometerShowUptime=1
ChronometerShowEvent=1
ChronometerShowTimers=0
ChronometerClockFormat=%I:%M:%S %p
ChronometerDateFormat=%A, %d %B %Y
ChronometerList1Name=Focus
ChronometerList1Timer1Label=Deep work
ChronometerList1Timer1Seconds=1500
ChronometerList1Timer2Label=Short break
ChronometerList1Timer2Seconds=300
ChronometerList1Timer3Label=Long break
ChronometerList1Timer3Seconds=900
ChronometerList1Timer4Label=Review
ChronometerList1Timer4Seconds=600
ChronometerList2Name=Daily
ChronometerList2Timer1Label=Tea
ChronometerList2Timer1Seconds=240
ChronometerList2Timer2Label=Stretch
ChronometerList2Timer2Seconds=600
ChronometerList2Timer3Label=Walk
ChronometerList2Timer3Seconds=1200
ChronometerList2Timer4Label=Reading
ChronometerList2Timer4Seconds=1800
ChronometerList3Name=Custom
ChronometerList3Timer1Label=Timer one
ChronometerList3Timer1Seconds=60
ChronometerList3Timer2Label=Timer two
ChronometerList3Timer2Seconds=300
ChronometerList3Timer3Label=Timer three
ChronometerList3Timer3Seconds=600
ChronometerList3Timer4Label=Timer four
ChronometerList3Timer4Seconds=3600
