# Spindle

A macOS desktop widget shaped like a 2000s-era portable music player. It shows
whatever is currently playing, from **any** app, not just Music — the album cover
filling the screen, the track title laid over it, and a working scroll wheel.

It is not a WidgetKit widget. It is a borderless panel that sits pinned to your
wallpaper *behind* your windows, sized to the macOS widget grid so it lines up
with the stock ones. It appears on every Space, and you can drag it anywhere.

> **Not affiliated with, endorsed by, or connected to Apple Inc.** Spindle is an
> independent tribute to a class of hardware, not a copy of any product, and all
> artwork in this repository is original. Product names referenced anywhere in
> this project belong to their respective owners.

![Four of the nine skins](docs/skins.png)

---

## Install

1. Download **Spindle-x.y.z.zip** from the repo, the latest release will be there.
2. Unzip it and drag **Spindle** into your **Applications** folder.
3. Double-click it. **macOS will refuse to open it the first time**  (see below.)

### First launch: "Apple could not verify…"

This app is not signed with a paid Apple Developer ID, so macOS blocks it on
first launch. Nothing is wrong with the download.

To open it anyway:

1. Double-click the app. A dialog says it could not be verified. Click **Done**.
2. Open **System Settings → Privacy & Security**.
3. Scroll down to **Security**. There is a line saying *"Spindle" was
   blocked to protect your Mac*. Click **Open Anyway**.
4. Confirm with Touch ID or your password, then click **Open**.

You only do this once. macOS remembers the app afterwards.

> The exact wording moves around between macOS versions, but the **Open
> Anyway** button in Privacy & Security is always where it lives.

If you would rather do it in one command instead:

```bash
xattr -dr com.apple.quarantine "/Applications/Spindle.app"
```

Once it launches, the widget appears on the middle-left of your main display
and a dial icon appears in the menu bar.

**Requires macOS 14 or later.** Apple Silicon and Intel.

---

## Permissions

**Automation, for the menu, and as a fallback.** Browsing Playlists, Artists,
Albums or Songs reads them out of Music.app, which needs this. Playback control,
shuffle and repeat all go through the system media controls, which need no
permission at all. If macOS prompts, allow it, or set it manually:

> System Settings → Privacy & Security → Automation → **Spindle** → enable
> **Music** / **Spotify**

The app does **not** need Screen Recording, Accessibility, Full Disk Access, or
a network connection. It never talks to the internet.

---

## Controls

| Control | Now Playing | In a menu |
| --- | --- | --- |
| **Turn the wheel** | Volume | Moves the highlight |
| **Centre button** | Play / pause | Select |
| **MENU (top)** | Opens the menu | Back up one level |
| **Right of wheel** | Next track | Next track |
| **Left of wheel** | Previous track | Previous track |
| **Bottom of wheel** | Opens whatever is playing | Opens whatever is playing |
| **Click the screen** | Opens the menu | Selects that row |
| **Drag the scrubber** | Jumps to that point | — |

Turning the wheel means either dragging your cursor around the ring, or just
scrolling anywhere on the widget — both do the same thing. Each step ticks; the
sound is synthesised, and both the tick and its volume are adjustable.

**Drag it anywhere** to move it. **⌘-drag** works even with **Lock position** on.

The wheel is faithful but not obvious, so the screen is a control too: click a
menu row to choose it, click Now Playing to open the menu. Nothing is
wheel-only. Volume has a bar you can drag rather than only a gesture, and the
scrubber seeks when you drag it.

Long track titles scroll across the screen, but at a deliberate crawl
(5pt/second, with a three second pause at each end), the widget lives on the
desktop all day, and text drifting in the corner of your eye is a distraction.

### The menu

MENU opens the widget's own menu rather than a settings window, and walks back
up a level at a time:

```
Spindle
 ├ Music ▸ Playlists / Artists / Albums / Songs ▸ … ▸ a track
 ├ Shuffle          Off · Songs · Albums
 ├ Repeat           Off · All · One
 ├ Settings
 └ Now Playing
```

Opening a playlist puts **Play Playlist** above its tracks, so you can start the
whole thing without picking one out of it. **Songs** has the same row as **Play
All**, meaning the whole library. Artists and albums do not: those lists are
grouped on this side, and there is no real container for Music to queue from.

Picking a single song plays that song out of your own playlist and keeps the rest
of that playlist going behind it. Nothing is copied and nothing is added to your
library.

### The menu bar icon

Because MENU belongs to the widget's own menu, the app's adjustments live in the
menu bar: show/hide, shuffle, repeat, the wheel and screen toggles, **Launch at
Login**, Settings and Quit. Nothing in the widget is unreachable if the click
wheel is behind a window.

### Settings

Everything you change is written straight to `UserDefaults` as you change it,
so it is what the widget uses from then on. There is no separate apply step and
nothing resets on update.

**Width** is in points, defaulting to **164pt**, with a four-step preset ladder
— Small, Medium, Large, Huge. Small and Huge line up with the macOS small and
medium widget grid. **Corner radius** defaults to 26pt, and its ceiling moves
with the width: a body cannot round its corners past the screen sitting inside
it without cutting the corners off the screen.

**Transparency** fades the whole widget, artwork included, it is applied to the
window itself, so nothing is left stubbornly opaque. It stops at 80% so the
widget can never be made invisible and impossible to find again.

