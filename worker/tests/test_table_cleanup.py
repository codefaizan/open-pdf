from __future__ import annotations

from open_pdf_worker.converter import (
    _expand_stacked_cells,
    _fill_orphan_labels,
    _is_noise_table,
    _label_amount_pairs,
    _supplemental_kv_rows,
)


def test_expand_stacked_cells_splits_label_amount() -> None:
    rows = [
        ["", "Previous Balance\n$454.42"],
        ["Minimum Payment Due", "$35.00", "Fees\n+$0.00"],
        ["$35.00\nMinimum Payment Due", ""],
    ]
    expanded = _expand_stacked_cells(rows)
    assert expanded[0][:2] == ["", "Previous Balance"]
    assert "$454.42" in expanded[0]
    assert expanded[1][0] == "Minimum Payment Due"
    assert expanded[1][1] == "$35.00"
    assert "Fees" in expanded[1]
    assert "+$0.00" in expanded[1]
    assert expanded[2][0] == "Minimum Payment Due"
    assert expanded[2][1] == "$35.00"


def test_noise_table_detects_prose_and_keeps_transactions() -> None:
    prose = [
        ["Payments: Your payment must be sent to the payment address shown on"],
        ["your statement and must be received by 5 p.m. local time at that address to"],
        ["be credited as of the day it is received. Payments we receive after 5 p.m. will"],
        ["not be credited to your Account until the next day. Payments must also: (1)"],
    ]
    notices = [
        ["MARSHALL N MCGOWAN", "Closing Date 06/19/26", "Account Ending 6-21000"],
        ["IMPORTANT NOTICES"],
        ["In Case of Errors or Questions About Your Electronic Transfers Telephone us at"],
        ["questions. You may also write us at American Express, Electronic Funds Services,"],
        ["statement or receipt is wrong or if you need more information about a transfer"],
    ]
    charges = [
        ["05/22/26", "Audible", "audible.com", "NJ", "$7.95"],
        ["05/26/26", "AMAZON MARKETPLACE", "AMZN.COM/BILL", "WA", "$252.61"],
    ]
    assert _is_noise_table(prose)
    assert _is_noise_table(notices)
    assert not _is_noise_table(charges)


def test_fill_orphan_labels_uses_page_pairs() -> None:
    summary = [["Minimum Payment Due", "$35.00"]]
    coupon = [["", "", "Minimum Payment Due"]]
    pairs = _label_amount_pairs(summary)
    filled = _fill_orphan_labels(coupon, pairs)
    assert filled[0][2] == "Minimum Payment Due"
    assert filled[0][3] == "$35.00"


def test_supplemental_keeps_missing_fee_rows_not_dated_charges() -> None:
    primary_keys = {"05/31/26", "amazon marketplace na pa", "$214.95"}
    rows = [
        ["05/31/26", "AMAZON MARKETPLACE NA PA", "$214.95"],
        ["Total Fees for this Period", "$0.00"],
        ["Total Fees in 2026", "$0.00"],
        ["Total New Charges", "$589.33", "$0.00", "$589.33"],
    ]
    extras = _supplemental_kv_rows(primary_keys, rows)
    joined = {" | ".join(row) for row in extras}
    assert "Total Fees for this Period | $0.00" in joined
    assert "Total Fees in 2026 | $0.00" in joined
    assert "Total New Charges | $589.33 | $0.00 | $589.33" in joined
    assert not any("05/31/26" in " | ".join(row) for row in extras)
