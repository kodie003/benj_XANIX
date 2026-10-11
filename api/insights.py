"""SeeYou insight engine - turns a small business's daily tally into 3 plain actions.

This is the heart of the product (PRD section 13). Every insight is a rule we
can explain in one sentence; no machine learning until we have weeks of data.

The engine is stateless: the app sends the business's whole record (items +
stock movements) and gets back numbers, alerts and the weekly WhatsApp message.
Nothing is stored server-side, so the owner's data stays on the owner's phone.

Served on Vercel as a Python function:
    POST /api/insights   body = {business, items, movements, events?, today?}
    GET  /api/insights   -> health check
"""

import json
import math
from collections import defaultdict
from datetime import date, timedelta
from http.server import BaseHTTPRequestHandler

# --- Tunable thresholds (the [placeholders] in the PRD) ---------------------
RUNOUT_DAYS = 2  # R2: warn when stock lasts fewer than this many days
COVER_DAYS = 7  # suggested restock should last about a week
DATA_GAP_DAYS = 2  # R8: nudge when nothing recorded for this long
WEEKDAY_SWING = 0.25  # R4: flag weekday differences of 25% or more
MIN_WEEKS_FOR_PATTERN = 3
THIN_MARGIN = 0.85  # R5: cost is more than 85% of the selling price
WASTE_SHARE = 0.10  # perishables: more than 10% thrown away
MAX_ACTIONS = 3

WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


def cedis(amount):
    """Money in plain cedis, no decimals unless needed (PRD UX notes)."""
    if abs(amount - round(amount)) < 0.05:
        return f"GHS {round(amount):,}"
    return f"GHS {amount:,.2f}"


def qty(n, unit):
    n = round(n, 1)
    n = int(n) if n == int(n) else n
    plural = unit if n == 1 or unit.endswith("s") else unit + "s"
    return f"{n} {plural}"


# --- Core computation ---------------------------------------------------------