**Black & white album cover** desaturates just the cover art; the title text and
the body colour are unaffected, and it applies to every skin.

**Show progress & status** draws the Now Playing furniture over the artwork: the
queue position and shuffle/repeat glyphs across the top, and a scrubber
underneath with elapsed counting up and time remaining counting down. Drag the
scrubber to seek.

**Album art while browsing** shows the highlighted song's cover behind the menu.
Each cover is a separate request to Music, so it waits for the highlight to
settle before asking and remembers the last two dozen it fetched.

**Always show a volume bar** keeps a draggable volume bar under the scrubber.
Without it the bar still appears while the wheel turns — and it is draggable
there too.

**Wheel click sound** has a volume slider. The tick is synthesised, not sampled.

**Launch at login** registers the widget with `SMAppService`, which puts it in
System Settings → General → Login Items where you can revoke it without going
through the app.

**Position lock is off by default**, so dragging just works. Turn it on once the
widget is where you want it; ⌘-drag still moves it either way.

**Placement** decides where it sits in the window stack:

| Mode | Behaviour |
| --- | --- |
| **On Desktop** (default) | Pinned to the wallpaper, behind every app window — like the stock widgets |
| **Always on Top** | Floats above everything |
| **Normal** | An ordinary window |

**Skins** are pure data in `Sources/Spindle/Theming/ThemeCatalog.swift`, so
adding a colourway means adding one `Theme` value with no view changes. Two of
the nine are glass: `Liquid Glass` (dark, the default) and `Frosted Glass`.

The last swatch is yours to edit: a hue/saturation **colour wheel** with a
brightness slider sets the body and border colours, and sliders cover body
opacity, border opacity and width, click wheel opacity, screen dim and title
scrim, plus a toggle for whether the wallpaper is blurred behind the widget.

---

## How it reads now-playing

This is the interesting part. Since macOS 15.4, Apple restricted the private
MediaRemote framework: `MRMediaRemoteGetNowPlayingInfo` returns an **empty
dictionary** for any process that is not an Apple platform binary. Verified on
this machine:

| Approach | Result |
| --- | --- |
| Reading now-playing directly from the app | 0 keys — blocked |
| Reading it from inside `/usr/bin/perl` | 31 keys, artwork included |
| Sending transport commands directly | Works, no workaround needed |
| `MRMediaRemoteSetShuffleMode` / `SetRepeatMode` | Work, unentitled |
| `MRMediaRemoteSetElapsedTime` (seeking) | Works, unentitled |
| `MRMediaRemoteGetNowPlayingApplicationPID` / `…DisplayID` | Blocked — PID 0, null id |
| Reading shuffle/repeat back | No usable API — see below |

So the app ships a small dylib and loads it inside `/usr/bin/perl`, which *is* a
platform binary, using the technique from
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter). The
dylib subscribes to MediaRemote's change notifications and writes
newline-delimited JSON to stdout; the app reads that stream. It is push-based,
not polling, and identical frames are deduplicated so idle playback costs
nothing.

Because the read goes through MediaRemote rather than a per-app script, it works
for anything that publishes to the system media controls, Music, Spotify,
Safari, Chrome, IINA, VLC.

The elapsed time in that dictionary is a reading taken *at* an accompanying
timestamp, not a live value. A frame captured while testing had `elapsed: 0`
with a timestamp nearly two minutes old, so the scrubber extrapolates from the
timestamp rather than trusting the number — otherwise it would sit at 0:00 for
the whole track. The queue leans on the same extrapolation: one frame per track
is enough to work out the exact moment to hand the next one over.

**Shuffle and repeat are set, not read.** `MRMediaRemoteSetShuffleMode` and
`MRMediaRemoteSetRepeatMode` work from an ordinary process and reach any player,
but the only way back is `MRMediaRemoteRegisterFor…ChangesWithHandler`, whose
block signature is undocumented — guessing at it segfaults. So the widget
remembers what it last set, and corrects itself against Music at launch when
Automation is already permitted. Change shuffle inside Music while the widget is
running and the status glyph can lag until you set it again from the widget.

If a future macOS closes the perl hole, the widget falls back to per-app
AppleScript for Music and Spotify, which loses universal coverage and artwork
from other sources.

---


## Troubleshooting

**The screen says "No media source".** The adapter could not start. Run the
binary directly to see why:

```bash
IPODWIDGET_DEBUG=1 "/Applications/Spindle.app/Contents/MacOS/Spindle"
```

That prints every now-playing update to stderr, which is the fastest way to
tell whether the adapter is feeding the UI.

**Nothing shows but music is playing.** Check the adapter is alive:

```bash
pgrep -fl stream.pl
```

**Transport buttons do nothing.** The media commands were refused and the
AppleScript fallback lacks permission, approve Automation as described above.

**I can't move the widget.** That is deliberate. Settings → turn off **Lock
position**, or use the menu bar icon.

**The wheel or the buttons don't respond.** The widget sits *behind* your
windows by default, so anything overlapping it takes the click. Move it
somewhere clear, or switch Placement to **Always on Top**. Every control is also
in the menu bar icon.

**The menu says "Allow Automation for Music".** Reading playlists needs it:
System Settings → Privacy & Security → Automation → Spindle → Music.

---

## License

MIT — see [LICENSE](LICENSE).
