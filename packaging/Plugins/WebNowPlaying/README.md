# Bundled WebNowPlaying plugin

`WebNowPlaying.dll` 2.0.7.0 for 32-bit and 64-bit Rainmeter, by keifufu and Trevor Hamilton, MIT License ([keifufu/WebNowPlaying-Rainmeter](https://github.com/keifufu/WebNowPlaying-Rainmeter)). The license text ships inside the skin at `Skins/Parallax/@Resources/Licenses/WebNowPlaying-LICENSE.txt` and the attribution is recorded in `NOTICE.txt` beside it. `packaging/release.json` lists this directory under `plugins`, and `tools/Package-Parallax.ps1` adds both files to the `.rmskin` as `Plugins/32bit/WebNowPlaying.dll` and `Plugins/64bit/WebNowPlaying.dll`.

Provenance: copied on 2026-09-16 from the plugin archive that the official WebNowPlaying `.rmskin` installer created on the maintainer's machine (`Skins\@Vault\Plugins\WebNowPlaying\2.0.7.0\`), with the maintainer's explicit approval to bundle it. Both files report FileVersion 2.0.7.0 and the copyright "c 2023 - keifufu, Trevor Hamilton" in their version resource; neither is Authenticode-signed upstream.

| File | PE machine | Bytes | SHA-256 |
| --- | --- | --- | --- |
| `2.0.7.0/32bit/WebNowPlaying.dll` | x86 (0x14C) | 53,760 | `026EF3777A68D930713C53EAD538C53947A16931791A51F6712419041B8FCA2F` |
| `2.0.7.0/64bit/WebNowPlaying.dll` | x64 (0x8664) | 53,760 | `1DC535CF9EAC30DBFD85D0D67ADD00A183D0611D260F5144265D25E1712C8D32` |

Why 2.0.7.0: it is the stable 2.x line that Media targets and the version the suite was developed and checked against. Upstream's 3.0.0 builds are prereleases.

Skin Installer copies the plugin into `%APPDATA%\Rainmeter\Plugins` only when no newer version is installed, keeps an archived copy under `Skins\@Vault\Plugins`, and never downgrades. The plugin only reports a player once the WebNowPlaying browser extension or a desktop adapter is installed; those remain separate installs.

To update: replace both DLLs with a matching upstream release pair, update the version in `packaging/release.json`, this table and `NOTICE.txt`, then rebuild with `tools/Package-Parallax.ps1` and re-run `tools/tests/Test-PackagingTools.ps1`. The packager refuses a pair whose version resource disagrees with `release.json`, whose PE machine type does not match its folder, or whose license is missing from the stage.
