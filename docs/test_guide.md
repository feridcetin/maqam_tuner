# Test guide

## 0. No instrument? Start here
Use **Settings > Test the tuner on this phone** (Phone check). It separates app faults from room/speaker faults:

1. **Detection test** feeds 12 synthetic notes straight into the detection code, with no microphone or speaker. All 12 should pass (error under 3 cents), at roughly 1–5 ms per analysis in a release build.
2. **Microphone check** (3 s of silence) shows the real sample rate (about 44100 Hz expected) and the background noise. A wrong sample rate would shift every reading by the same percentage.
3. **Speaker to microphone** plays 440 Hz from the phone and listens. Expect within about ±5 cents.

If 1 passes and 2 shows about 44100 Hz, a wrong reading in the tuner comes from the sound source or the room, not from the app. Use **Copy report** and send it to me if something fails.

More ways to test without an instrument:
- A **second phone or computer** playing a pure tone: search for "online tone generator" and set exactly 440, 220 or 110 Hz. Pure sine waves are the cleanest test.
- **Your own voice**: hum one steady note (the tuner should settle on it; compare with a second tuner app).
- **Recordings** of oud, saz or violin played from a computer. Check that the notes shown make sense and compare with another tuner app. Expect worse results with small laptop speakers, echo and several instruments playing at once.
- **Free piano apps** or a keyboard: each key is a known pitch.

## 1. Put the app on your phone
1. Phone: Settings > About > tap *Build number* 7 times > Developer options > enable **USB debugging**. Plug in the USB cable and accept the prompt.
2. `flutter devices` must list the phone. Then:
   - `flutter run` for quick UI checks (debug build is slow; the needle can look laggy, which is normal).
   - **`flutter run --release`** for judging speed and accuracy. Always do the accuracy tests in release or profile mode.
3. Use a real phone, not the emulator (no usable microphone).
4. Ads show Google *test* ads until you set real IDs. In-app purchases do **not** work from `flutter run`; they need a build installed from a Play Console internal/closed test track.

## 2. How to play the test sounds
- Files are in `test_pack/`. Play them from a **second device** (laptop, another phone, Bluetooth speaker), 20–30 cm from the test phone's microphone, in a quiet room, medium volume.
- Do not play them from the same phone. Its own Tone tab is only a quick sanity check.
- Small speakers cannot reproduce very low notes (below roughly 150 Hz the fundamental is weak or missing). For files 06, 07 and 08 use a decent speaker or headphones held to the mic, or better a real instrument. If the tuner shows an octave too high there, that is a genuine finding: note which phone and which string.

## 3. Expected results (checked offline with the app's own detection code)
Tolerance: within **±3 cents** and a stable display within about half a second.

| File | Mode | Expected |
|---|---|---|
| 01_A4_440Hz | 12-TET chromatic | A4, 0 cents, steady for 5 s |
| 02_A4_cents | 12-TET chromatic | A4 with −20, −10, 0, +10, +20 cents in turn; "Tune up" for negative, "Tune down" for positive |
| 03_24TET_quartertones | 24-TET chromatic | A4 A+4 A#4 B−4 B4 C−5 C5 C+5 C#5 D−5 D5 D+5 D#5 E−5 E5 F−5 F5 F+5 F#5 G−5 G5 G+5 G#5 A−5 A5, each ~0 cents (`+` = quarter-sharp, `−` = quarter-flat) |
| 04_53TET_komas | 53-TET chromatic | A4, A4 +1 koma, +2, +3, A4 +4 koma · bakiye, B4 −4 koma · bakiye, B4 −3, −2, −1, B4. Each ~0 cents |
| 05_Rast_on_C | Scale: Rast, tonic C (24-TET) | degrees 1 to 8 and back: C, D, E−, F, G, A, B−, C, each ~0 cents |
| 06_oud_arabic | Instrument: Oud · Arabic | strings C2 F2 A2 D3 G3 C4 highlighted in turn, ~0 cents |
| 07_oud_turkish | Instrument: Oud · Turkish | C#2 F#2 B2 E3 A3 D4 in turn |
| 08_bass | Instrument: Bass guitar (Pro) | E1 A1 D2 G2 (E1 is 41.2 Hz) |
| 09_oud_A2_detuned | Oud · Arabic | A2 at −30 ("Tune up"), then 0, then +30 ("Tune down") |
| 10_glide | Chromatic | note follows the sweep smoothly. Expect up to ~45 cents lag (smoothing), never a jump of an octave |
| 11_noise_then_silence | any | **no note shown at all**. A note appearing here is a bug |
| 12_violin | Instrument: Violin | G3 D4 A4 E5 in turn |

Offline simulation results with the same pipeline: all of the above held (A4 440.1 Hz, bass E1 41.2 Hz, 25 quarter tones and 10 komas in order, no output on noise, no octave jumps in the glide).

## 4. Behaviour checklist
- [ ] First start: microphone permission asked. Deny it: a clear message appears, no crash. Allow it later: works.
- [ ] Banner ad is hidden while listening and visible on Tone and Settings tabs.
- [ ] Press Home while listening, come back: listening resumes by itself.
- [ ] Switch to Tone tab and back: same.
- [ ] Incoming call or another app using the microphone: no crash, tuner recovers (watchdog).
- [ ] Screen does not turn off while listening; turns off normally after stopping.
- [ ] Hold a note in tune for 1 s: one vibration (can be disabled in Settings).
- [ ] Tap a string: it locks and plays its pitch; tap again: back to auto-detect.
- [ ] Scale mode: pick Rast, change tonic, play the scale on the Tone tab.
- [ ] Settings: A4 slider changes readings (play 01 with A4 = 442: about −9 cents).
- [ ] Noisy room setting reduces jumping when a TV is on; Quiet room picks up soft notes.
- [ ] Pro items show a lock; paywall opens; "Restore purchases" works from a Play test build.
- [ ] Rewarded test ad grants 24 h Pro and locks again afterwards.
- [ ] Rotate the phone, switch dark/light system mode, large font size: nothing overflows.

## 5. How to know the numbers are right (independent checks)
1. **Known-frequency sources:** the test files above, plus a tone-generator website or Audacity (Generate > Tone) at 440, 110 and 220 Hz.
2. **Second opinion:** run a trusted tuner (a hardware clip-on or a well-rated app) next to yours on the same real instrument. Differences above 3–5 cents on a steady note need an explanation.
3. **Spectrum view:** record the instrument in Audacity and use Analyze > Plot Spectrum to read the true fundamental, then compare with the app.
4. **Real instruments, 3+ phones** (one cheap): open strings of an oud, a guitar and a violin. Check the lowest strings for octave errors, and check that the needle settles in under half a second.
5. **Players:** ask an oud/saz/kanun player to confirm that the scale degrees (Rast, Bayati, Hicaz, Uşşak…) match what they actually play. The values are standard theory, but regions and players differ.

### Acceptance criteria before publishing
- Steady tones from 80 Hz to 1 kHz: within ±3 cents on every test phone.
- No note shown for silence or noise.
- No octave errors on the open strings of your own oud.
- No freeze after 10 minutes of listening, and after 5 background/foreground cycles.

### If something fails
- Reads an octave high on low strings: lower `threshold` or raise the clarity requirement in `lib/core/yin.dart`/`tuner_controller.dart`; test with a better speaker first to rule out missing fundamentals.
- Jumpy needle: raise `_minClarity` values or use the Noisy room setting.
- Slow to react: lower the 3-frame agreement requirement (currently 3 frames ≈ 180 ms).
- Phone-specific bad readings: send me the phone model and which file/string, and I will adjust.
