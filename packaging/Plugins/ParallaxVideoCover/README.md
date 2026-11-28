# ParallaxVideoCover (experimental, not bundled)

Source of Media's optional live video cover (`MediaVideoCover=1`, off by default).
Behavior and limits: [Media](../../../docs/modules/Media.md#video-cover-and-cover-preview-in-development-2026-11-27).
Original Parallax code. No binary is in the repository and no release contains one.

| File | What it is |
|---|---|
| `ParallaxVideoCover.cpp`, `Follower.h`, `PageTitle.h` | The plugin: a DWM thumbnail on the skin's window; the video's place read through UI Automation. |
| `Build.ps1` | Builds the 64-bit DLL into a folder under TEMP (`-OutDir` to change it). |
| `Test-Plugin.ps1` | Draws a stand-in window in a separate Rainmeter with its own settings folder. Windows PowerShell 5.1; shows windows on screen while it runs. |

## Dependencies

- **Build:** Visual Studio Build Tools with the C++ workload and a Windows SDK.
  The Rainmeter plugin SDK is not needed: the three functions used are looked up
  in the running `Rainmeter.dll`.
- **Test:** an installed Rainmeter and the built DLL.
- **Run:** Windows' own DWM and UI Automation. To try it in Media, copy the DLL
  into Rainmeter's `Plugins` folder. 32-bit is not built.

```powershell
.\packaging\Plugins\ParallaxVideoCover\Build.ps1
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\Plugins\ParallaxVideoCover\Test-Plugin.ps1
```
