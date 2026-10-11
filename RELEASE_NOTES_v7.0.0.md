# EeveeSpotify 7.0.0

A ground-up overhaul of the tweak's interface, built around native **iOS 26 Liquid Glass**, plus a redesigned settings app, a remote flag browser, and a large batch of stability and privacy fixes.

---

## ⚠️ Requires iOS 16.1

The minimum firmware is now **iOS 16.1**, raised from 14.0 to match Spotify 9.1.x's own floor. This is a breaking change.

> **If you're on iOS 14.0–16.0, stay on 6.6.8.** This version will not install on your device.

Liquid Glass surfaces additionally require **iOS 26** and an app restart. The settings page says so explicitly rather than failing silently.

---

## ✨ Liquid Glass UI *(iOS 26)*

A new opt-in rendering layer that replaces Spotify's stock chrome with real system glass, toggleable surface-by-surface — take the tab bar without touching the player.

- **Tab bar** — a genuine `UITabBar` rendered as native glass, with taps replayed onto Spotify's own tab items
- **Now Playing bar** — glass capsule with album-colour tinting
- **Spotify's own bars & menus** — existing blur views swapped for real `UIGlassEffect`
- **Player, lyrics, search, home, and page headers**
- **Playlist, album, and artist** glass action rows, with header and Home section controls
- **Custom lyrics view** — optional glass rendering, with the button hidden automatically when no lyrics are fetched

## 🎛️ Tab bar customization

Reorder tabs, hide tabs you never tap, hide labels for an icon-only bar, choose a launch tab, and pin any Spotify page as a custom tab. Liked Songs, Downloads, Podcasts, and Queue ship as presets; any `spotify:` URI can be added. Custom tabs navigate in-app rather than bouncing to your other Spotify install.

## 🎨 Appearance

