# Lucide Media icons

The user selected these Lucide icons on 2026-09-12:

| Role | Icon |
| --- | --- |
| Song | [music](https://lucide.dev/icons/music) |
| Artist | [user-round-group](https://lucide.dev/icons/user-round-group) |
| Album | [disc-3](https://lucide.dev/icons/disc-3) |
| Play | [play](https://lucide.dev/icons/play) |
| Play hover | [play-off](https://lucide.dev/icons/play-off) |
| Pause | [pause](https://lucide.dev/icons/pause) |
| Pause hover | step-forward, supplied by the user as an SVG data URL |
| Previous track | rewind, supplied by the user as an SVG data URL |
| Next track | fast-forward, supplied by the user as an SVG data URL |
| Expand Queue | list-plus, supplied by the user as an SVG data URL |
| Collapse Queue | list-minus, supplied by the user as an SVG data URL |
| Media title | monitor-play, supplied by the user as an SVG data URL |
| Current player below Media title | audio-lines, supplied by the user as an SVG data URL |

The first six unmodified upstream SVGs and the full upstream LICENSE are retained here from
[Lucide revision a79b2d131dab2bf20cb224bd0937b439a9c4fa99](https://github.com/lucide-icons/lucide/tree/a79b2d131dab2bf20cb224bd0937b439a9c4fa99).
Lucide uses the ISC license; its music icon is derived from Feather and carries
the additional MIT notice for Cole Bemis. Both notices are included in LICENSE.
The other seven files preserve the exact decoded user-supplied SVGs.

`PlayerMeters.inc` adapts the metadata SVG geometry into native Rainmeter Shape meters:
the 24-unit coordinates and 2-unit strokes scale uniformly by `14 * Scale / 24`,
`currentColor` maps to `MutedColor`, and the paths retain round caps/joins.
Disc 3's cubic curves are translated exactly into Rainmeter's endpoint-first
CurveTo notation; User Round Group's circular arcs reverse the SVG sweep flag
to match Rainmeter's convention. `TransportIcons.inc` fits a 24-pixel icon into
each existing 28-by-26-pixel control, scaled with the suite. Transport strokes
use AccentColor when supported and MutedColor when unavailable. The rewind and
fast-forward artwork represents the existing previous/next track commands.
Hover fills the supported previous/next icons with AccentColor. The center
control shows Play Off on Play hover and Step Forward on Pause hover; these
are visual changes only, and clicking still performs the play/pause action.
`Common.inc` fits List Plus/Minus into a 14-pixel canvas centered in an 18-pixel
queue toggle. The vertical plus stroke is omitted when expanded, matching
List Minus. `Header.inc` scales Monitor Play with `TitleIconSize / 24` and
centers it beside the static Media Player title. Audio Lines uses six vertical
native lines with the supplied round caps, scaling by `14 * Scale / 24`, beside
the body-font detected player name below the title. Both icons use `MediaColor`.
There is no new runtime dependency. The source SVGs are kept
for provenance rather than loaded by Rainmeter.

SHA256 of the unmodified upstream files:

- music.svg: `8721B8A3594219C1313C4083049E5A5C049F49C47B1CD93FDB61D52A0803E42B`
- disc-3.svg: `93B3102C857A46D590FFC268A8D9EA740ABF9BFB30F76DE42B9899E34BBBA438`
- user-round-group.svg: `A37D7C9FFB7A17E6F4CF70CA4706DA164B664127405F756B8CBDA3C7D6A188F4`
- play.svg: `D7C34786135922A92B6896F6C2384CEEB0346AFBF6041DC79982011411409833`
- pause.svg: `F122EC4EA7F5693A0B1BAAFA9C708B53980DC87B4AACB297C6E6F71C1A4C115C`
- play-off.svg: `5179F07B1D726103F7C874D4232C39CDC756ECA6349D5C68F40ED4A8D7B44BCF`
- LICENSE: `B495047BD93A9B06913511076F504DABA17D5BBEB3E0650F3BB53A4220329C57`

SHA256 of the decoded user-supplied SVGs:

- rewind.svg: `A6A6F676FAB62A138995A504AC397207BF3192C82E76CD84700D085235D079CC`
- fast-forward.svg: `A2A08FA7C99C154D625389C8BEF98F250DB3D4DA574370DB76573E192B5A9B34`
- list-plus.svg: `EEB7813436284D56799B44803FF2145C44DE69725CBCE18298128D22ABD65828`
- list-minus.svg: `C61B3AFC48B7CDA4EF4B47155A5386D6E03FA16CB6F251D88C6D0E385C9C2FD1`
- monitor-play.svg: `D3C350E15AE2CE472BEEF507DC5697044BDFB0D0D3C0AA8235530DFBD8D559BC`
- step-forward.svg: `ECBD311F6389C6043CF1B10AB8E7B852629B7D2EC8B1511A3655C26761D3952F`
- audio-lines.svg: `C8CDF2A5EA1678255E220D9F91CD18ED78476F7C423E4EE80AADDAEDA63B11B3`
