# Next Release To-Do (post-7.0.0)

Sources: open + recent issues on `SideloadLabs/EeveeSpotifyReincarnated` (as of 2026-10-07),
the v7.0.0 release (published 2026-10-05), and a feature diff against <https://chroma.pw>.

Nothing here is started. Order is the suggested shipping order.

---

## P0 — Regressions and bugs introduced by 7.0.0

| # | Issue | Reporters | Why it's P0 | First step |
|---|-------|-----------|-------------|-----------|
| 1 | **#190** — TrollStore injection → app won't launch (iPhone 15PM, iOS 17.0, Spotify 9.1.88, ES 7.0.0) | 1, no log | Blocks an entire install method. Looks like a regression, not a config issue. | Get a crash log / `os_log` capture from the reporter. Check whether the packaged deb differs from the previous release's (`Depends: firmware (>= 16.1)` was raised in this cycle). |
| 2b | **Custom tabs — STILL BROKEN, was crashing on tap (on-device, 2026-10-10)** | user, 9.1.90 | Not fixed yet; crashed the app on tap. | Two faults found. (a) Hooking the real 5-arg `navigateToURI:options:reason:completionHandler:resultHandler:` made Orion intercept the method Spotify uses for ALL internal navigation, which broke tab-bar rendering at startup and tab taps — hook reverted to the non-installing 3-arg form. (b) `open()` passed `nil` for the two completion blocks, which Spotify's implementation invokes unconditionally — now passes real no-op blocks. **Unverified**; needs a device retest. If it still fails, capture the `[CustomTabs]` log lines. |
| 2c | **Liquid Glass tab bar doesn't render until app switch (on-device, 2026-10-10)** | user, 9.1.90 | Bar invisible until backgrounding Spotify. | **ROOT CAUSE FOUND & FIXED (2026-10-10), unverified on device.** Not 2b's hook. `GlassTabBar.sync()` has two early returns (`tabRow` nil, `tabs` empty) that fire while Spotify's tab row is still building during launch — and unlike the icon-missing path, they did **not** re-arm a retry, so nothing called `sync()` again until the next layout/selection change. Backgrounding Spotify is what re-triggered it, which is exactly the reported workaround. Fix in `GlassTabBar.x.swift`: both early-return paths now re-arm a bounded retry chain (`scheduleRetry`/`schedulePass`, 80 × 0.25s, budget reset by any external sync), a `didBecomeActive` observer re-syncs on foreground, and `reveal()` keeps suppressing Spotify's content once revealed instead of only when icons are complete. Re-test: cold launch should show the glass bar within ~1s without switching apps, and it must survive background/foreground cycles. |
| 2d | **Liquid Glass "Follow" button on playlists is buggy (on-device, 2026-10-10)** | user, 9.1.90 | Pre-existing, not from the 2026-10-10 diff. | Lives in `Pages/PlaylistActionRow.swift` + `Pages/GlassPlaylist.x.swift` — neither touched by the diff. The row draws its own `followButton` and forwards the tap to Spotify's `Curation.FollowButtonElementKit.FollowButton`. Need the actual symptom (wrong label / does not toggle / misaligned) before fixing. |
| 2 | **#184** — Tab Bar "Create New" tabs render but do nothing; active tab re-highlights | 2, confirmed by a second user | The headline Liquid Glass tab-bar feature is visibly broken on 7.0.0. **ROOT CAUSE CONFIRMED.** | The selector is wrong for 9.1.88. Eevee calls `navigateToURI:options:interactionID:` (`GlassTabBar.x.swift:329`) but that selector does **not exist anywhere** in the 9.1.88 binary — grepping the extracted `Spotify` executable returns **0** occurrences. The only multi-arg form present is `navigateToURI:options:reason:completionHandler:resultHandler:`. So `CustomTabs.open()` passes its `dispatcher` guard, fails `responds(to:)`, and returns silently — and because `select(tab)` sits *after* that call, `selectedKey` is never set, which is exactly why the stock tab re-highlights (the second reporter's other symptom). The class itself (`SPTLinkDispatcherImplementation`) is present, which is why the tabs still *render*. Fix = call the real selector (note it takes 5 args, not 3), plus make the `responds(to:)` failure log at error level instead of one indistinguishable string. |
| 3 | **#189** — hiding all player parts leaves "Explore the artist" up and wrecks the layout | 1 + screenshot | Visible breakage of a shipped option. | **Hypothesis revised after checking the binary.** `PlayerDeclutter.x.swift` maps `.exploreArtist → ["WatchFeed"]`, and `WatchFeed` *does* still exist in 9.1.88 (`SPTWatchFeed_NPVProviderImplProperties` etc.), so "the marker was renamed" is **not** the explanation. The 9.1.88 NPV providers are `SPTMartini_NPVCardProviderImpl`, `SPTVideoRecommendations_NPVProvider`, `SPTWatchFeed_NPVProvider` — `Martini_NPVCardProvider` is a generic card provider and a plausible new host for this card. Still needs a live UI dump to confirm; do not assume the marker is stale. |
| 4 | **#188** — stretched settings gear icon; now-playing artwork hard against the edge | 1 + screenshot | Cheap, high-visibility polish. | Gear stretch is in the Eevee settings design layer; the artwork inset is the `rounded_artwork` / `GlassNowPlayingBar` path touched by `5b1e7cc`. |
| 5 | **#187** — stale lyrics teaser card after skip (iPadOS 26.6); wrong release date; displaces Explore Artist | 1 | Same subsystem as #3 — fix together. | Teaser card marker is `Lyrics_CardElementImpl` in `PlayerDeclutter`. Stale-after-skip implies the verdict cache isn't invalidated on track change. |
| 6 | **#171** — shared links in Messages still carry the `si` parameter | 2, open since 2026-10-03 | Long-standing, was reported as fixed before (#128) and isn't. | Repro is now narrowed: **only** via the Messages button direct-share path, not the generic share sheet. `CleanShareLinks.x.swift` covers `UIActivityViewController` + pasteboard; the Messages path bypasses both. Prior `ShareURLFactoryImpl` swizzle was reverted as ineffective — don't re-apply it, hook the actual direct-share entry point instead. |
| 7 | **#194** — player declutter: "Discovered more about (Artist)" card not hidden (new 2026-10-09) | 1, reporter self-diagnosed | Same subsystem as #3/#5 — a third instance of one root cause. | Reporter narrowed it to the "Discovered more about <artist>" card. **Do not guess markers.** The exact English string does not appear anywhere in the 9.1.88 binary or our bundle, and `cardMarkers` is matched against *class names + accessibilityIdentifiers*, never display text — so adding the display string as a marker cannot work. Needs the real class/accessibility ID from a live UI dump. |
| 8 | **#193** — music videos not properly masked in the Now Playing bar (new 2026-10-07) | 1 | Liquid Glass NPV-bar regression class. | Believed to be in the `GlassNowPlayingBar` artwork/tint path touched by `5b1e7cc`. Confirm before assuming. |

