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
| Doesn't know the calendar | **Knows the owner's rhythm**: the owner adds busy or quiet days (school break, exams), and advice adjusts the week before |
| Records sales | Spots **waste** (how much was thrown away, in cedis) and **weekday patterns** (which days sell less) |
| Keeps the owner inside the app | Sends the week as a **WhatsApp message**, ready to share |
| Assumes the advice works | **"I did this"** on each action measures whether advice changes behaviour (our north-star metric) |

## Try it

The app starts empty. There is no demo or sample data; everything you see comes from what the owner enters.

1. Name the business.
2. **Items** tab: add each item with what you pay, what you charge, your reorder level, and how many you have now. Optionally add upcoming busy or quiet days.
3. **Record** tab: at the end of each day, enter how many were sold, bought/made, or thrown away.
4. **This week** tab: see the 3 actions, then send them to WhatsApp. Weekday patterns appear after 3 weeks of records.

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

| Rule | What it looks at | Where |
|---|---|---|
| R1/R2 Low stock + run-out forecast | One combined market list, sized to cover a week | `rule_restock` |
| R3 Top/bottom earners | Which item makes most of the profit, and which loses money | `rule_profit_mix` |
| R4 Weekday pattern (3+ weeks of data) | Days that sell ≥25% less/more of a fresh item | `rule_weekday` |
| R5 Margin squeeze | Supplier price rose (from "Bought" entries) → suggested new price | `rule_margin` |
| R7 Calendar shift | Busy or quiet days the owner entered | `rule_calendar` |
| R8 Data gap | No tally for 2+ days | `rule_data_gap` |
| Waste | More than 10% of a fresh item thrown away | `rule_waste` |

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

## Tunable thresholds

The only built-in numbers are the rule thresholds at the top of `api/insights.py` (`RUNOUT_DAYS`, `WASTE_SHARE`, `THIN_MARGIN`…). These are the PRD's `[X]` placeholders: tune them from interview evidence.

## Next steps (deliberately not built yet)

1. Phone-OTP login + cloud database (Firebase/Supabase) so the team can see usage (FR-A1, FR-E1).
2. Automated weekly WhatsApp send via the Business Cloud API (FR-D2). Today the owner taps "Send to WhatsApp".
3. Average sales only over days the item was **in stock**. Today a stock-out makes demand look lower than it is.
4. Physical count vs expected (R6), expenses, payment type (cash / MoMo / credit), credit "who owes me".
5. Business-type starter item lists (once interviews give us real prices), photo-of-tally-sheet and voice-note entry; Twi labels.
6. A real offline queue (records already save offline; only the advice needs a network).
