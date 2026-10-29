# Launch, traction and money

This file covers where to announce the beta, how to tell whether anyone is using Parallax, and what charging for it would involve. It sits beside [ROADMAP.md](ROADMAP.md), which owns what must be true before each release. Written 2026-10-28. Third-party rules quoted here (Spotify, community norms, platform terms) were checked that day. They change, so recheck them before acting on any of them.

## Positioning

ModernGadgets, the well-known dense monitoring suite, was archived in 2022. Parallax is an original, actively maintained suite in that niche. Credit ModernGadgets as the visual inspiration, as [`NOTICE.txt`](../Skins/Parallax/@Resources/Licenses/NOTICE.txt) already does. Don't make its name the headline, and don't suggest it endorses Parallax.

## Where to post, in waves

Announce in waves, not everywhere on day one. A wave brings most of its downloads in its first few days, and each later wave deserves a better build. A release that is never announced gets almost no discovery from GitHub alone.

**Wave 1: soft launch (`0.2.0-beta.1`).** The goal is 5–20 testers on hardware other than the maintainer's.

- **Rainmeter Forums**, on the board for sharing creations. These are the most technical and forgiving readers and write the best bug reports.
- **The unofficial r/Rainmeter Discord**, which [rainmeter.net/discover](https://rainmeter.net/discover) links to, in its showcase area.

**Wave 2: visual launch (beta.2–3, after the first round of fixes).**

- **DeviantArt.** The deviation is one polished full-desktop preview image, with the `.rmskin` attached or linked to the GitHub release. Submit it to the Rainmeter groups and tag it well.
- **r/desktops.** Post the whole desktop and put the link in a comment. Since 2023, r/Rainmeter has mostly been a help forum and has pointed suite posts to r/desktops, DeviantArt, the forums and Discord. Read its current rules before posting there.
- **VisualSkins** (curated; contact them) and the **WinCustomize** Rainmeter gallery.
- **Discord again:** an update to the Wave 1 post, with the new screenshots.
- **A Parallax Discord server: not yet.** A server needs moderating, and an empty one looks abandoned. Use GitHub Discussions until users ask for a chat space.

**Wave 3: the hardware-monitoring niche (beta.3+ or RC).**

- **The HWiNFO forum**, which has threads for third-party skins. Parallax reads HWiNFO exports.
- The software sections of **Linus Tech Tips** and **Overclock.net**.
- A 30–60 second demo video (YouTube, Shorts). At RC or 1.0, contact desktop-customization YouTubers.

**Everywhere, from the start:**

- GitHub repository topics: `rainmeter`, `rainmeter-skin`, `rainmeter-suite`, `system-monitor`, `windows-customization`.
- A repository social-preview image.
- The same three or four screenshots and a 10-second GIF on every venue.

**Don't** paste identical text across venues, and don't argue with critics.

## Running the beta

Triage once or twice a week, not on demand. Label each issue *confirmed*, *needs info*, *after 1.0* or *won't fix*, and batch fixes into the next `beta.N`. Answering feature requests with "after 1.0" is what keeps this a hobby. Record each tester's machine in the hardware table in [ROADMAP.md](ROADMAP.md#stage-2-before-beta1-010-alphan).

## Measuring traction without telemetry

Parallax collects nothing, and that stays true. The signals below are public or come from GitHub's own counters:

- **Package downloads:** the `.rmskin` asset's count on each release.
- **The update-feed count, a rough measure of active installs.** Each installed copy with Global Settings ▸ Updates ▸ Auto check on fetches `parallax-update.json` from the Latest release about once a day ([UPDATES.md](UPDATES.md)). The daily rise in that asset's count is a rough count of installs that are actually running. It includes the maintainer's own copies, and it misses copies with Auto check off.

  ```powershell
  gh api repos/davideAurum/Parallax/releases --jq '.[] | {tag: .tag_name, assets: [.assets[] | {name, download_count}]}'
  ```

  Baseline on 2026-10-28: 2–6 package downloads per release, almost all the maintainer's.
- **Other signals:** stars, DeviantArt favourites and downloads, forum replies, and issues opened by strangers.

**Set thresholds before launch, not after.** A starting proposal, to revisit:

- After 60 days: at least 100 downloads, feedback from at least 10 strangers, and at least one person asking how to support the project means it's worth more effort.
- Below that, Parallax stays a personal hobby, which is a fine outcome.

## If you want to charge

### A ladder

Take each step only if the one before it showed demand.

1. **A tip link at beta.1** (Ko-fi, GitHub Sponsors or similar), in the README, release notes, DeviantArt and forum posts. Optionally add an unobtrusive link in Global Settings, but no nag screens. It costs nothing, and the community won't object.
2. **Pay-what-you-want with a $0 minimum** (Gumroad or itch.io) after 1.0, alongside the free GitHub download.
3. **A free core plus paid extras**, such as theme and preset packs or alternative layouts. The core stays MIT on GitHub.
4. **Fully paid: not recommended**, for the reasons below.

### What to plan for

- **Community norms.** Selling skins is frowned on in the Rainmeter community ([forum thread](https://forum.rainmeter.net/viewtopic.php?p=204663)). Paid suites do exist on Gumroad at about $1–$15, with sales from single digits to a few dozen ([example](https://99villages.gumroad.com/l/LFtC), [example](https://aidendrew.gumroad.com/l/SenjaSuite-Rainmeter)). Expect tips, not income.
- **No copy protection is possible.** Skins are plain text, so a buyer can share them. A price is something supporters choose to pay, not a lock.
- **The license.**
  - MIT already allows anyone to redistribute Parallax, and even to sell it. Every release made under MIT stays MIT.
  - Future versions could use another license, but expect backlash.
  - Copyright in largely AI-written code is unsettled in the US. The Copyright Office protects human-authored contributions, so a restrictive license may be hard to enforce. Get advice before relying on one.
- **Third-party pieces** ([NOTICE.txt](../Skins/Parallax/@Resources/Licenses/NOTICE.txt)).
  - IBM Plex (OFL) can ship inside paid software, but can't be sold on its own, and its license must ship with it.
  - WebNowPlaying (MIT) and Lucide (ISC) can be bundled as long as their notices stay.
  - ModernGadgets' released skin is CC BY-NC-SA 3.0, which forbids commercial use and requires derivatives to share alike ([repository](https://github.com/raiguard/ModernGadgets)). That matters only if any of it is reused. Parallax uses none of its code or assets. Keep that true and recorded, and keep its name out of sales copy.
- **Spotify.**
  - Spotify's Developer Terms restrict commercial use. Spotify staff have said that even showing cover art on a commercial site is not allowed ([thread](https://community.spotify.com/t5/Spotify-for-Developers/General-Inquiry-Regarding-Commercial-Use-of-Spotify-Web-API/td-p/7347501)).
  - Development Mode apps need a Premium owner and allow 5 users each ([February 2026 guide](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide), [July 2026 update](https://developer.spotify.com/blog/2026-07-23-web-api-quota-updates)).
  - So never put the Spotify queue behind a paywall, consider leaving it out of any paid offering, and read [developer.spotify.com/terms](https://developer.spotify.com/terms) before charging.
- **The name.** "Parallax" is a common product name. Do a quick trademark search before selling under it.
- **Money administration** (general considerations, not tax advice).
  - Prefer a sales platform that acts as merchant of record and handles sales tax and VAT; confirm its current terms.
  - Tips and sales are taxable income, so keep simple records.
  - See a tax professional if it becomes regular income. Tip-sized amounts don't need a business entity.
- **An employer.** Outside-work and IP policies can apply to paid side projects. Check them first.
- **Support load.** Paying users expect fixes. Publish a short support policy: best effort, a reply within about a week, refunds through the platform.
- **Delivery.** The built-in updater reads the public GitHub releases, so paid extras would need separate delivery through the platform's download or email. That is another reason to keep the core free.

## Sources

Checked 2026-10-28:

- ModernGadgets license and archive status: <https://github.com/raiguard/ModernGadgets>
- Spotify Development Mode: <https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide>, <https://developer.spotify.com/blog/2026-07-23-web-api-quota-updates>
- Spotify and commercial use (staff reply): <https://community.spotify.com/t5/Spotify-for-Developers/General-Inquiry-Regarding-Commercial-Use-of-Spotify-Web-API/td-p/7347501>
- Rainmeter community and selling: <https://forum.rainmeter.net/viewtopic.php?p=204663>
- Rainmeter distribution guidance and community links: <https://docs.rainmeter.net/manual/distributing-skins/>, <https://rainmeter.net/discover>
- r/Rainmeter's 2023 change to a help-focused subreddit (mirror): <https://reddit.fsky.io/r/Rainmeter>
