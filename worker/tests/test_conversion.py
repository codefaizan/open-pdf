from __future__ import annotations

from pathlib import Path

from tests.conftest import (
    compare_expected_workbook,
    handshake,
    read_workbook_cell_formats,
    read_workbook_cells,
)


def test_ruled_table_conversion_produces_expected_workbook(
    worker,
    tmp_path: Path,
    sample_pdf: Path,
    expected_spec: dict,
) -> None:
    handshake(worker)
    output = tmp_path / "ruled_table.xlsx"
    worker.send(
        {
            "type": "convert",
            "request_id": "ruled-table",
            "input_pdf": str(sample_pdf),
            "output_xlsx": str(output),
            "pages": "1",
        }
    )

    progress_events = []
    while True:
        event = worker.read_event()
        if event["type"] == "progress":
            progress_events.append(event)
        if event["type"] == "complete":
            break
        if event["type"] == "error":
            raise AssertionError(event)

    assert output.exists()
    assert event["output_xlsx"] == str(output)
    assert len(event["worksheets"]) >= expected_spec["minimum_worksheets"]
    assert progress_events
    assert progress_events[0]["percent"] < progress_events[-1]["percent"]

    metrics = compare_expected_workbook(output, expected_spec)
    assert metrics["cell_recall"] == 1.0
    assert metrics["matched_rows"] == metrics["expected_rows"]
    assert metrics["headers_found"] == metrics["headers_expected"]
    assert metrics["source_metadata_found"]
    assert not metrics["values_missing"]


def test_leading_zeroes_preserved_as_text(
    worker,
    tmp_path: Path,
    sample_pdf: Path,
) -> None:
    handshake(worker)
    output = tmp_path / "leading_zeroes.xlsx"
    worker.send(
        {
            "type": "convert",
            "request_id": "leading-zeroes",
            "input_pdf": str(sample_pdf),
            "output_xlsx": str(output),
        }
    )

    while True:
        event = worker.read_event()
        if event["type"] == "complete":
            break
        if event["type"] == "error":
            raise AssertionError(event)

    cells = read_workbook_cells(output)
    flat = {value for row in cells for value in row}

    assert "00123" in flat
    assert "00456" in flat
    assert "00789" in flat
    assert "123" not in flat
    assert "456" not in flat
    assert "789" not in flat

    for item_id in ("00123", "00456", "00789"):
        for row in cells:
            if item_id in row:
                column_index = row.index(item_id)
                assert row[column_index] == item_id

    assert all(fmt == "@" for fmt in read_workbook_cell_formats(output))
