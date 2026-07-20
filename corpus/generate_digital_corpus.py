"""Generate redistributable digital PDFs for the conversion benchmark corpus."""

from __future__ import annotations

from pathlib import Path

import pypdfium2 as pdfium
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

CORPUS_DIR = Path(__file__).resolve().parent


def _draw_ruled_table(
    c: canvas.Canvas,
    *,
    table_left: float,
    table_top: float,
    headers: list[str],
    rows: list[list[str]],
    column_widths: list[float],
    row_height: float = 0.35 * inch,
) -> None:
    table_width = sum(column_widths)
    table_height = row_height * (len(rows) + 1)

    c.setStrokeColor(colors.black)
    c.setLineWidth(1)

    y = table_top
    for _ in range(len(rows) + 1):
        c.line(table_left, y, table_left + table_width, y)
        y -= row_height

    x = table_left
    for width in column_widths:
        c.line(x, table_top, x, table_top - table_height)
        x += width
    c.line(x, table_top, x, table_top - table_height)

    c.setFont("Helvetica-Bold", 10)
    x = table_left
    y = table_top - row_height + 0.1 * inch
    for column_index, header in enumerate(headers):
        c.drawString(x + 0.08 * inch, y, header)
        x += column_widths[column_index]

    c.setFont("Helvetica", 10)
    for row_index, row in enumerate(rows):
        x = table_left
        y = table_top - (row_index + 2) * row_height + 0.1 * inch
        for column_index, value in enumerate(row):
            c.drawString(x + 0.08 * inch, y, value)
            x += column_widths[column_index]


def generate_ruled_table(pdf_path: Path) -> None:
    page_width, page_height = letter
    c = canvas.Canvas(str(pdf_path), pagesize=letter)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(inch, page_height - inch, "Inventory Summary")
    _draw_ruled_table(
        c,
        table_left=inch,
        table_top=page_height - inch - 0.4 * inch,
        headers=["Item ID", "Product Code", "Quantity", "Unit Price", "Notes"],
        rows=[
            ["00123", "ABC-00456", "10", "29.99", "Rush order"],
            ["00456", "XYZ-00789", "5", "15.50", "Standard"],
            ["00789", "DEF-00123", "25", "8.00", "Bulk"],
        ],
        column_widths=[1.0 * inch, 1.4 * inch, 0.9 * inch, 1.0 * inch, 1.5 * inch],
    )
    c.showPage()
    c.save()


def generate_borderless_table(pdf_path: Path) -> None:
    page_width, page_height = letter
    c = canvas.Canvas(str(pdf_path), pagesize=letter)
    headers = ["Account", "Posted", "Reference", "Amount"]
    rows = [
        ["100200300400500", "2024-01-15", "INV-2024-0042", "1250.00"],
        ["200300400500600", "2024-02-28", "INV-2024-0088", "890.50"],
        ["300400500600700", "2024-03-10", "INV-2024-0115", "432.10"],
    ]
    column_widths = [1.8 * inch, 1.1 * inch, 1.5 * inch, 1.0 * inch]
    table_left = inch
    table_top = page_height - inch
    row_height = 0.35 * inch

    c.setFont("Helvetica-Bold", 14)
    c.drawString(table_left, table_top, "Ledger Extract")

    c.setFont("Helvetica-Bold", 10)
    x = table_left
    y = table_top - 0.5 * inch
    for index, header in enumerate(headers):
        c.drawString(x, y, header)
        x += column_widths[index]

    c.setFont("Helvetica", 10)
    for row_index, row in enumerate(rows):
        x = table_left
        y = table_top - 0.85 * inch - row_index * row_height
        for column_index, value in enumerate(row):
            c.drawString(x, y, value)
            x += column_widths[column_index]

    c.showPage()
    c.save()


def generate_merged_cell_table(pdf_path: Path) -> None:
    page_width, page_height = letter
    c = canvas.Canvas(str(pdf_path), pagesize=letter)
    table_left = inch
    table_top = page_height - inch
    row_height = 0.35 * inch
    column_widths = [1.2 * inch, 1.2 * inch, 1.0 * inch, 1.0 * inch]
    table_width = sum(column_widths)

    c.setFont("Helvetica-Bold", 14)
    c.drawString(table_left, table_top, "Regional Sales")

    grid_top = table_top - 0.45 * inch
    grid_height = row_height * 4
    c.setStrokeColor(colors.black)
    c.setLineWidth(1)

    y = grid_top
    for _ in range(5):
        c.line(table_left, y, table_left + table_width, y)
        y -= row_height
    x = table_left
    for width in column_widths:
        c.line(x, grid_top, x, grid_top - grid_height)
        x += width
    c.line(x, grid_top, x, grid_top - grid_height)

    c.setFont("Helvetica-Bold", 10)
    c.drawCentredString(table_left + table_width / 2, grid_top - row_height + 0.1 * inch, "North Region")

    sub_headers = ["Store", "Manager", "Units", "Revenue"]
    x = table_left
    y = grid_top - 2 * row_height + 0.1 * inch
    for index, header in enumerate(sub_headers):
        c.drawString(x + 0.08 * inch, y, header)
        x += column_widths[index]

    rows = [
        ["Store A", "001-Jane", "120", "5400.00"],
        ["Store B", "002-Bob", "95", "4275.00"],
    ]
    c.setFont("Helvetica", 10)
    for row_index, row in enumerate(rows):
        x = table_left
        y = grid_top - (row_index + 3) * row_height + 0.1 * inch
        for column_index, value in enumerate(row):
            c.drawString(x + 0.08 * inch, y, value)
            x += column_widths[column_index]

    c.showPage()
    c.save()