**Also verify:** the iPad tab-bar height fix (`5b1e7cc`, `minimumBarHeight` = 50pt) — confirm the 7.0.0 build actually contains it and that it reads as tall enough on a wide iPad window. I could not re-open the screenshot attached earlier in this conversation, so treat this as unconfirmed.

---

## P1 — Most-requested features

| # | Issue | Signal | Note |
|---|-------|--------|------|
| 7 | **#179** — equaliser / audio effects (spoti.pw/JamesDSP-style) | Filed 2026-10-05; notes Spotify's own EQ is now paywalled | This is chroma.pw's flagship differentiator. Genuinely large: needs an `AVAudioEngine`/tap on Spotify's own player. Scope it as a phased feature — start with a plain EQ before talking reverb/convolver. Nothing EQ-related exists in the tree today. |
| 8 | **#139** — iOS 26 lock-screen artwork | **19 comments** — the most-discussed open issue | Chroma ships this as a Live Activity (controls / queue / sleep timer) plus artwork-as-lock-screen. No `ActivityKit` usage anywhere in the repo yet. Highest engagement-per-effort item on the board. |
| 9 | **#136** + comment on **#186** — bring back the download button for 9.1.88 | 2 separate asks | Users are deliberately downgrading to 9.1.74/6.6.8 to keep it (see #186 thread), which costs us bug reports on old builds. |
| 10 | **#148** — ads in Spotify-made "made for you" playlists | 8 comments | Ad-surface coverage gap; follow-on to #129/#130 (nodzen, Premium config for 9.1.76+). |

---

## P2 — Competitive gaps vs chroma.pw

Chroma advertises these; Eevee has **none** of them (verified by grep over `Sources/`):

