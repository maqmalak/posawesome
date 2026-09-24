# Post-Install Defaults — MicroMax / POS Awesome

Site: `micromaxerp` · Company: `MicroMax Erp Pvt Ltd.` (MEPL)

Everything below was configured **after** `bench install-app` / `bench migrate` for
`micromax` and `posawesome` — i.e. the manual setup layered on top of a clean app
install.

---

## 1. MicroMax app

### 1.1 Micromax Defaults (new Single DocType)
`apps/micromax/micromax/micromax/doctype/micromax_defaults/`

Site-wide UI defaults, editable at **MicroMax → Settings → Micromax Defaults**
(System Manager only):

| Field | Options | Default |
|---|---|---|
| Theme | dark / light | dark |
| Table Rows Per Page | 10 / 20 / 50 / 100 | 20 |
| View | list / card / pipeline | list |
| Default Docstatus Filter | 0 Draft / 1 Submitted / 2 Cancelled | 2 |

Exposed to other code via `micromax.micromax.doctype.micromax_defaults.micromax_defaults.get_micromax_defaults()`.

A **Link** shortcut to this doctype was added to the MicroMax workspace
(`micromax/micromax/workspace/micromax/micromax.json`, under the "Settings" card).

### 1.2 Fixed a recurring duplicate-field bug
`apps/micromax/micromax/install.py`

`before_migrate` was unconditionally recreating two Custom Fields that ERPNext
v16 now ships natively:

- `Sales Order.incoterm`
- `Item.country_of_origin`

Every `bench migrate` re-added them on top of the native fields, producing
duplicate fieldnames (surfaced later as `Fieldname X appears multiple times in
rows` on unrelated saves). Added `_drop_fields_that_now_exist_natively()`,
which skips creating a custom field when a same-named native field already
exists and no Custom Field record for it does. The two stray Custom Field
records were deleted once; the guard prevents them coming back on future
migrates.

---

## 2. POS Awesome — "Branch Lahore" POS Profile

Set up per `apps/posawesome/README.md`'s Quick Start (steps 3–4) plus its
optional operational settings.

### 2.1 Prerequisite masters created
| Doctype | Name | Notes |
|---|---|---|
| Warehouse | `Branch Lahore - MEPL` | under `All Warehouses - MEPL` |
| Customer | `Walk-in Customer` | Individual, territory Pakistan |

### 2.2 POS Profile `Branch Lahore`
| Field | Value |
|---|---|
| Company | MicroMax Erp Pvt Ltd. |
| Warehouse | Branch Lahore - MEPL |
| Customer | Walk-in Customer |
| Currency | PKR |
| Write Off Account / Cost Center | Write Off - MEPL / Main - MEPL |
| Write Off Limit | 5 |
| Payment Methods | Cash (default), Bank |
| Applicable Users | Administrator (default) |
| Item Groups | POS Products *(pre-existing; expands to its child groups — see §3)* |
| Allow Offline Sale Without Stock Verification | ✅ Enabled |
| Create POS Invoice instead of Sales Invoice | ✅ Enabled |

**Skipped:** Credit Card as a payment method — its Mode of Payment has no GL
account linked for MEPL (only real bank accounts exist). Adding it as-is
would let a cashier pick it but fail on submit. Needs a clearing account
created first if wanted.

### 2.2.1 Checkout fixes
Two mandatory-field/routing issues hit on first checkout, both fixed at the
data level (no code changes):

- **"Cost Center is required"** — `Sales Invoice Item`/`POS Invoice Item`
  make `cost_center` mandatory, and neither the POS Profile nor the new items
  had one set. Fixed by setting `POS Profile.cost_center` = `Main - MEPL`
  and each new item's `Item Default.selling_cost_center` = `Main - MEPL`
  (belt-and-braces — POS Awesome/ERPNext can source it from either).
- **"Page pos-invoice not found"** — the POS Awesome frontend branches
  every doctype decision (which doctype to create, which route/print view
  to open, etc.) on `POS Profile.create_pos_invoice_instead_of_sales_invoice`.
  It was off, so the backend was creating `Sales Invoice` while something in
  the flow pointed at the `POS Invoice` page. Enabled the flag so the
  profile consistently uses **POS Invoice** end-to-end.
  Note: only `Accounts Manager`/`Accounts User` (plus Administrator, who
  bypasses permissions) can create/submit `POS Invoice` — a non-privileged
  cashier user added later will need one of those roles.
