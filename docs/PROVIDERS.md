# Providers and constraints

Research checked 2026-09-11 against primary sources. Optional integrations must remain optional for distribution.

| Area | Baseline | Optional extension |
| --- | --- | --- |
| CPU | Native CPU total/per-core | UsageMonitor top processes; HWiNFO clocks/temperature/power |
| RAM | Native PhysicalMemory | UsageMonitor process memory |
| GPU | Carefully scoped GPU counters, with explicit metric semantics | HWiNFO mapped adapter sensors |
| Network | Native NetIn/NetOut with selected interface | Future opt-in process attribution |
| Disk | FreeDiskSpace; PhysicalDisk/LogicalDisk transfer counters | HWiNFO temperature/SMART |
| Media | WebNowPlaying metadata and supported controls | Spotify Web API queue; explicit local Windows-session source detection |
| Visualizer | Built-in AudioLevel mixed output capture | Future custom process capture |

Native measure sources: [CPU](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/cpu.html), [memory](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/memory.html), [network](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/net.html), [disk capacity](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/measures/freediskspace.html).

[UsageMonitor](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/usagemonitor.html) polls categories once per second independently of skin cadence and shares workers. Its GPU aggregate is not automatically a 0-100% whole-adapter metric; Task Manager uses the [busiest engine](https://devblogs.microsoft.com/directx/gpus-in-the-task-manager/). Process I/O includes network/device/file activity and must not be called disk throughput; use disk counters for that purpose.

[HWiNFO registry/Gadget exports](https://github.com/rainmeter/rainmeter-docs/blob/master/source/tips/hwinfo.html) can be read by Rainmeter without a separate plugin or Shared Memory. Map sensor labels as well as indices. The non-Pro shared-memory interface has a 12-hour limit; Pro removes that limit. Check current [licensing](https://www.hwinfo.com/licenses/) and redistribution rights before release. Minimize sensor polling, particularly EC/SMI/SMART sources with documented [latency issues](https://hwinfo.com/forum/threads/known-issues.398/).

[WebNowPlaying](https://wnp.keifufu.dev/rainmeter/usage) provides metadata/buttons and supports [desktop players](https://wnp.keifufu.dev/desktop-players), including Spotify Desktop without Spicetify. Not every player supports every command. Its documented interface does not expose Spotify's queue.

Parallax's optional source observer identifies Spotify when one observed Windows session matches WNP's title, artist and playback state. Ambiguous or stale results retain the generic Windows label. It starts only through Media Settings, samples every two seconds, and keeps bounded metadata in private local runtime storage; it uses no Spotify credentials, network request or playback action. Stop controls only this observer. It remains separate from the authenticated queue provider and adds overhead only when explicitly started. See [Media's source detection contract](modules/Media.md#optional-spotify-source-detection) for lifecycle, expiry and correlation limits.

Spotify exposes a [queue endpoint](https://developer.spotify.com/documentation/web-api/reference/get-queue). A native helper should use [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow), explicit loopback [redirects](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri), minimal scopes and protected per-user storage. Honor [rate limits](https://developer.spotify.com/documentation/web-api/concepts/rate-limits). Current [quota rules](https://developer.spotify.com/documentation/web-api/concepts/quota-modes) require Premium for development app owners and allow only five allowlisted users. Extended quota applications have organizational eligibility requirements. Public distribution cannot assume a shared client ID works for all users; user-supplied application setup is an advanced option. Spotify-connected features need a release policy review, including restrictions on synchronizing recordings with visual media.

[AudioLevel](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/plugins/audiolevel.html) analyzes device audio. Use one parent FFT, a bounded number of bands and a standalone skin. The visualizer is a generic audio spectrum display, not an audio equalization DSP or a guarantee of Spotify-only capture.