def analyse(data):
    business = data.get("business", {})
    items = {i["id"]: i for i in data.get("items", [])}
    moves = data.get("movements", [])
    today = date.fromisoformat(data.get("today") or date.today().isoformat())

    # FR-C1: stock on hand = opening + received - sold - wasted
    stock = defaultdict(float)
    sold_by_day = defaultdict(lambda: defaultdict(float))  # item -> day -> qty
    waste_by_day = defaultdict(lambda: defaultdict(float))
    recorded_days = set()
    latest_cost = {}
    for m in sorted(moves, key=lambda m: m["date"]):
        item_id, kind, q = m["item"], m["type"], float(m["qty"])
        if item_id not in items:
            continue
        day = date.fromisoformat(m["date"])
        if kind in ("opening", "received"):
            stock[item_id] += q
            if m.get("cost"):
                latest_cost[item_id] = float(m["cost"])
        elif kind == "sale":
            stock[item_id] -= q
            sold_by_day[item_id][day] += q
            recorded_days.add(day)
        elif kind == "waste":
            stock[item_id] -= q
            waste_by_day[item_id][day] += q
            recorded_days.add(day)

    week = [today - timedelta(days=d) for d in range(0, 7)]
    last_week = [today - timedelta(days=d) for d in range(7, 14)]
    days_recorded_this_week = max(1, len([d for d in week if d in recorded_days]))

    def total(by_day, item_id, days):
        return sum(by_day[item_id].get(d, 0) for d in days)

    def cost_of(item_id):
        return latest_cost.get(item_id, float(items[item_id]["cost"]))

    rows = []
    for item_id, it in items.items():
        price = float(it["price"])
        cost = cost_of(item_id)
        sold_wk = total(sold_by_day, item_id, week)
        waste_wk = total(waste_by_day, item_id, week)
        avg_daily = sold_wk / days_recorded_this_week
        on_hand = max(0.0, stock[item_id])
        rows.append(
            {
                "id": item_id,
                "name": it["name"],
                "unit": it.get("unit", "piece"),
                "price": price,
                "cost": cost,
                "listed_cost": float(it["cost"]),
                "perishable": bool(it.get("perishable")),
                "reorder": float(it.get("reorder", 0)),
                "on_hand": on_hand,
                "avg_daily": avg_daily,
                "days_left": (on_hand / avg_daily) if avg_daily > 0 else None,
                "sold_week": sold_wk,
                "waste_week": waste_wk,
                "sales_week": sold_wk * price,
                "profit_week": sold_wk * (price - cost) - waste_wk * cost,
                "margin": (price - cost) / price if price else 0,
            }
        )

    def sales_on(days):
        return sum(total(sold_by_day, r["id"], days) * r["price"] for r in rows)

    summary = {
        "today_sales": sales_on([today]),
        "week_sales": sales_on(week),
        "last_week_sales": sales_on(last_week),
        "week_profit": sum(r["profit_week"] for r in rows),
        "days_recorded": len([d for d in week if d in recorded_days]),
        "top_items": [
            r["name"] for r in sorted(rows, key=lambda r: -r["sales_week"])[:3] if r["sales_week"] > 0
        ],
    }

    actions = []
    if not items:
        actions.append(action("R8", "Add the items you sell", "Go to the Items tab and add each item with what you pay and what you charge.", 0, 3))
    else:
        actions += rule_data_gap(recorded_days, today)
    actions += rule_restock(rows, today)
    actions += rule_weekday(rows, sold_by_day, recorded_days, today)
    actions += rule_waste(rows)
    actions += rule_margin(rows)
    actions += rule_calendar(rows, data.get("events", []), today)
    actions += rule_profit_mix(rows, summary)

    # Rank: urgent first, then by money at stake. The owner only sees 3,
    # and at most one per rule so the week's advice covers different decisions.
    actions.sort(key=lambda a: (-a["urgency"], -a["impact"]))
    top, more, seen = [], [], set()
    for a in actions:
        if len(top) < MAX_ACTIONS and a["rule"] not in seen:
            top.append(a)
            seen.add(a["rule"])
        else:
            more.append(a)

    return {
        "business": business.get("name", "Your business"),
        "today": today.isoformat(),
        "summary": summary,
        "items": [
            {k: r[k] for k in ("id", "name", "unit", "on_hand", "avg_daily", "days_left", "margin", "profit_week", "cost")}
            for r in rows
        ],
        "actions": top,
        "more": more,
        "whatsapp": whatsapp_message(business, summary, top),
    }


def action(rule, title, why, impact, urgency):
    """impact = rough cedis at stake this week, so we can rank and say why it matters."""
    return {"rule": rule, "title": title, "why": why, "impact": round(impact, 2), "urgency": urgency}


# --- Insight rules (PRD section 13) ------------------------------------------


def rule_data_gap(recorded_days, today):  # R8
    if not recorded_days:
        return [action("R8", "Record your first day's sales", "We need at least a few days of tallies before we can advise you.", 0, 3)]
    gap = (today - max(recorded_days)).days
    if gap >= DATA_GAP_DAYS:
        return [
            action(
                "R8",
                "Send us today's tally",
                f"We haven't seen your numbers for {gap} days, so the advice below may be out of date.",
                0,
                3,
            )
        ]
    return []