- **Animated (canvas) cover art** — chroma shows it in the player, on album pages *and* on the lock screen. We are closer than we look: `player_flag_canvas` in `LiquidGlass/PlayerSettingsView.swift:14` is already a user-visible "Canvas" toggle that re-enables Spotify's own `ios-feature-canvas.canvas_enabled`. So the player half is reachable today; the real gaps are **album pages** and **the lock screen**, plus the fact that we don't render any of it ourselves. Confirm the toggle works on 9.1.88 before counting this as covered.
- **Lock Screen + Dynamic Island Live Activity** — controls, queue or sleep timer; like/dislike without unlocking. Overlaps #139; do them as one project.
- **On-tap line translation** and **Genius annotations for the tapped line** — `LyricsTranslationDto` exists but there's no tap-to-translate UI.
- **RTL-correct Arabic and Hebrew lyrics** — we ship an `ar-EG` UI locale, but nothing handles RTL lyric lines specially.
- **Speed/pitch and sound controls** — tempo-preserving speed, key change, reverb, bass boost, compander, convolver, AutoEq headphone correction, and "Sing" (vocal-down). Same audio-engine foundation as #179; a broad audio-processing grep (`AVAudioEngine`, `AVAudioUnit`, EQ, reverb, convolver, time/pitch, AutoEq) returns **zero** hits, so this is greenfield. Our existing Karaoke feature is the closest thing and should be checked for parity with chroma's "Sing".
- **App-wide custom font + accent colour** — true black is done (AMOLED, #126/#175); font and accent tint are not.
- **In-browser IPA patcher** — chroma patches "right here in the browser, no Mac needed" and pins to 9.1.78. Ours is `build-ipa-local.sh` plus a decrypted IPA the user must supply. Even just documenting GitHub Actions as the no-Mac path would narrow this.

**What we already lead on** — worth putting in the release notes rather than building: 27 UI languages vs their single-page site, 34 app icons, the remote flag browser, Spicy Lyrics sources, 9.1.88 (they test 9.1.78), and no paid tier.

---

## P3 — Housekeeping and long tail

**Release mechanics**
- The local IPA `Outputs/IPAS/EeveeSpotify-7.0.0-9.1.88.ipa` was built at `9c7dc28` and **predates** the `04561bd` lyrics fix — rebuild before shipping.
- IPA `MinimumOSVersion` says **15.0** (inherited from stock Spotify) while `control` requires **firmware >= 16.1**. Sideloaders see contradictory numbers.

**AltSource (`apps.json`)**
- Patched entry `size: 13000000` is ~10× too low — real size is **142,296,457** (unpatched is 139,507,438).
- Both entries declare `"version": "9.1.76"`, contradicting their own `versionDescription` ("Updated to Spotify v9.1.88").
- Entry 1's `localizedDescription` still advertises EeveeSpotify 6.6.8(2) / Spotify 9.1.76.
- Leave the `SideloasLabs-AltSource` spelling alone — it's the real repo name; the "corrected" spelling 404s.

**Translations** — 5 locales for `rounded_artwork` are machine-produced and want a native pass: **ar-EG, fa, np, az, hr**.

**Security** — hardcoded Spicy Lyrics API key at `Lyrics/Models/Settings/SpicyLyricsKey+UserDefaults.swift:6`.

**Lyrics quality cluster** — #154 (misinterpreted Japanese), #98 (LRCLIB server), #67 / #51 (desync), #46 (Genius not loading), #40 (not loading in some situations). Worth one investigation pass rather than five separate fixes, since they plausibly share a timing/caching root cause.

**Smaller asks**
- #183 — adjustable lyric-background blur (also notes Liquid Glass borders around the lyrics screen).
- #192 — option to queue an album/singles (filed as a `bug`, but reads as a feature request).
- #182 — choose which playlist the "+" button adds to instead of always Liked Songs.
- #191 — play offline/cached songs.
- #146 — Musixmatch lyrics broken.
- #78 — custom lyrics sometimes disappear.
- #177 — login rejects email until an attempt with username is made (SideStore → LiveContainer).
- Rootlist toggle in the style of spicetify's `toggleDJ` — feasible (~20 lines via the already-hooked `ProfileSettingsSection`), but **only** worth it if Spotify iOS actually surfaces a "Your DJ" library entry users want hidden. Confirm that first.
