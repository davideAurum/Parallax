; Cached one-shot metadata only. Controllers explicitly Run on model/both load
; and user refresh. The entrypoint supplies its fixed IONameFinishAction target.
[MeasureIOModelQuery]
Measure=Plugin
Plugin=RunCommand
Program=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
StartInFolder=#@#Modules\IO\
Parameter=-NoLogo -NoProfile -NonInteractive -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); try { & ([ScriptBlock]::Create([IO.File]::ReadAllText('DriveModels.ps1.txt'))) } catch { [Console]::WriteLine('IO_MODELS_V1'); [Console]::Write('UNAVAILABLE') }"
State=Hide
OutputType=UTF8
Timeout=12000
UpdateDivider=1
FinishAction=[!UpdateMeasure MeasureIOModelQuery]#IONameFinishAction#