def rule_restock(rows, today):  # R1 low stock + R2 run-out forecast
    """One combined market list - owners restock in one trip, not item by item."""
    lines, reasons, lost = [], [], 0.0
    for r in rows:
        if r["perishable"]:  # made or bought fresh each day; handled by the waste/weekday rules
            continue
        low = r["on_hand"] <= r["reorder"]
        runs_out = r["days_left"] is not None and r["days_left"] < RUNOUT_DAYS
        if not (low or runs_out) or r["avg_daily"] == 0:
            continue
        need = max(1, math.ceil(r["avg_daily"] * COVER_DAYS - r["on_hand"]))
        lines.append(f"{qty(need, r['unit'])} of {r['name']}")
        lost += r["avg_daily"] * (r["price"] - r["cost"]) * 2  # ~2 days of lost profit if you run dry
        if r["on_hand"] == 0:
            reasons.append(f"{r['name']}: finished")
        elif runs_out:
            run_day = today + timedelta(days=max(1, int(r["days_left"])))
            reasons.append(f"{r['name']}: runs out by {WEEKDAYS[run_day.weekday()]} at this pace")
        else:
            reasons.append(f"{r['name']}: only {qty(r['on_hand'], r['unit'])} left")
    if not lines:
        return []
    return [
        action(
            "R1",
            "Market list: buy " + "; ".join(lines),
            f"{'; '.join(reasons)}. These amounts cover about a week of your usual sales. "
            f"Running out would cost you about {cedis(lost)} in profit every 2 days.",
            lost,
            2,
        )
    ]


def rule_weekday(rows, sold_by_day, recorded_days, today):  # R4
    span = sorted(recorded_days)
    if not span or (span[-1] - span[0]).days < MIN_WEEKS_FOR_PATTERN * 7 - 1:
        return []
    open_days = {d.weekday() for d in span}
    out = []
    for r in rows:
        if not r["perishable"]:
            continue
        by_day = sold_by_day[r["id"]]
        overall = [by_day.get(d, 0) for d in span]
        avg_all = sum(overall) / len(overall)
        if not avg_all:
            continue
        best = None
        for wd in open_days:
            same = [by_day.get(d, 0) for d in span if d.weekday() == wd]
            if len(same) < MIN_WEEKS_FOR_PATTERN:
                continue
            avg_same = sum(same) / len(same)
            swing = (avg_same - avg_all) / avg_all
            if abs(swing) >= WEEKDAY_SWING and (best is None or abs(swing) > abs(best[1])):
                best = (wd, swing, avg_same)
        if not best:
            continue
        wd, swing, avg_same = best
        word = "less" if swing < 0 else "more"
        out.append(
            action(
                "R4",
                f"On {WEEKDAYS[wd]}s, prepare about {round(avg_same)} {r['name']}, not {round(avg_all)}",
                f"For {len(span) // 7} weeks you have sold {abs(swing):.0%} {word} {r['name']} on {WEEKDAYS[wd]}s "
                f"(about {avg_same:.0f} vs {avg_all:.0f} on other days).",
                abs(avg_same - avg_all) * (r["cost"] if swing < 0 else r["price"] - r["cost"]),
                1,
            )
        )
    return out


def rule_waste(rows):  # FR-B4 / "cook less"
    out = []
    for r in rows:
        made = r["sold_week"] + r["waste_week"]
        if not r["perishable"] or not made or r["waste_week"] / made <= WASTE_SHARE:
            continue
        lost = r["waste_week"] * r["cost"]
        per_day = max(1, math.ceil(r["avg_daily"] * 1.1))  # what you really sell, plus a small buffer
        out.append(
            action(
                "WASTE",
                f"Make or buy less {r['name']} - about {per_day} a day",
                f"You threw away {qty(r['waste_week'], r['unit'])} this week ({r['waste_week'] / made:.0%} of what you had), "
                f"which cost you {cedis(lost)}.",
                lost,
                1,
            )
        )
    return out


def rule_margin(rows):  # R5 margin squeeze
    out = []
    for r in rows:
        if r["price"] <= 0 or r["cost"] / r["price"] <= THIN_MARGIN:
            continue
        rose = r["cost"] > r["listed_cost"] * 1.05
        old_share = r["listed_cost"] / r["price"] if rose else 0.75  # keep the margin you used to have
        new_price = math.ceil(r["cost"] / old_share)
        keep = r["price"] - r["cost"]
        reason = (
            f"Your supplier price went up from {cedis(r['listed_cost'])} to {cedis(r['cost'])}. "
            if rose
            else ""
        )
        out.append(
            action(
                "R5",
                f"Raise the price of {r['name']} to about {cedis(new_price)}",
                f"{reason}You now keep only {cedis(keep)} on each {r['unit']} you sell at {cedis(r['price'])}.",
                r["sold_week"] * (new_price - r["price"]),
                1,
            )
        )
    return out


