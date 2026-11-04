# benj

**Team benj · XANIX Challenge 2026 · Opportunity: "The Business That Can't See Itself"**

> Small shops are not short of records; they are short of foresight. benj turns records into foresight.

benj tells a small shop owner what to restock, how much, and when, before they run out (PRD, `XANIX docs`). Live: https://benj-xanix.vercel.app

## Who it's for

Small, single-outlet shops near Ashesi selling **countable, non-perishable goods** (bags, packs, cartons, crates): the provision shop, the rice seller, and a cafeteria's packaged items. Supermarkets with a POS, chains and perishables are out of scope for v1.

## Try it

The app starts empty: no demo shop and no sample data.

1. **Sign in** with a phone number and password (a benj account), Google, or email. Creating an account asks for the business name. Poddy gives a short tour on the first visit.
2. **Add products** with unit (bag, pack, carton…), size (1 kg, 4.5 kg), how many are on the shelf, and optionally what you pay.
3. **Log** each day: tap + for each one sold, or type a count, or record what you bought and at what price.
4. **Home** warns what is running low, with days left. **Buy** gives the week's list ("Buy 2 bags of Rice 4.5 kg"), adjusted for campus events and ranked for the cash you have. **Stock** charts levels over time; tap a product to see forecast vs actual.

## What is built (PRD section 7)

| PRD | Feature | Where |
|---|---|---|
| F1 | Shop setup: business name at sign-up; products on a full page, **typed, spoken, or from a photo** (label, shelf or stock-book page) read by Gemini into the form for the owner to check; location, phone, restock day in Settings | `screens/auth.dart`, `product_form.dart`, `core/reader.dart`, `settings.dart` |
| F2 | Quick stock log: +/- per product or a count, one screen, saves offline; seconds per entry recorded | `screens/log.dart` |
| F3 | Restock entry: quantity and price per product | `screens/log.dart` (Bought) |
| F4 | Low-stock warning with days left; owner's level or benj's suggestion | `screens/home.dart`, `product.dart` |
| F5 | Weekly buying list with plain-language lines | `screens/buy.dart` |
| F6 | Campus calendar: owner-added events with a demand change, shown on the list | `settings.dart`, `buy.dart` |
| F7 | Forecast vs actual, per product per week, with error | `screens/product.dart` |
| F8 | Stock dashboard: line per product, week/month, sort by name / lowest / fastest, today marked, variant colours | `screens/stock.dart` |
| F12 | Budget-aware list: most at-risk items first, "cash covers 1 of the 7 you need" | `screens/buy.dart` |

Voice and photo work for **adding products**: speech is turned into words by the browser (`web/voice.js`), then the words or the photo go to Gemini (`gemini-3.8-flash` via Firebase AI Logic) which returns product details; nothing is saved until the owner checks it. Not built yet: voice and photo for **daily logging** (F9/F10), F11 WhatsApp/SMS reminders (the list can be sent to WhatsApp by hand). The **official Ashesi academic calendar** is not pre-loaded: we could not find published dates, so owners add events themselves until the team adds the real dates.

## How it works

```
 Flutter web app (phone)                          Firebase (project benj-27c66)
 ─────────────────────────                        ─────────────────────────────
 Log / Buy / Stock / Settings  ── writes ──▶      Firestore: shops/{uid}/products, stockLogs, events
 forecast on the phone (offline) ◀── sync ──      (offline cache on the phone; rules: owner only)
                                  └─ checks ──▶   Python forecast service on Vercel: api/forecast.py
```

- **Data model (PRD 9):** `shops/{uid}` (name, location, phone, restock day, consent), `products`, `stockLogs` (type count/sale/restock, quantity, price, input method, seconds taken) and `events` (dates, demand factor). Each owner can only read and write their own shop (`firestore.rules`).
- **Forecast (PRD 9), the same in Python and Dart:** average daily demand over the last 14 days (sold-out days skipped), times the calendar factor; warning level = d × f × L + 1.65 σ √L, buying quantity = d × f × 7 + 1.65 σ √7 − stock, rounded up. Under 3 days of data, benj says it is still learning. `tests/forecast_vectors.json` checks Python and Dart give the same numbers.
- **Forecast vs actual (F7)** replays the logs as of each past Monday, so it doubles as the backtest in PRD Test 2.

## Logo

The **b's bowl is a lens** (a round glass with a glint), because benj helps owners see their shop clearly. `assets/brand/logo.svg` (full) and `assets/brand/mark.svg` (the b tile) are generated, not hand-drawn, so they stay proportional:
* the lens is exactly as tall as the letter o, so it lines up with **e, n, j** (Poppins Bold, SIL Open Font License);
* the white strokes are slightly thinner than Poppins Bold's, because white on green reads heavier; the result looks the same weight as "enj";
* in the full logo the tile also covers the left 25% of the **e**: that part is white and the other 75% is green, so the b tile flows into "enj". The tile's bottom edge lines up with the j;
* the app icon and browser-tab icon use the square b tile on its own, with the b optically centred.

