# Competitor and review analysis

Collected from public store/analytics pages while building v1.1. Review samples are small
(often 15–25 reviews per app, AI-summarised by third-party sites), so treat them as **signals, not statistics**.
I could not open the Play Store itself, so install and rating numbers come from third-party trackers and may be stale.

## Direct competitors (oud / maqam tuners)

| App | What it is | Signals found |
|---|---|---|
| Ud Tuner – Oud Tuner (CherrySoft, Android) | Oud tuner, Turkish/Greek/Armenian/Arabic/Iranian presets | ~530K installs, ~4.0★ on ~2.8K ratings (tracker data), installs trending down, revenue estimated under $10K/month, mix of ads and IAP |
| Oud Tuner (softadev, Android, Jun 2026) | Oud tuner with auto course detection | Annual subscription ("Pro") unlocks the full tuner |
| Oud Tuner (iOS) | Oud tuner with custom tunings | Review: fails on the most common Arabic tuning C F A D G C, even with custom tuning |
| Maqam: Eastern Tuner (iOS only) | Tuner + metronome for 24 Eastern instruments | iOS only in what I found; few reviews |
| Maqam Analyzer, BrayerMaqam, Altarab (iOS) | Maqam detection, MIDI controller, teaching suite | Not tuners; show demand for quarter-tone tools |

**Gap I could identify:** I did not find an Android tuner that combines 12/24/53 systems, scale practice and
oud tunings without a paywall on basics. I cannot prove none exists; check the Play Store before launch.

## Complaints about tuner apps in general (all instruments)

1. **Ads during tuning** ("two ads in one tuning session").
2. **Subscription-only ad removal**, "$48/month to remove ads", "why subscribe to a tuner?", requests for one-time purchase.
3. **Free app turned paid** after an update; users delete and leave 1★.
4. **Needle freezes / does not move**, need to close and reopen the app. One tuner had a bug where it went silent after switching apps.
5. **Inaccurate or jumpy readings** in noisy rooms; slow needle; wrong octave on low strings.
6. **Does not know which string** you are tuning in alternate tunings.
7. **Bloat**: lessons and games pushed inside a tool people only want to be a tuner.

## What v1.1 does about each

| Complaint | Response in the app |
|---|---|
| Ads during tuning | Banner is hidden while the tuner is listening; no interstitials at all |
| Subscription-only | One-time "Remove ads" and one-time "Pro, pay once"; yearly is optional |
| Free turned paid | Core tuning, all oud tunings, guitar, violin and main scales stay free; paywall text says so |
| Freezing / silence after switching | Watchdog restarts the microphone; auto-resume after app or tab switch |
| Jumpy in noise | 3-frame agreement + median, clarity gate, 3-level sensitivity setting |
| Which string? | Auto-detect plus tap-to-lock a string (also plays its pitch) |
| Common Arabic tuning missing | Arabic C F A D G C and D G A D G C, Turkish C# F# B E A D and E A B E A D, plus custom tunings with quarter-tone notes |
| Low strings | Detection down to 35 Hz (bass E1 = 41 Hz), tested |
| Bloat | No lessons or games; one extra feature (scale practice) that fits the audience |

## New differentiators added
- **Scale practice (maqam mode):** nearest degree, cents error, play the scale up/down; 24-TET and 53-TET scales.
- **Quarter-tone note names** in custom tunings (`Bd3` = B half-flat).
- **Tap-to-lock string**, **vibrate when held in tune**, **screen stays awake** while tuning.
- **Review prompt only after 5 successful tunings**, at most once per 120 days.

## Not done / ideas for later
- Native-speaker review of the Turkish and Arabic translations (added in 1.2.0, not yet reviewed).
- More instruments (saz/bağlama, kanun, ney). I did not add saz tunings because I could not verify them from a reliable source.
- Ahenk (diapason) transposition for Turkish music; currently A4 calibration 415–466 Hz only.
- Saving several custom tunings; recording/replay; metronome.
- Real-world accuracy tuning with recorded oud/saz samples.

## Sources (accessed Nov 2026)
- appgoblin.info/apps/com.visne.oudtuner (installs, ratings, revenue estimate)
- appgoblin.info/apps/xyz.softadev.oudtuner (annual subscription)
- appshunter.io/ios/app/1128962288/reviews (C F A D G C complaint)
- apps.apple.com/app/id6768297508 and marlvel.ai/apps/maqam-eastern-tuner (Maqam: Eastern Tuner)
- android-stats.com/d/hai.lior.ukaleletunerfree/reviews, android-stats.com/d/com.t4a.tuner.bass/reviews
- apps.apple.com/app/id687934254, justuseapp.com reviews pages for GuitarTuna / Guitar Tuner apps
- apps.apple.com/ID/app/id348094874 (Pano Tuner silent-after-app-switch fix)
- Oud tunings: londonguitarstudio.com/s/what-is-an-oud, mikeouds.com forum threads, soundbridge.io/en/oud
