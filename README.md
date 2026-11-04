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
| F1 | Shop setup: business name at sign-up; products with unit, size, prices; location, phone, restock day in Settings | `screens/auth.dart`, `product_form.dart`, `settings.dart` |
| F2 | Quick stock log: +/- per product or a count, one screen, saves offline; seconds per entry recorded | `screens/log.dart` |
| F3 | Restock entry: quantity and price per product | `screens/log.dart` (Bought) |
| F4 | Low-stock warning with days left; owner's level or benj's suggestion | `screens/home.dart`, `product.dart` |
| F5 | Weekly buying list with plain-language lines | `screens/buy.dart` |
| F6 | Campus calendar: owner-added events with a demand change, shown on the list | `settings.dart`, `buy.dart` |
| F7 | Forecast vs actual, per product per week, with error | `screens/product.dart` |
| F8 | Stock dashboard: line per product, week/month, sort by name / lowest / fastest, today marked, variant colours | `screens/stock.dart` |
| F12 | Budget-aware list: most at-risk items first, "cash covers 1 of the 7 you need" | `screens/buy.dart` |

Not built yet: F9 voice, F10 photo, F11 WhatsApp/SMS reminders (the list can be sent to WhatsApp by hand). The **official Ashesi academic calendar** is not pre-loaded: we could not find published dates, so owners add events themselves until the team adds the real dates.

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

The first screen (`lib/screens/auth.dart`) is the **Create a benj account** form: business name, phone number, password, repeat password and a consent tick. Below it: **Continue with Google**, **Continue with email**, "Already have a benj account? **Sign in**", and **About · Privacy** in the footer (`lib/screens/info.dart`, written as plain sections so the team can update them).
* **Phone numbers:** the country dropdown defaults to Ghana (+233), where the number must be exactly 10 digits starting with 0 (024 123 4567 becomes +233 24 123 4567). Other countries in the dropdown use their own length (`lib/core/countries.dart`).
* **A benj account** is a Firebase email/password account whose id is the number at a reserved address (`233241234567@phone.benj.invalid`, which can never receive mail). No SMS is sent, so it costs nothing. The number is not verified, and a forgotten password is reset by a teammate in the Firebase console when the owner emails **benj.support@gmail.com**.
* **Google** is one tap; **email** has its own screen with "Forgot password" by email.

The sign-in and email screens have a back button and Poddy hovering at the top. Errors are explained in plain English (`lib/auth_service.dart`).

**Privacy page:** based on Ghana's Data Protection Act, 2012 (Act 843) and Firebase's guidance on disclosing what an app collects. It states that registration with the Data Protection Commission will be completed before a public launch; the team must make that true.

**SMS codes are paused.** Firebase only sends SMS on the paid Blaze plan. The code for real SMS verification is still in `AuthService`, ready if the team turns on Blaze or wires a Ghanaian SMS provider instead.

Testing without real accounts: run `firebase emulators:start --project demo-benj --only auth`, then `flutter build web --dart-define=USE_EMULATOR=true`.

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
