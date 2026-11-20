# Bundled Chameleon plugin

`Chameleon.dll` 1.6.5.0 for 32-bit and 64-bit Rainmeter, by Socks the Fox, 3-clause BSD License ([socks-the-fox/chameleon](https://github.com/socks-the-fox/chameleon)). The license text ships inside the skin at `Skins/Parallax/@Resources/Licenses/Chameleon-LICENSE.txt` and the attribution is recorded in `NOTICE.txt` beside it. `packaging/release.json` lists this directory under `plugins`, and `tools/Package-Parallax.ps1` adds both files to the `.rmskin` as `Plugins/32bit/Chameleon.dll` and `Plugins/64bit/Chameleon.dll`.

Media uses it for **Album colors** (`Modules/Media/AlbumColors1.inc`): it samples WebNowPlaying's cover file in-process, with no process, network or polling of its own beyond the Media provider cadence.

Provenance: extracted on 2026-11-19 from `Chameleon.zip` (748,534 bytes) attached to upstream release [1.6.5](https://github.com/socks-the-fox/chameleon/releases/tag/1.6.5) (published 2024-12-15); the zip holds the author's example skin `Socks_2.7.5.rmskin`, whose `Plugins/32bit` and `Plugins/64bit` folders are these files, unmodified. Downloaded with the maintainer's approval for a spike; bundled under his instruction to build on the recommended options (2026-11-19). Both files report FileVersion 1.6.5.0 and "© 2015-2024 - Socks the Fox"; neither is Authenticode-signed upstream.

| File | PE machine | Bytes | SHA-256 |
| --- | --- | --- | --- |
| `1.6.5.0/32bit/Chameleon.dll` | x86 | 287,744 | `C5BEA8EF480436CDF4F24B783C99E3412B9BEC07B12F87829E616A541425FF31` |
| `1.6.5.0/64bit/Chameleon.dll` | x64 | 319,488 | `CFC69B9A9FBFCF65A7948F75D75C64A96EBFCD779DA8F04151D00D7012B05217` |

**License status (decided 2026-11-19: ship and ask).** Chameleon's repository is BSD-3, but the DLL statically links the same author's separate [libChameleon](https://github.com/socks-the-fox/libChameleon) repository, which has no license file. The author publishes the binary for use in skins and Rainmeter suites commonly bundle it, but that is an inference, not a grant. The maintainer approved bundling (exception in `AGENTS.md`) and chose to ship it while asking the author to add a license to libChameleon. Request to the author: [socks-the-fox/libchameleon#1](https://github.com/socks-the-fox/libchameleon/issues/1), opened 2026-11-19, awaiting an answer. If the author declines or rules out redistribution, remove this folder and its `release.json` entry: Media then shows theme colors and Media settings says the plugin is missing.

Skin Installer copies the plugin into `%APPDATA%\Rainmeter\Plugins` only when no newer version is installed and never downgrades.

To update: replace both DLLs with a matching upstream release pair, update the version in `packaging/release.json`, this table and `NOTICE.txt`, then rebuild with `tools/Package-Parallax.ps1` and re-run `tools/tests/Test-PackagingTools.ps1`.