def rule_calendar(rows, events, today):  # R7 local rhythm
    """events come from the owner: {name, start, effect} - effect is the expected
    change in customers, e.g. -0.4 for a school break, +0.3 for a campus event."""
    out = []
    for ev in events:
        start = date.fromisoformat(ev["start"])
        lead = (start - today).days
        if not 0 <= lead <= 7:
            continue
        when = "today" if lead == 0 else "tomorrow" if lead == 1 else f"on {WEEKDAYS[start.weekday()]}"
        perishables = [r["name"] for r in rows if r["perishable"]][:3]
        if ev["effect"] < 0:
            what = f"make {abs(ev['effect']):.0%} less {', '.join(perishables)}" if perishables else "don't overstock"
            title = f"{ev['name']} starts {when}: {what}"
            why = f"You expect about {abs(ev['effect']):.0%} fewer customers then."
        else:
            title = f"{ev['name']} {when}: stock about {ev['effect']:.0%} more of your best sellers"
            why = f"You expect about {ev['effect']:.0%} more customers then."
        week_sales = sum(r["sales_week"] for r in rows)
        out.append(action("R7", title, why, week_sales * abs(ev["effect"]) * 0.2, 2 if lead <= 3 else 1))
    return out


def rule_profit_mix(rows, summary):  # R3 top and bottom earners
    earners = [r for r in rows if r["sold_week"] > 0]
    total_profit = sum(r["profit_week"] for r in earners)
    if len(earners) < 2 or total_profit <= 0:
        return []
    best = max(earners, key=lambda r: r["profit_week"])
    worst = min(earners, key=lambda r: r["profit_week"])
    out = [
        action(
            "R3",
            f"Never run out of {best['name']}",
            f"It made {best['profit_week'] / total_profit:.0%} of your profit this week ({cedis(best['profit_week'])}).",
            best["profit_week"] * 0.1,
            0,
        )
    ]
    if worst["profit_week"] <= 0:
        out.append(
            action(
                "R3",
                f"Rethink {worst['name']} - it lost money this week",
                f"After cost and waste it made {cedis(worst['profit_week'])}. Raise the price, buy less, or drop it.",
                abs(worst["profit_week"]),
                1,
            )
        )
    return out


# --- Delivery -------------------------------------------------------------------


def whatsapp_message(business, s, actions):
    """PRD section 13 weekly summary format - max 3 actions, each with a reason."""
    owner = business.get("owner") or business.get("name") or "there"
    lines = [f"Good evening {owner} - your week in 30 seconds:"]
    lines.append(f"- Sales: {cedis(s['week_sales'])}{change(s['week_sales'], s['last_week_sales'])}")
    lines.append(f"- Profit (estimate): {cedis(s['week_profit'])}")
    if s["top_items"]:
        lines.append(f"- Best sellers: {', '.join(s['top_items'])}")
    if actions:
        lines.append("")
        lines.append("Actions for next week:")
        for n, a in enumerate(actions, 1):
            lines.append(f"{n}. {a['title']}. {a['why']}")
        lines.append("")
        lines.append("Reply 1, 2 or 3 to tell us which you'll do.")
    return "\n".join(lines)


def change(now, before):
    if not before:
        return ""
    pct = (now - before) / before
    return f" ({'up' if pct >= 0 else 'down'} {abs(pct):.0%} vs last week)"


# --- Vercel handler -----------------------------------------------------------------


class handler(BaseHTTPRequestHandler):
    def _send(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(payload)

    def do_OPTIONS(self):
        self._send(204, {})

    def do_GET(self):
        self._send(200, {"ok": True, "engine": "SeeYou insights", "usage": "POST your records here"})

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(length) or b"{}")
            self._send(200, analyse(data))
        except Exception as exc:  # keep the app alive on bad input
            self._send(400, {"error": str(exc)})
