# Does the plugin draw on a real Rainmeter skin window, survive repaints
# and move with the window? Windows PowerShell 5.1. Runs a separate Rainmeter
# with its own settings folder under TEMP; the installed one and its settings are
# not touched. Shows a test skin and an animated test window for about 20 s.
param(
    [string]$Dll = (Join-Path ([IO.Path]::GetTempPath()) 'parallax-video-cover\plugin\ParallaxVideoCover.dll'),
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe')
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Dll)) { throw 'Build the plugin first (Build.ps1).' }
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices; using System.Text; using System.Windows.Forms;
public class Moving : Form {
  int frame; readonly Timer timer = new Timer();
  public Moving(string title, Point at) { Text = title; StartPosition = FormStartPosition.Manual; Location = at; ClientSize = new Size(480, 270); TopMost = true; DoubleBuffered = true;
    timer.Interval = 100; timer.Tick += delegate { frame++; Invalidate(); }; timer.Start(); }
  protected override void OnPaint(PaintEventArgs e) { e.Graphics.Clear(Color.FromArgb(40, (frame * 23) % 256, 200)); e.Graphics.FillRectangle(Brushes.White, (frame * 31) % 480, 0, 60, 270); }
}
// A window with a moving "video" panel inside a still red page.
public class Page : Form {
  public readonly Panel Video = new Panel(); int frame; readonly Timer timer = new Timer();
  public Page(string title, Point at) { Text = title; StartPosition = FormStartPosition.Manual; Location = at; ClientSize = new Size(480, 360); TopMost = true; BackColor = Color.FromArgb(200, 30, 30);
    Video.Name = "videoBox"; Video.Bounds = new Rectangle(40, 50, 320, 180); Controls.Add(Video);
    timer.Interval = 100; timer.Tick += delegate { frame++; Video.BackColor = Color.FromArgb(20, 60 + (frame * 23) % 190, 220); }; timer.Start(); }
}
public static class Screen0 {
  public delegate bool P(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L,T,Rt,B; }
  [DllImport("user32")] static extern bool EnumWindows(P p, IntPtr l);
  [DllImport("user32", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32")] public static extern bool SetProcessDPIAware();
  [DllImport("user32")] static extern IntPtr GetDC(IntPtr h);
  [DllImport("user32")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
  [DllImport("gdi32")] static extern bool BitBlt(IntPtr d,int x,int y,int w,int h,IntPtr s,int sx,int sy,int rop);
  public static IntPtr ByTitle(string t){ IntPtr f=IntPtr.Zero; EnumWindows((h,l)=>{ var s=new StringBuilder(1024); GetWindowText(h,s,1024); if(string.Equals(s.ToString(),t,StringComparison.OrdinalIgnoreCase)){f=h;return false;} return true;},IntPtr.Zero); return f; }
  public static int[] Grab(int x, int y, int w, int h) {
    using (var b = new Bitmap(w, h, PixelFormat.Format32bppRgb)) {
      using (var g = Graphics.FromImage(b)) { IntPtr s = GetDC(IntPtr.Zero), d = g.GetHdc(); BitBlt(d, 0, 0, w, h, s, x, y, 0x00CC0020 | 0x40000000); g.ReleaseHdc(d); ReleaseDC(IntPtr.Zero, s); }
      var list = new System.Collections.Generic.List<int>();
      for (int j = 3; j < h; j += 7) for (int i = 3; i < w; i += 7) list.Add(b.GetPixel(i, j).ToArgb() & 0xFFFFFF);
      return list.ToArray(); } }
}
'@
[void][Screen0]::SetProcessDPIAware()

$run = Join-Path ([IO.Path]::GetTempPath()) ('PxPlugin-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$skins = Join-Path $run 'Skins'
$config = Join-Path $skins 'PluginTrial'
New-Item -ItemType Directory -Force $config, (Join-Path $run 'Plugins') | Out-Null
Copy-Item -LiteralPath $Dll -Destination (Join-Path $run 'Plugins\ParallaxVideoCover.dll')
$title = 'Parallax plugin trial source'
$ini = Join-Path $config 'Trial.ini'
$pageTitle = 'Parallax plugin trial page'
Set-Content -LiteralPath $ini -Encoding Unicode -Value @"
[Rainmeter]
Update=250

[MeterBack]
Meter=Shape
Shape=Rectangle 0,0,300,330,12 | Fill Color 40,40,44,255 | StrokeWidth 0

; Changes every update, so the skin keeps repainting under the picture.
[MeasureCount]
Measure=Calc
Formula=(Counter % 100)

[MeterCount]
Meter=String
MeasureName=MeasureCount
X=10
Y=305
FontColor=255,255,255
Text=repaint %1

[MeasureCover]
Measure=Plugin
Plugin=ParallaxVideoCover
DynamicVariables=1
Show=1
X=10
Y=10
Size=280
Radius=10
Zoom=0
Player=YouTube
AllowPlayer=YouTube
SourceTitle=$title

; Another player: nothing may be drawn here.
[MeasureOther]
Measure=Plugin
Plugin=ParallaxVideoCover
DynamicVariables=1
Show=1
X=310
Y=10
Size=100
Player=Spotify
AllowPlayer=YouTube
SourceTitle=$title

[MeterOtherBack]
Meter=Shape
X=300
Y=0
Shape=Rectangle 0,0,120,120 | Fill Color 40,40,44,255 | StrokeWidth 0

; Cuts one element out of a window, as for the video in the YouTube app.
[MeterPageBack]
Meter=Shape
X=0
Y=340
Shape=Rectangle 0,0,300,300 | Fill Color 40,40,44,255 | StrokeWidth 0

[MeasurePage]
Measure=Plugin
Plugin=ParallaxVideoCover
DynamicVariables=1
UpdateDivider=1
Show=1
X=10
Y=350
Size=280
Zoom=1
Radius=10
SourceTitle=$pageTitle
SourceElement=id:videoBox
"@
Set-Content -LiteralPath (Join-Path $run 'Rainmeter.ini') -Encoding Unicode -Value "[Rainmeter]`r`nSkinPath=$skins\`r`nDisableVersionCheck=1`r`nDisableAutoUpdate=1`r`nLogging=1`r`nTrayIcon=0`r`n`r`n[PluginTrial]`r`nActive=1`r`nWindowX=80`r`nWindowY=80`r`nAlwaysOnTop=2`r`nSavePosition=0`r`n"

$rainmeter = $null; $source = $null; $page = $null
$script:failures = 0
function Pump([int]$ms) { $w = [Diagnostics.Stopwatch]::StartNew(); while ($w.ElapsedMilliseconds -lt $ms) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10 } }
function Check([bool]$ok, [string]$what) { if (-not $ok) { $script:failures++ }; '{0}  {1}' -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $what }
# The cover area's own points: how many are not the skin's background, and how often they changed.
function Watch-Cover([IntPtr]$skin, [int]$looks = 8) {
    $r = New-Object Screen0+R; [void][Screen0]::GetWindowRect($skin, [ref]$r)
    $changed = 0; $picture = 0; $last = $null
    for ($i = 0; $i -le $looks; $i++) {
        $now = [Screen0]::Grab($r.L + 12, $r.T + 82, 276, 136)   # the fitted 16:9 band
        $picture = [Math]::Max($picture, @($now | Where-Object { $_ -ne 0x28282C }).Count)
        if ($null -ne $last -and ($now -join ',') -ne ($last -join ',')) { $changed++ }
        $last = $now; Pump 250
    }
    [pscustomobject]@{ Picture = $picture; Points = $last.Count; Changed = $changed; Looks = $looks; At = "$($r.L),$($r.T)" }
}

try {
    $source = New-Object Moving($title, (New-Object Drawing.Point(620, 80)))
    $source.Show()
    $rainmeter = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f (Join-Path $run 'Rainmeter.ini')) -WorkingDirectory $run -PassThru
    $skin = [IntPtr]::Zero
    for ($i = 0; $i -lt 40 -and $skin -eq [IntPtr]::Zero; $i++) { Pump 250; $skin = [Screen0]::ByTitle($ini) }
    if ($skin -eq [IntPtr]::Zero) { throw 'The test skin window did not appear.' }
    Pump 1500
    $a = Watch-Cover $skin
    Check ($a.Picture -gt $a.Points / 2 -and $a.Changed -ge 6) "draws on the skin window and updates across repaints: picture $($a.Picture)/$($a.Points), changed $($a.Changed)/$($a.Looks)"
    # Move the window and look at once, without giving anything time to follow.
    [void][Screen0]::SetWindowPos($skin, [IntPtr]::Zero, 120, 430, 0, 0, 0x15)
    Start-Sleep -Milliseconds 50
    $r = New-Object Screen0+R; [void][Screen0]::GetWindowRect($skin, [ref]$r)
    $moved = [Screen0]::Grab($r.L + 12, $r.T + 82, 276, 136)
    $n = @($moved | Where-Object { $_ -ne 0x28282C }).Count
    Check ($r.L -eq 120 -and $n -gt $moved.Count / 2) "is already there 50 ms after the window moves: picture $n/$($moved.Count)"
    $b = Watch-Cover $skin
    Check ($b.Changed -ge 6) "keeps updating at the new place $($b.At): changed $($b.Changed)/$($b.Looks)"
    $r = New-Object Screen0+R; [void][Screen0]::GetWindowRect($skin, [ref]$r)
    $other = [Screen0]::Grab($r.L + 314, $r.T + 14, 92, 92)
    $n = @($other | Where-Object { $_ -ne 0x28282C }).Count
    Check ($n -eq 0) "draws nothing for a player that is not allowed: picture $n/$($other.Count)"
    $source.Close(); $source = $null
    Pump 1500
    $c = Watch-Cover $skin 4
    Check ($c.Picture -eq 0) "goes when the source window closes: picture $($c.Picture)/$($c.Points)"
    $rainmeter.Refresh()
    Check (-not $rainmeter.HasExited) 'the test Rainmeter is still running'
    # The element inside a window: only it may show, and it must be followed.
    $page = New-Object Page($pageTitle, (New-Object Drawing.Point(620, 380)))
    $page.Show()
    # A Rainmeter on a scaled screen draws everything, the picture included, larger:
    # the page section sits at 16,356 of a skin 420 units wide.
    function Look-Part { $r = New-Object Screen0+R; [void][Screen0]::GetWindowRect($skin, [ref]$r); $k = ($r.Rt - $r.L) / 420.0
        [Screen0]::Grab($r.L + [int](16 * $k), $r.T + [int](356 * $k), [int](268 * $k), [int](268 * $k)) }
    function Count-Red($px) { @($px | Where-Object { (($_ -shr 16) -band 255) -gt 150 -and (($_ -shr 8) -band 255) -lt 80 }).Count }
    function Count-Video($px) { @($px | Where-Object { (($_ -shr 16) -band 255) -lt 60 -and ($_ -band 255) -gt 180 }).Count }
    Pump 4000
    $a = Look-Part; Pump 400; $b = Look-Part
    Check ((Count-Video $a) -gt $a.Count * 0.9 -and (Count-Red $a) -eq 0 -and ($a -join ',') -ne ($b -join ',')) "draws only the element, moving: video $(Count-Video $a)/$($a.Count), page $(Count-Red $a)"
    $page.Video.Bounds = New-Object Drawing.Rectangle(150, 150, 240, 135); Pump 1500
    $c = Look-Part
    Check ((Count-Video $c) -gt $c.Count * 0.9 -and (Count-Red $c) -eq 0) "follows the element when it moves and resizes: video $(Count-Video $c)/$($c.Count), page $(Count-Red $c)"
    $page.WindowState = 'Minimized'; Pump 1500
    $d = Look-Part
    Check ((Count-Video $d) -eq 0) "draws nothing while that window is minimized: video $(Count-Video $d)"
    $page.WindowState = 'Normal'; Pump 2500
    $e = Look-Part
    Check ((Count-Video $e) -gt $e.Count * 0.9) "comes back after restoring: video $(Count-Video $e)/$($e.Count)"
    $page.Close(); $page = $null; Pump 1500
    $f = Look-Part
    Check ((Count-Video $f) -eq 0) "goes when that window closes: video $(Count-Video $f)"
    $rainmeter.Refresh()
    Check (-not $rainmeter.HasExited -and $rainmeter.Responding) 'the test Rainmeter is still running and responding'
} finally {
    if ($page) { $page.Close() }
    if ($source) { $source.Close() }
    if ($rainmeter -and -not $rainmeter.HasExited) { Stop-Process -InputObject $rainmeter -Force; $null = $rainmeter.WaitForExit(5000) }
    $log = Join-Path $run 'Rainmeter.log'
    if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log | Where-Object { $_ -match 'ERRO|WARN' } | Select-Object -First 8 }
    Remove-Item -LiteralPath $run -Recurse -Force -ErrorAction SilentlyContinue
}
"failures: $($script:failures)"
if ($script:failures) { exit 1 }