Green is `#1B7A3D`, which also seeds the app's colours. The logo appears on sign-in, in the top bar, on the loading screen, as the browser-tab icon, the install icon (with a crop-safe version for round launchers) and the Android launcher icon. Source, generator script and font are in the team's docs folder (`logo/final`).

## Sign-in (Firebase Auth, project benj-27c66)

**Create a benj account** is the first screen (`lib/screens/auth.dart`): business name, a phone number and/or an email (at least one), password twice, and a consent tick. **Continue with Google** is at the bottom; **About · Privacy** in the footer (`lib/screens/info.dart`).
* **Phone:** the country dropdown defaults to Ghana (+233), where numbers must be 10 digits starting with 0. Other countries use their own length (`lib/core/countries.dart`); errors are one line, e.g. "Ghana numbers should be 10 digits, starting with 0."
* **Business names are unique** on benj, so an owner can sign in with it. A second "Ama Provisions" is asked to add their area.
* **Sign in** takes the business name, phone or email, plus the password. Poddy says "Heyy, good to see you!". **Forgot password?** sends Firebase's reset link to the account's email; accounts without an email write to benj.support@gmail.com (SMS reset can come later).

How it works: Firebase signs a person in with one email-style login (the email, or `233241234567@phone.benj.invalid` for phone-only accounts). `api/accounts.py` keeps a private index (`logins/{sha256(kind:value)}` → account) that the app can never read (`firestore.rules`); the service reads it as its own login (`svc-logins@benj.invalid`) and only reveals an account after Firebase checks the password. Deleting an account removes it from the index.

**One-time setup:** run `python -I scripts/setup_service_login.py` once. It creates the service login on Firebase and stores its random password in Vercel as `BENJ_SVC_PASSWORD` (never printed).

**SMS codes are paused** (Firebase only sends SMS on the paid Blaze plan); the code for them is still in `AuthService`.

Testing without real accounts: run the Auth and Firestore emulators (`firebase emulators:start --project demo-benj --only auth,firestore`), build with `--dart-define=USE_EMULATOR=true`, and run `scripts/dev_server.py` with `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIRESTORE_EMULATOR_HOST=127.0.0.1:8087 BENJ_PROJECT=demo-benj BENJ_SVC_PASSWORD=anything`.

## Poddy, the mascot

Poddy **peeks in from the edge** instead of sitting at the top of the page: from the right on sign-in and Home, from the left on setup and Record, and up from the bottom on Items (`lib/poddy/peek.dart`). He says one short line, a few words at most, then ducks back so only his head shows. His line and mood always come from the owner's records (`lib/poddy/poddy.dart`): "Welcome back, Ama!", "Something's running low!", "Record today's sales?", "Saved. Nice work!". Tap him and he asks "Need help?" with three quick tips for that screen. He blinks, floats and turns towards your finger (`web/poddy/poddy.js`). Phones without WebGL simply don't show him.

**Credits (required by the licence):** Poddy is the 3D model ["Poddy M1 - Stylized Floating Robot - Posed"](https://sketchfab.com/3d-models/poddy-m1-stylized-floating-robot-posed-6b5b90dc52ae4933a103d0a71777ecbd) by [Exmoor beast](https://sketchfab.com/Exmoorbeast), licensed under [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/). We converted it from FBX to glTF, resized its textures to 1024 px with the ambient occlusion baked in, and kept its six held poses as clips. Rendered with [three.js](https://threejs.org) 0.185.1 (MIT, see `web/poddy/three/LICENSE`). The same credit is in the app under ⋮ > Credits.

## Run locally

```bash
python -m pytest tests                    # forecast engine tests
flutter test                              # Dart forecast, budget and phone tests
flutter build web                         # (C:\src\flutter\bin\flutter.bat on Joseph's machine)
python scripts/dev_server.py              # http://localhost:8000  — same routes as Vercel
```

## Deploy (Vercel)

Pushes to `main` deploy automatically. `vercel.json` configures everything: `scripts/vercel_build.sh` installs Flutter and builds `build/web`, and `api/forecast.py` deploys as a Python function. No environment variables are needed. Firestore rules deploy with `firebase deploy --only firestore`.

For an Android build later: `flutter build apk --dart-define=API_BASE=https://<your-app>.vercel.app`

## Tunable numbers

The forecast's built-in numbers are at the top of `api/forecast.py` and `lib/core/forecast.dart` (keep them equal): `z = 1.65` (about 95% cover) and a 14-day demand window. The PRD's thresholds (logging 5 of 7 days, forecast within about 20%) are targets to check against real use, not settings.

## Next steps (not built yet)

1. Voice (F9) and photo of the stock book (F10) input.
2. Weekly reminders by WhatsApp or SMS (F11); SMS also needs a paid plan or a Ghanaian SMS provider.
3. The official Ashesi academic calendar, pre-loaded once the team has the dates.
4. Multiple users per shop (owner and helper), suppliers and one-tap reorder (PRD P2).
