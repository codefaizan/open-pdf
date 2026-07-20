"""Generate the representative ruled-table PDF used by ticket 1."""

from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas


CORPUS_DIR = Path(__file__).resolve().parent
PDF_PATH = CORPUS_DIR / "ruled_table.pdf"

HEADERS = ["Item ID", "Product Code", "Quantity", "Unit Price", "Notes"]
ROWS = [
    ["00123", "ABC-00456", "10", "29.99", "Rush order"],
    ["00456", "XYZ-00789", "5", "15.50", "Standard"],
    ["00789", "DEF-00123", "25", "8.00", "Bulk"],
]


def draw_ruled_table(pdf_path: Path) -> None:
    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    page_width, page_height = letter
    c = canvas.Canvas(str(pdf_path), pagesize=letter)

    title_y = page_height - inch
    c.setFont("Helvetica-Bold", 14)
    c.drawString(inch, title_y, "Inventory Summary")

    table_top = title_y - 0.4 * inch
    table_left = inch
    column_widths = [1.0 * inch, 1.4 * inch, 0.9 * inch, 1.0 * inch, 1.5 * inch]
    row_height = 0.35 * inch
    table_width = sum(column_widths)
    table_height = row_height * (len(ROWS) + 1)

    c.setStrokeColor(colors.black)
    c.setLineWidth(1)

    y = table_top
    for row_index in range(len(ROWS) + 1):
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
    for column_index, header in enumerate(HEADERS):
        c.drawString(x + 0.08 * inch, y, header)
        x += column_widths[column_index]

    c.setFont("Helvetica", 10)
    for row_index, row in enumerate(ROWS):
        x = table_left
        y = table_top - (row_index + 2) * row_height + 0.1 * inch
        for column_index, value in enumerate(row):
            c.drawString(x + 0.08 * inch, y, value)
            x += column_widths[column_index]

    c.showPage()
    c.save()


def main() -> None:
    draw_ruled_table(PDF_PATH)
    print(f"Wrote {PDF_PATH}")


if __name__ == "__main__":
    main()
