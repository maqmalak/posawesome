import frappe
from frappe.utils import flt


def get_base_value(doc, fieldname, base_fieldname=None, conversion_rate=None):
    """Return the value for a field in company currency."""

    base_fieldname = base_fieldname or f"base_{fieldname}"
    base_value = doc.get(base_fieldname)

    if base_value not in (None, ""):
        return flt(base_value)

    value = doc.get(fieldname)
    if value in (None, ""):
        return 0

    if conversion_rate is None:
        conversion_rate = (
            doc.get("conversion_rate")
            or doc.get("source_exchange_rate")
            or doc.get("target_exchange_rate")
            or doc.get("exchange_rate")
            or 1
        )

    return flt(value) * flt(conversion_rate or 1)


def resolve_payment_currency(payment_row, invoice_currency, company_currency=None):
    """Return the currency a payment row was tendered in, falling back to the
    invoice's currency (and then the company currency) when the row doesn't
    carry its own."""

    for fieldname in (
        "posa_payment_currency",
        "currency",
        "account_currency",
        "payment_currency",
    ):
        value = payment_row.get(fieldname)
        if value:
            return value
    return invoice_currency or company_currency
