# YouTube playback in Media (shelved 2026-11-28)

Goal: Media's Queue, Playlists and spectrum work for YouTube whether it plays on
this PC or on a TV. Shelved, not abandoned: the TV half is built and on `main`.

## On main

- Opt-in TV link paired by TV code: the TV app's up next in the queue drawer
  with clickable rows, and a TV view in the player card with play, pause and next.
- Opt-in direct connection for casts, with a Casts row in Connections.
- The spectrum says the audio is on the TV; local YouTube says its up next is
  not available yet; the Playlists tab says YouTube is not supported yet.

## Not built

- Playlists with a Google sign-in. The official API gives playlists only, not
  live queue or playback control, and an app left in Testing signs out weekly.
- Up next for YouTube playing on this PC: needs a browser extension and a local
  helper. How the helper reaches Rainmeter was left to decide.

## Not tried live

- The direct cast connection, and the casting lines in the queue and spectrum.
- Pair and Forget from Connections; the TV link returning after a Rainmeter
  restart; other TVs.

## Learned

- A cast started from Chrome leaves the casting tab stale once the TV moves on,
  so Next from the tab does not reach the TV. Reading the TV directly is why the
  cast connection exists.
- The TV session does not reveal whether a list is a Mix; the heading stays
  neutral.
- A running TV worker keeps old code after an update unless restarted.

## Pick it up when

A TV is available to try casts, or playlists or local up next are wanted.
