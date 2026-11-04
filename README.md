# benj

**Team benj · XANIX Challenge 2026 · The Business That Can't See Itself**

> Small shops are not short of records; they are short of foresight. benj turns records into foresight.

benj tells a small shop owner what to restock, how much, and when, before they run out.
It's for single-outlet shops selling countable goods (bags, packs, cartons, crates). Live at https://benj-xanix.vercel.app.

## What's built (PRD section 7)

| ID | Feature | Where |
|---|---|---|
| F1 | Shop setup | `lib/screens/setup_screen.dart`, `product_form.dart` |
| F2 | Quick stock log, offline | `lib/screens/log_screen.dart` |
| F3 | Restock entry | Log > Bought, or tick items on the buying list |
| F4 | Low-stock warning | Home; owner's level or benj's suggestion (`product_screen.dart`) |
| F5 | Weekly buying list | `lib/screens/buying_screen.dart` |
| F6 | Calendar | `settings_screen.dart`; official dates go in `assets/ashesi_calendar.json` |
| F7 | Forecast vs actual | Product screen, replays the log as of each past Monday |
| F8 | Stock dashboard | `lib/screens/stock_screen.dart` |
| F9 | Voice input | `capture_sheets.dart`, `lib/core/voice_parser.dart` |
| F10 | Photo input (owner confirms) | `capture_sheets.dart`, Gemini through Firebase AI Logic |
| F12 | Budget-aware list | Cash field on the buying list |

Every log stores its input method and seconds taken, so the riskiest assumption (will a busy owner log?) is measured. See Settings > My numbers.

## How it fits together

```
Flutter web app (installable PWA)
  ├─ Firebase Auth: phone (SMS), Google, email
  ├─ Firestore: shops/{uid}/... with an offline cache; private to each owner
  ├─ lib/core/forecast.dart: warnings and lists, works with no network
  └─ web/fx/: mascot and effects (three.js and shaders), loaded only when needed
Python service: api/forecast.py on Vercel
  the same formulas; tests/forecast_vectors.json keeps Python and Dart identical
```

### The forecast, in full (PRD section 9)

```
daily demand d   = mean units sold per day, last 14 days (sold-out days skipped)
calendar factor f = average of the owner's event factors over the period
warning level    = d * f * L + 1.65 * sd * sqrt(L)     L = days to next restock
buy Q            = d * f * 7 + 1.65 * sd * sqrt(7) - stock on hand, rounded up
```

Below 3 days of logs benj says "still learning" rather than suggest amounts.

### Effects

| Moment | File | Notes |
|---|---|---|
| Boot logo, liquid metal | `web/fx/glyph.js` (metal) | No three.js, so it loads first |
| "benj" name, liquid glass | `web/fx/glyph.js` (glass) | |
| Mascot | `web/fx/mascot.js` | Modelled in code; also exported as `web/fx/benj.glb` |
| Loading | `web/fx/quantum.js` | Particles settle into the logo |
| Voice orb | `web/fx/orb.js` | Reacts to the real mic level |
| Saving a log | `web/fx/glow.js` | Morphs, then resolves into a tick |
| Stock Constellation | `web/fx/nodes.js` | Height = days left; drag the timeline to see the future |
| Team portraits | `web/fx/team.js` | Add headshots at `web/team/{id}.jpg` |
| Globe | `web/fx/globe.js` | Beacon on Berekuso |
| Floating sparkle | `lib/widgets/sparkle.dart` | Drawn by Flutter, answers from real records |

All are written for benj, inspired by the references rather than copied. three.js is MIT licensed.

### Team headshots

Add a clear, well-lit square photo for each person, then redeploy: `web/team/selikem.jpg`, `josephine.jpg`, `moyinoluwa.jpg`, `bright.jpg`, `emmanuella.jpg`. Until a photo exists, an anonymous dotted bust holds the place.

## Run it

```bash
python -m unittest discover tests      # forecast, Python
flutter test                           # forecast, voice, budget, phone numbers

# Whole app, no Firebase account needed
firebase emulators:start --project demo-benj --only auth,firestore
flutter build web --no-web-resources-cdn --pwa-strategy=none --dart-define=USE_EMULATOR=true
python scripts/serve.py 8766           # http://localhost:8766

python scripts/e2e.py OUT_DIR          # full owner journey in a real browser
python scripts/e2e_security.py OUT_DIR # security rules and SMS sign-in
```

`pip install playwright` first; the scripts drive Microsoft Edge.

## Deploy

- App and Python service: push to `main`; Vercel runs `scripts/vercel_build.sh`.
- Rules: `firebase deploy --only firestore:rules`.

## Not done yet

- WhatsApp or SMS reminders (F11). Today the list shares through a WhatsApp link.
- Multiple users per shop; perishables; Twi voice input (PRD P2).
- Native Android 3D. The Android build shows still images of the mascot for now.