- **"Page pos-invoice not found" persisted even after the flag above** —
  the real cause: **Custom DocPerm** rows existed on `POS Invoice` that
  zeroed out `read`/`write`/`create` for both `Accounts Manager` and
  `Accounts User` (permlevel 0 and 1), overriding the doctype's normal
  shipped permissions. Because of that override, `POS Invoice` never made
  it into the desk's per-session readable-doctype list
  (`boot.user.can_read`), which is what the desk's client-side router uses
  to know a slug maps to a doctype list view — so `/desk/pos-invoice`
  fell through to a "page not found" state instead of opening the list.
  Not something posawesome or micromax fixtures ship; it looks like a
  manual permission change made directly on this site at some point.
  Deleted the 3 stray `Custom DocPerm` records and cleared cache —
  confirmed `POS Invoice` now appears in the computed `can_read` list.
- **Item Default warehouse was wrong** — ERPNext's own Stock Reconciliation
  submit auto-fills a blank Item Default warehouse with a generic company
  default; all 15 items had silently gotten `Stores - MEPL` instead of
  `Branch Lahore - MEPL`. Fixed via `src/util/generate_pos_items.sh`
  (§3 below), which now force-corrects the warehouse on every run.
- **"Unable to verify cashier PIN" on terminal unlock** — Administrator
  had no `posa_pos_pin` set (the per-user Password field POS Awesome checks
  on unlock). Set a PIN (`1234`) on the Administrator user via the same
  path `save_cashier_pin` uses. Change it from the POS terminal's cashier
  PIN screen once real cashier accounts exist — don't leave it at the
  placeholder value.

### 2.3 POS Awesome Supervisor role
Already shipped by the app (`Role: POS Awesome Supervisor`) — nothing to
create. Administrator implicitly holds it (Administrator has every role by
default). Assign it explicitly to any *non*-Administrator cashier from
**User → Roles** if/when one is added.

### 2.4 Notifications
No configurable notification setting exists on POS Profile or the Supervisor
role in this app version. The only notification feature is POS Awesome's
built-in **update checker** (every 24h, or Menu → Check for Updates) — global,
automatic, needs no setup.

---

## 3. POS item catalog — Foods / Beverages / Add-on

Item Groups (already existed under `POS Products`, created via the desk
before this pass): `Foods Items`, `Beverages`, `add-on`.

5 items were added to each group, all under company MEPL:

| Group | Items (item_code) | Price (PKR) |
|---|---|---|
| Foods Items | FOOD-001 Grilled Chicken Sandwich · FOOD-002 Beef Burger · FOOD-003 Margherita Pizza Slice · FOOD-004 Chicken Biryani · FOOD-005 Club Sandwich | 450 / 500 / 350 / 400 / 420 |
| Beverages | BEV-001 Fresh Orange Juice · BEV-002 Cappuccino · BEV-003 Iced Latte · BEV-004 Mineral Water · BEV-005 Mint Lemonade | 200 / 250 / 280 / 80 / 180 |
| add-on | ADDON-001 French Fries · ADDON-002 Garlic Bread · ADDON-003 Coleslaw · ADDON-004 Onion Rings · ADDON-005 Extra Cheese | 200 / 220 / 150 / 220 / 100 |

For every item:
- **Image**: a generated SVG icon (colored ring + tinted disc + category emoji —
  same visual language as the site's process-diagram icons), attached as a
  private-off File and set on `Item.image`. No external image URLs used.
- **Item Price**: Standard Selling, PKR, at the rate above.
- **Opening stock**: 50 units at `Branch Lahore - MEPL`, posted via Stock
  Reconciliation `MAT-RECO-2026-00001` (valuation ≈ 45% of selling rate,
  difference account `Stock In Hand - MEPL` since it's an Opening Stock
  entry and must hit an Asset account, not the P&L `Stock Adjustment`
  account).

`Branch Lahore`'s POS Products item-group filter already covers these three
groups (POS Awesome expands a parent Item Group to all its descendants), so
no POS Profile change was needed for the new items to show up.

**Script**: [`src/util/generate_pos_items.sh`](src/util/generate_pos_items.sh)
creates/repairs this whole catalog. Idempotent — safe to re-run after a fresh
`bench --site <site> migrate` / `install-app` on another environment.
Usage: `./src/util/generate_pos_items.sh [site] [warehouse] [company]`
(defaults: `micromaxerp`, `Branch Lahore - MEPL`, `MicroMax Erp Pvt Ltd.`).

---

## Still open / not done
- No dedicated cashier user created yet — POS only lists Administrator as an
  applicable user.
- Credit Card payment method needs a clearing account before it can be added
  to the profile.
