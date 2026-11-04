"""benj forecast service: the same few readable formulas as PRD section 9.

Simple statistics, not a black box. For each product:

    average daily demand   d = mean units sold per day, last 14 days
    calendar adjustment    f = average event factor over the period looked at
    warning level            = d * f * L + z * sd * sqrt(L)     (L = days to next restock)
    suggested quantity     Q = d * f * 7 + z * sd * sqrt(7) - stock on hand

lib/core/forecast.dart mirrors this file so warnings still work offline.
tests/forecast_vectors.json keeps the two honest: both must return the same numbers.

POST /api/forecast  {products, logs, events, today, restockDay}
"""

import json
import math
from datetime import date, datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler

Z = 1.65  # about 95% cover
WINDOW_DAYS = 14
MIN_DAYS = 3  # below this we say "still learning" instead of pretending


def day_of(value):
    return date.fromisoformat(str(value)[:10])


def next_restock(today, restock_day):
    """Days until the next restock day (1 = Monday ... 7 = Sunday). Today counts as a week away."""
    if not restock_day:
        return 7
    return ((int(restock_day) - today.isoweekday() - 1) % 7) + 1


def factor_on(day, events):
    f = 1.0
    for e in events:
        if day_of(e["start"]) <= day <= day_of(e.get("end") or e["start"]):
            f *= float(e.get("factor", 1))
    return f


def average_factor(today, days, events):
    days = max(1, days)
    return sum(factor_on(today + timedelta(days=i + 1), events) for i in range(days)) / days


def daily_series(logs, today):
    """Replays one product's logs. Returns (stock now, demand per day, days it was sold out)."""
    logs = sorted(logs, key=lambda l: str(l["at"]))
    stock = 0.0
    demand = {}
    sold_out = set()
    first = None
    last_day = None

    def carry_sold_out(until):
        # Days with no logs while the shelf is empty are sold-out days too.
        if last_day is not None and stock <= 0:
            d = last_day + timedelta(days=1)
            while d < until:
                sold_out.add(d)
                d += timedelta(days=1)

    for log in logs:
        day = day_of(log["at"])
        if day > today:
            continue
        first = first or day
        carry_sold_out(day)
        last_day = day
        qty = float(log["quantity"])
        kind = log["type"]
        if kind == "restock":
            stock += qty
        elif kind == "sale":
            stock = max(0.0, stock - qty)
            demand[day] = demand.get(day, 0.0) + qty
        elif kind == "count":
            # A count below what we expected means units left that nobody logged.
            if qty < stock:
                demand[day] = demand.get(day, 0.0) + (stock - qty)
            stock = qty
        if stock <= 0:
            sold_out.add(day)
        else:
            sold_out.discard(day)
    carry_sold_out(today + timedelta(days=1))
    return stock, demand, sold_out, first


def stats(demand, sold_out, first, today):
    """Mean and spread over closed days. Sold-out days are skipped: zero sales there
    means no stock, not no demand."""
    if first is None:
        return 0.0, 0.0, 0
    start = max(first, today - timedelta(days=WINDOW_DAYS))
    days = []
    d = start
    while d < today:
        if d not in sold_out or demand.get(d, 0) > 0:
            days.append(demand.get(d, 0.0))
        d += timedelta(days=1)
    if not days:  # Only today so far.
        days = [demand.get(today, 0.0)]
    n = len(days)
    mean = sum(days) / n
    sd = math.sqrt(sum((x - mean) ** 2 for x in days) / (n - 1)) if n > 1 else 0.0
    return mean, sd, n


def forecast_product(product, logs, events, today, restock_day):
    stock, demand, sold_out, first = daily_series(logs, today)
    mean, sd, n = stats(demand, sold_out, first, today)
    lead = next_restock(today, restock_day)
    f_lead = average_factor(today, lead, events)
    f_week = average_factor(today, 7, events)
    suggested_warning = math.ceil(mean * f_lead * lead + Z * sd * math.sqrt(lead)) if n else 0
    owner_warning = product.get("warningLevel")
    warning = float(owner_warning) if owner_warning is not None else float(suggested_warning)
    week_demand = mean * f_week * 7
    qty = max(0, math.ceil(week_demand + Z * sd * math.sqrt(7) - stock)) if n else 0
    rate = mean * f_week
    days_left = stock / rate if rate > 0 else None
    return {
        "product": product["id"],
        "stock": round(stock, 2),
        "meanDaily": round(mean, 3),
        "sdDaily": round(sd, 3),
        "daysOfData": n,
        "learning": n < MIN_DAYS,
        "factor": round(f_week, 3),
        "leadDays": lead,
        "suggestedWarning": suggested_warning,
        "warningLevel": warning,
        "isLow": n > 0 and stock <= warning or (first is not None and stock <= 0),
        "daysLeft": round(days_left, 2) if days_left is not None else None,
        "weekDemand": round(week_demand, 2),
        "suggestedQty": qty,
    }


def forecast(data):
    today = day_of(data.get("today") or date.today().isoformat())
    restock_day = data.get("restockDay")
    events = data.get("events") or []
    logs = data.get("logs") or []
    out = []
    for p in data.get("products") or []:
        mine = [l for l in logs if l["product"] == p["id"]]
        out.append(forecast_product(p, mine, events, today, restock_day))
    return {"today": today.isoformat(), "results": out, "at": datetime.now(timezone.utc).isoformat()}


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
        self._send(200, {"ok": True, "service": "benj forecast", "usage": "POST products, logs, events"})

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            self._send(200, forecast(json.loads(self.rfile.read(length) or b"{}")))
        except Exception as exc:  # Bad input must not take the app down.
            self._send(400, {"error": str(exc)})
