# SeeYou — v1 concept MVP

**Team Benj · XANIX Challenge 2026 · Opportunity: "The Business That Can't See Itself"**

> Your business already tells a story every day. We help you read it — and tell you what to do next.

## Who it's for

Owner-run food and provisions businesses near Ashesi (Berekuso) that **tally sales and stock by hand**: the rice seller, the waakye stand, the campus snack shop. Bigger operators with a POS are explicitly out of scope, because they can already see themselves.

## What makes it different

Ghana already has record-keeping tools (SikaBooks, Chopmoney, OZÉ, Bumpa, Kippa). They all give the owner **dashboards**. SeeYou gives **decisions**:

| Typical bookkeeping app | SeeYou |
|---|---|
| Charts the owner never opens | **3 plain actions a week**, each with the reason and the cedis at stake |
| One low-stock alert per item | **One market list** for the next trip: "buy 14 bags rice; 13 bottles oil…" |
| Doesn't know the calendar | **Knows campus rhythm**: "Mid-sem break starts Friday — make 45% less waakye" |
| Records sales | Spots **waste** ("you threw away 44 plates = GHS 528") and **weekday patterns** ("Saturdays sell 55% less bread") |
| Keeps the owner inside the app | Sends the week as a **WhatsApp message**, ready to share |
| Assumes the advice works | **"I did this"** on each action measures whether advice changes behaviour (our north-star metric) |

## Try it

- Open the deployment with `?demo` on the end (e.g. `https://<your-app>.vercel.app/?demo`). This loads **Auntie Esi's Provisions & Waakye**, a simulated shop with 4 weeks of records that triggers every rule.
- Or set up your own shop from a template (rice/provisions, food vendor, campus snacks), enter today's stock, then record at the end of each day.

## How it works

```
 Flutter app (on the phone)                     Python insight engine (Vercel function)
 ─────────────────────────                      ──────────────────────────────────────
 Record tab: end-of-day tally   ── records ──▶  api/insights.py
 (sold / bought / thrown away)                   stock on hand, weekly sales & profit
 Items tab: stock + margin                        rules R1–R8 → ranked actions
 This week tab: 3 actions  ◀── 3 actions ───    WhatsApp weekly message
 + WhatsApp share + "I did this"
```

- **No logins, no database (yet).** Records live on the phone (`shared_preferences`). The engine is stateless: the app sends its records and gets advice back. The owner's data stays the owner's (PRD principle).
- **Every insight is a one-sentence rule** (PRD §13). No ML until we have weeks of real data.

| Rule | What it says | Where |
|---|---|---|
| R1/R2 Low stock + run-out forecast | One combined market list, sized to cover a week | `rule_restock` |
| R3 Top/bottom earners | "Waakye made 41% of your profit — never run out" | `rule_profit_mix` |
| R4 Weekday pattern (3+ weeks of data) | "On Saturdays prepare ~10 bread, not 18" | `rule_weekday` |
| R5 Margin squeeze | "Supplier price went up 9→11; raise to GHS 15" | `rule_margin` |
| R7 Calendar shift | Ashesi calendar events → prep advice | `rule_calendar` + `CALENDAR` |
| R8 Data gap | "Send us today's tally" | `rule_data_gap` |
| Waste | "You threw away 23% of waakye — make about 28 a day" | `rule_waste` |

Actions are ranked by urgency, then by **cedis at stake**, with at most one per rule. The owner only ever sees 3.

## Run locally

```bash
python -m unittest discover tests        # engine tests
flutter build web                         # (C:\src\flutter\bin\flutter.bat on Joseph's machine)
python scripts/dev_server.py              # http://localhost:8000  — same routes as Vercel
```

## Deploy (Vercel)

Import the GitHub repo into Vercel. `vercel.json` already configures everything: `scripts/vercel_build.sh` installs Flutter and builds `build/web`, and `api/insights.py` deploys as a Python function. No environment variables are needed.

For an Android build later: `flutter build apk --dart-define=API_BASE=https://<your-app>.vercel.app`

## Placeholders to replace with evidence

- `CALENDAR` dates in `api/insights.py` are **guesses**. Replace them with the official Ashesi academic calendar.
- Template prices in `lib/templates.dart` are rough estimates. Confirm them in interviews.
- Thresholds (`RUNOUT_DAYS`, `WASTE_SHARE`, `THIN_MARGIN`…) are the PRD's `[X]` placeholders.

## Next steps (deliberately not built yet)

1. Phone-OTP login + cloud database (Firebase/Supabase) so the team can see usage (FR-A1, FR-E1).
2. Automated weekly WhatsApp send via the Business Cloud API (FR-D2). Today the owner taps "Send to WhatsApp".
3. Average sales only over days the item was **in stock**. Today a stock-out makes demand look lower than it is.
4. Physical count vs expected (R6), expenses, payment type (cash / MoMo / credit), credit "who owes me".
5. Photo-of-tally-sheet and voice-note entry; Twi labels.
6. A real offline queue (records already save offline; only the advice needs a network).