- **AMOLED black theme** — see [Credits](#-credits) below
- **Custom accent colours** and **custom background colours**
- **Rounded playlist cover art** for library rows and playlist track rows
- **Dynamic background colours** pulled from album art
- **Home gradient control** — style (gradient or solid), height (short, medium, tall), strength, fade curve, and per-page targeting for Home, Library, and Search
- **Player backdrop** and **glass lyrics card** toggles

## 🎧 Player

Control decluttering, double-tap seek/skip zones, haptics for buttons and scrubbing, and direct access to Word-Synced lyrics.

## 📜 Lyrics & karaoke

The biggest change here: **word-synced lyrics now work in the custom lyrics view**, not just on Spotify's own lyrics screen.

- **Word-synced support for the custom lyrics view**, with a dedicated on/off toggle gating the rest of the section
- **Customisable blur intensity** (0–6) for inactive lyric lines
- **Other lyrics sources can now use line-synced mode**, not just Spicy Lyrics
- **Credits footer** with real attribution — who wrote, provided, and uploaded the lyrics
- **Official Spicy Lyrics API** with a configurable key, in-app validation, and a link to the key template
- Lyrics uncensoring fill, RTL karaoke highlighting, text alignment and reversed-direction controls

## 🔧 New settings surfaces

- **Remote flag browser** — browse, search, and override Spotify's server-side feature flags, with change-only filtering and per-flag reset
- **Curated Spotify Features page** — hidden switches Spotify already ships (trim silence, library Pro, denser rows, lock-screen options, sleep timer, and more)
- **Redesigned settings** grouped into Listening / Looks / Advanced, with per-page previews, page-level resets, and a Troubleshooting section
- **Debug logging** with export and clear

## 🛡️ Privacy & stability

- **Blocks third-party tracking SDKs** — Firebase, Facebook, Branch, and other analytics
- **Hide Jam** — strips Jam entry points from the app without touching tracks or artists that happen to be titled "Jam"
- **Blocks App Store rating prompts** — no more review popups interrupting playback
- Resolves an access-token race crash, a karaoke long-press scope bug, settings tint leaks, and assorted stability issues

---

## 🐛 Fixes in this release

### Custom lyrics view didn't update between songs

The biggest fix. Previously, opening the custom lyrics view pinned it to whatever song was playing at that moment — skip to the next track and it kept showing the old lyrics until you closed and reopened it.

It now follows the player: when the track changes, it swaps in the new song's lyrics and resets scroll position and per-line state so each song starts fresh. If the new track's lyrics aren't in hand yet, it fetches them and retries a few times before giving up.

It also tracks the **actually playing** track rather than the one a lyrics request last named — Spotify preloads lyrics for upcoming songs, so the old behaviour could latch onto the wrong one. If no lyrics turn up at all, the view closes itself instead of sitting there empty.

### iPad Liquid Glass layout

- **Tab bar rendered too small** — the glass bar inherited Spotify's short iPad strip height, squashing every item. Now floored at 50pt and centred on the original strip.
- **Album art escaped the mini player** — clipping was applied inside a radius check that iPad's capsule radius skipped entirely, so artwork bled past the corners. Clipping is now unconditional, and the artwork search is iPad-aware.

### Localisations

- Non-English tables brought in line with English
- Version appearance simplified, build number surfaced in-app
- "Rounded artwork" renamed to **"Rounded playlist cover art"** across all 27 languages

---

## 📦 Packaging

Locally built IPAs now ship with the alternate app icons baked in, and the deb dependency was corrected.

---

## 📋 At a glance

| | |
|---|---|
| Minimum iOS | **16.1** (was 14.0) |
| Liquid Glass | iOS 26 + restart |
| Languages | **27** |
| Alternate app icons | **34** |
| Spotify | 9.1.x |

---

## 📥 Install

Sign the IPA with **SideStore**, **FlareStore**, or a certificate-based signer like **RyukSign**. For jailbroken devices, grab the `.deb` matching your architecture from the releases page.

---

## 🙏 Credits

This release stands on a lot of contributed work. Thank you to everyone who opened a PR, reported an issue, or tested a build.

### Hide Jam & block rating prompts

**Hide Jam** and **Block rating prompts** were proposed and implemented by **[Incognito-Coder](https://github.com/Incognito-Coder)** in **[PR #152](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/pull/152)** (*feat: hide Jam from menus and block app star rating dialogs*).

**Hide Jam** strips Jam out of the app without touching tracks or artists that happen to be titled "Jam" — it overrides 17 Jam-related remote configuration flags covering the queue button, guest controls, device-picker integration, nearby-session nudges, invite deep links, and local-network discovery. Rating prompts are suppressed by hooking `SKStoreReviewController` directly.

Both are off by default and take effect after restarting Spotify.

### AMOLED black theme

The optional **AMOLED black theme** was originally proposed and implemented by **[nodzen](https://github.com/nodzen)** in **[PR #126](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/pull/126)** (*feat: add optional AMOLED black theme*).

Rather than flattening every dark surface to pure black, nodzen's approach was surgical: it replaces only opaque, nearly neutral dark `UIView` backgrounds with true black, while deliberately preserving coloured artwork-derived backgrounds, gradients, translucent materials, text, icons, and shadows. That constraint is what keeps the theme from destroying album art and glass surfaces elsewhere in the app.

The theme ships disabled by default and takes effect after restarting Spotify.

### Word-synced lyrics

**Word-synced lyrics in the custom lyrics view**

### Other contributions

- **[hooray804](https://github.com/hooray804)** — Korean localisation ([PR #172](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/pull/172))
- **[marcinmajsc](https://github.com/marcinmajsc)** — Polish localisation and lyrics source footer ([PR #123](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/pull/123), [PR #147](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/pull/147))
- **[Huseyin-Korkmaz](https://github.com/Huseyin-Korkmaz)** — Turkish localisation ([PR #137](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/pull/137))
- **[U-rTrDD-fyi](https://github.com/U-rTrDD-fyi)** — Musixmatch lyrics fix for the `apic` ELB 403 ([PR #166](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/pull/166))
- **[karlfrank916](https://github.com/karlfrank916)** — the Messages `si` parameter report that prompted this release's share-link investigation ([#171](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/issues/171))

---

## Known issues

- **Share links to Messages still include Spotify's `si` tracking parameter** ([#171](https://github.com/SideloadLabs/EeveeSpotifyReincarnated/issues/171)). Clean Share Links strips it for the share sheet, clipboard, and direct share targets, but the Messages route isn't covered yet. An attempted fix was reverted because it targeted a class we couldn't confirm on that code path.
