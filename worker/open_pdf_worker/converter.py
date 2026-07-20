from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import camelot
from openpyxl import Workbook
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.worksheet import Worksheet

ProgressCallback = Callable[[str, int, str], None]


@dataclass(frozen=True)
class WorksheetInfo:
    name: str
    source_pages: list[int]


@dataclass(frozen=True)
class ConversionResult:
    output_xlsx: Path
    worksheets: list[WorksheetInfo]


def _safe_sheet_name(base: str, used: set[str]) -> str:
    cleaned = "".join(ch if ch.isalnum() or ch in (" ", "_", "-") else "_" for ch in base)
    cleaned = cleaned.strip() or "Sheet"
    cleaned = cleaned[:31]
    candidate = cleaned
    suffix = 2
    while candidate in used:
        tail = f"_{suffix}"
        candidate = f"{cleaned[: 31 - len(tail)]}{tail}"
        suffix += 1
    used.add(candidate)
    return candidate


def _write_text_cell(sheet: Worksheet, row: int, column: int, value: object) -> None:
    text = "" if value is None else str(value).strip()
    cell = sheet.cell(row=row, column=column, value=text)
    cell.number_format = "@"


def _write_table(sheet: Worksheet, rows: list[list[str]]) -> None:
    for row_index, row_values in enumerate(rows, start=1):
        for column_index, value in enumerate(row_values, start=1):
            _write_text_cell(sheet, row_index, column_index, value)


def _autosize_columns(sheet: Worksheet) -> None:
    for column_cells in sheet.columns:
        column_index = column_cells[0].column
        max_length = max((len(str(cell.value or "")) for cell in column_cells), default=0)
        sheet.column_dimensions[get_column_letter(column_index)].width = min(max(max_length + 2, 8), 40)


def convert_pdf_to_excel(
    input_pdf: Path,
    output_xlsx: Path,
    pages: str | None,
    on_progress: ProgressCallback,
) -> ConversionResult:
    on_progress("starting", 5, "Preparing conversion.")
    page_spec = pages or "all"

    on_progress("extracting", 20, f"Extracting tables from pages {page_spec}.")
    try:
        tables = camelot.read_pdf(
            str(input_pdf),
            pages=page_spec,
            flavor="lattice",
        )
    except Exception as exc:
        raise RuntimeError(f"Unable to read PDF tables: {exc}") from exc

    if len(tables) == 0:
        raise RuntimeError("No tables detected in the requested page range.")

    on_progress("writing", 70, f"Writing {len(tables)} worksheet(s).")
    workbook = Workbook()
    default_sheet = workbook.active
    workbook.remove(default_sheet)

    used_names: set[str] = set()
    worksheets: list[WorksheetInfo] = []

    for index, table in enumerate(tables, start=1):
        page_number = int(table.parsing_report.get("page", index))
        sheet_name = _safe_sheet_name(f"Table {index} p{page_number}", used_names)
        sheet = workbook.create_sheet(title=sheet_name)
        dataframe = table.df.fillna("")
        rows = [[str(value) for value in row] for row in dataframe.values.tolist()]
        header = [str(column) for column in dataframe.columns.tolist()]
        _write_table(sheet, [header, *rows])
        metadata_row = len(rows) + 3
        _write_text_cell(sheet, metadata_row, 1, "Source page(s)")
        _write_text_cell(sheet, metadata_row, 2, ", ".join(str(page) for page in [page_number]))
        _autosize_columns(sheet)
        worksheets.append(WorksheetInfo(name=sheet_name, source_pages=[page_number]))

    on_progress("finalizing", 90, "Saving workbook.")
    output_xlsx.parent.mkdir(parents=True, exist_ok=True)
    workbook.save(output_xlsx)

    on_progress("complete", 100, "Conversion finished.")
    return ConversionResult(output_xlsx=output_xlsx, worksheets=worksheets)
