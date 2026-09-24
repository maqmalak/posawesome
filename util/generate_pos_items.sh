#!/usr/bin/env bash
#
# Creates (or repairs) the POS Awesome demo catalog: Item Groups "Foods Items",
# "Beverages", "add-on" under "POS Products", 5 items each with a generated
# icon image, a Standard Selling price (PKR), a default warehouse + selling
# cost center, and opening stock at the default warehouse.
#
# Idempotent: safe to re-run. Existing items are left alone except that their
# Item Default (warehouse / cost center) is repaired if missing, and opening
# stock is only posted for items that currently have zero stock in that
# warehouse.
#
# Usage:
#   ./generate_pos_items.sh [site] [warehouse] [company]
#
# Defaults match this bench's current setup:
#   site      = micromaxerp
#   warehouse = Branch Lahore - MEPL
#   company   = MicroMax Erp Pvt Ltd.

set -euo pipefail

SITE="${1:-micromaxerp}"
WAREHOUSE="${2:-Branch Lahore - MEPL}"
COMPANY="${3:-MicroMax Erp Pvt Ltd.}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PAYLOAD="$(mktemp /tmp/generate_pos_items.XXXXXX.py)"
trap 'rm -f "$PAYLOAD"' EXIT

cat > "$PAYLOAD" <<'PYEOF'
import frappe
from frappe.utils.file_manager import save_file

COMPANY = "__COMPANY__"
WAREHOUSE = "__WAREHOUSE__"
PRICE_LIST = "Standard Selling"
CURRENCY = "PKR"
UOM = "Nos"
OPENING_QTY = 50

CATEGORIES = [
    {
        "group": "Foods Items",
        "prefix": "FOOD",
        "color": "#ea580c",
        "tint": "#fdece0",
        "items": [
            ("Grilled Chicken Sandwich", "\U0001F96A", 450),
            ("Beef Burger", "\U0001F354", 500),
            ("Margherita Pizza Slice", "\U0001F355", 350),
            ("Chicken Biryani", "\U0001F35B", 400),
            ("Club Sandwich", "\U0001F959", 420),
        ],
    },
    {
        "group": "Beverages",
        "prefix": "BEV",
        "color": "#0d9488",
        "tint": "#e0f5f3",
        "items": [
            ("Fresh Orange Juice", "\U0001F34A", 200),
            ("Cappuccino", "☕", 250),
            ("Iced Latte", "\U0001F964", 280),
            ("Mineral Water", "\U0001F4A7", 80),
            ("Mint Lemonade", "\U0001F34B", 180),
        ],
    },
    {
        "group": "add-on",
        "prefix": "ADDON",
        "color": "#d97706",
        "tint": "#fdf1dc",
        "items": [
            ("French Fries", "\U0001F35F", 200),
            ("Garlic Bread", "\U0001F956", 220),
            ("Coleslaw", "\U0001F957", 150),
            ("Onion Rings", "\U0001F9C5", 220),
            ("Extra Cheese", "\U0001F9C0", 100),
        ],
    },
]


def make_svg(emoji: str, color: str, tint: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
  <circle cx="60" cy="60" r="56" fill="{tint}" stroke="{color}" stroke-width="2" stroke-opacity="0.4"/>
  <circle cx="60" cy="60" r="46" fill="{color}" fill-opacity="0.12"/>
  <text x="60" y="76" font-size="54" text-anchor="middle" font-family="'Noto Color Emoji','Apple Color Emoji','Segoe UI Emoji',sans-serif">{emoji}</text>
</svg>'''


def ensure_item_defaults(item_doc) -> bool:
    """Make sure this item's Item Default row (for COMPANY) has both the
    default warehouse and selling cost center set. Returns True if changed."""
    changed = False
    # ERPNext's own Stock Reconciliation submit auto-fills a blank Item Default
    # warehouse with its own default (Stock Settings / company fallback), so a
    # simple "only fill if blank" check isn't enough here — force it to WAREHOUSE.
    row = next((r for r in item_doc.item_defaults if r.company == COMPANY), None)
    if row is None:
        item_doc.append(
            "item_defaults",
            {
                "company": COMPANY,
                "default_warehouse": WAREHOUSE,
                "selling_cost_center": frappe.db.get_value("Company", COMPANY, "cost_center"),
            },
        )
        changed = True
    else:
        if row.default_warehouse != WAREHOUSE:
            row.default_warehouse = WAREHOUSE
            changed = True
        if not row.selling_cost_center:
            row.selling_cost_center = frappe.db.get_value("Company", COMPANY, "cost_center")
            changed = True
    return changed


def ensure_opening_stock(item_code: str, valuation_rate: float, recon_rows: list):
    existing_qty = frappe.db.get_value(
        "Bin", {"item_code": item_code, "warehouse": WAREHOUSE}, "actual_qty"
    )
    if not existing_qty:
        recon_rows.append(
            {
                "item_code": item_code,
                "warehouse": WAREHOUSE,
                "qty": OPENING_QTY,
                "valuation_rate": valuation_rate,
            }
        )


def run():
    report = []
    recon_rows = []

    for cat in CATEGORIES:
        if not frappe.db.exists("Item Group", cat["group"]):
            raise Exception(f"Item Group missing: {cat['group']}")

        for idx, (name, emoji, rate) in enumerate(cat["items"], start=1):
            item_code = f"{cat['prefix']}-{idx:03d}"
            valuation_rate = round(rate * 0.45, 2)

            if frappe.db.exists("Item", item_code):
                item = frappe.get_doc("Item", item_code)
                changed = ensure_item_defaults(item)
                if changed:
                    item.save(ignore_permissions=True)
                ensure_opening_stock(item_code, valuation_rate, recon_rows)
                report.append((item_code, "repaired" if changed else "already ok"))
                continue

            item = frappe.new_doc("Item")
            item.item_code = item_code
            item.item_name = name
            item.item_group = cat["group"]
            item.stock_uom = UOM
            item.is_stock_item = 1
            ensure_item_defaults(item)
            item.insert(ignore_permissions=True)

            svg = make_svg(emoji, cat["color"], cat["tint"])
            file_doc = save_file(f"{item_code}.svg", svg, "Item", item_code, is_private=0, decode=False)
            frappe.db.set_value("Item", item_code, "image", file_doc.file_url)

            if not frappe.db.exists(
                "Item Price", {"item_code": item_code, "price_list": PRICE_LIST}
            ):
                ip = frappe.new_doc("Item Price")
                ip.item_code = item_code
                ip.price_list = PRICE_LIST
                ip.currency = CURRENCY
                ip.price_list_rate = rate
                ip.selling = 1
                ip.insert(ignore_permissions=True)

            ensure_opening_stock(item_code, valuation_rate, recon_rows)
            report.append((item_code, "created"))

    if recon_rows:
        sr = frappe.new_doc("Stock Reconciliation")
        sr.company = COMPANY
        sr.purpose = "Opening Stock"
        sr.expense_account = frappe.db.get_value("Company", COMPANY, "default_inventory_account")
        for row in recon_rows:
            sr.append("items", row)
        sr.insert(ignore_permissions=True)
        sr.submit()
        report.append(("Stock Reconciliation", sr.name))

    frappe.db.commit()
    return report


for code, label in run():
    print(code, "->", label)
PYEOF

sed -i "s|__COMPANY__|${COMPANY}|; s|__WAREHOUSE__|${WAREHOUSE}|" "$PAYLOAD"

cd "$BENCH_ROOT"
printf "exec(open('%s').read(), globals())\n" "$PAYLOAD" | bench --site "$SITE" console