def generate_multi_table(pdf_path: Path) -> None:
    page_width, page_height = letter
    c = canvas.Canvas(str(pdf_path), pagesize=letter)

    c.setFont("Helvetica-Bold", 14)
    c.drawString(inch, page_height - inch, "Daily Operations")

    _draw_ruled_table(
        c,
        table_left=inch,
        table_top=page_height - inch - 0.4 * inch,
        headers=["Shift", "Staff ID", "Hours"],
        rows=[
            ["Morning", "00045", "8.0"],
            ["Evening", "00078", "7.5"],
        ],
        column_widths=[1.2 * inch, 1.2 * inch, 0.9 * inch],
    )

    _draw_ruled_table(
        c,
        table_left=inch,
        table_top=page_height - inch - 2.4 * inch,
        headers=["Ticket", "Priority", "Status"],
        rows=[
            ["TKT-1001", "High", "Open"],
            ["TKT-1002", "Low", "Closed"],
        ],
        column_widths=[1.2 * inch, 1.0 * inch, 1.0 * inch],
    )

    c.showPage()
    c.save()


def generate_multi_page_table(pdf_path: Path) -> None:
    page_width, page_height = letter
    headers = ["Line", "SKU", "Qty", "Ship Date"]
    rows_page_1 = [
        ["1", "SKU-001", "12", "2024-06-01"],
        ["2", "SKU-002", "8", "2024-06-02"],
        ["3", "SKU-003", "15", "2024-06-03"],
    ]
    rows_page_2 = [
        ["4", "SKU-004", "6", "2024-06-04"],
        ["5", "SKU-005", "20", "2024-06-05"],
    ]
    column_widths = [0.7 * inch, 1.2 * inch, 0.8 * inch, 1.2 * inch]

    c = canvas.Canvas(str(pdf_path), pagesize=letter)
    for page_index, rows in enumerate((rows_page_1, rows_page_2)):
        c.setFont("Helvetica-Bold", 14)
        c.drawString(inch, page_height - inch, f"Shipment Register (Page {page_index + 1})")
        _draw_ruled_table(
            c,
            table_left=inch,
            table_top=page_height - inch - 0.4 * inch,
            headers=headers,
            rows=rows,
            column_widths=column_widths,
        )
        c.showPage()

    c.save()


def generate_rotated_table(pdf_path: Path) -> None:
    source_path = pdf_path.with_suffix(".source.pdf")
    c = canvas.Canvas(str(source_path), pagesize=letter)
    _draw_ruled_table(
        c,
        table_left=inch,
        table_top=letter[1] - inch - 0.4 * inch,
        headers=["Item ID", "Batch", "Count"],
        rows=[
            ["00987", "B-2024-01", "50"],
            ["00988", "B-2024-02", "35"],
        ],
        column_widths=[1.0 * inch, 1.4 * inch, 0.9 * inch],
    )
    c.showPage()
    c.save()

    document = pdfium.PdfDocument(str(source_path))
    page = document[0]
    page.set_rotation(90)
    document.save(str(pdf_path))
    source_path.unlink(missing_ok=True)


def generate_uncertain_table(pdf_path: Path) -> None:
    page_width, page_height = letter
    c = canvas.Canvas(str(pdf_path), pagesize=letter)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(inch, page_height - inch, "Warehouse Snapshot")

    c.setFont("Helvetica", 10)
    headers = ["Code", "ID", "Qty"]
    rows = [("Alpha", "001", "12"), ("Beta", "002", "8"), ("Gamma", "003", "15")]
    y = page_height - inch - 0.5 * inch
    for index, header in enumerate(headers):
        c.drawString(inch + index * 1.5 * inch, y, header)
    for row_index, (code, item_id, qty) in enumerate(rows):
        y = page_height - inch - 0.85 * inch - row_index * 0.35 * inch
        c.drawString(inch, y, code)
        c.drawString(1.5 * inch + (row_index % 2) * 0.25 * inch, y, item_id)
        c.drawString(4 * inch, y, qty)

    c.showPage()
    c.save()


GENERATORS = {
    "ruled_table.pdf": generate_ruled_table,
    "borderless_table.pdf": generate_borderless_table,
    "merged_cell_table.pdf": generate_merged_cell_table,
    "multi_table.pdf": generate_multi_table,
    "multi_page_table.pdf": generate_multi_page_table,
    "rotated_table.pdf": generate_rotated_table,
    "uncertain_table.pdf": generate_uncertain_table,
}


def main() -> None:
    CORPUS_DIR.mkdir(parents=True, exist_ok=True)
    for filename, generator in GENERATORS.items():
        path = CORPUS_DIR / filename
        generator(path)
        print(f"Wrote {path}")


if __name__ == "__main__":
    main()
