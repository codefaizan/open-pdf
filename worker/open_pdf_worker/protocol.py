from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PAGE_RANGE_RE = re.compile(r"^\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*$")


@dataclass(frozen=True)
class ConvertRequest:
    request_id: str
    input_pdf: Path
    output_xlsx: Path
    pages: str | None


class ProtocolError(ValueError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def emit(event: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(event, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def log_diagnostic(message: str) -> None:
    sys.stderr.write(message.rstrip() + "\n")
    sys.stderr.flush()


def parse_message(line: str) -> dict[str, Any]:
    try:
        payload = json.loads(line)
    except json.JSONDecodeError as exc:
        raise ProtocolError("INVALID_REQUEST", f"Invalid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise ProtocolError("INVALID_REQUEST", "Message must be a JSON object.")
    message_type = payload.get("type")
    if not isinstance(message_type, str) or not message_type:
        raise ProtocolError("INVALID_REQUEST", "Missing message type.")
    return payload


def validate_handshake(payload: dict[str, Any], supported_protocol: str) -> None:
    protocol_version = payload.get("protocol_version")
    if protocol_version != supported_protocol:
        raise ProtocolError(
            "PROTOCOL_MISMATCH",
            f"Unsupported protocol version: {protocol_version!r}.",
        )


def parse_convert_request(payload: dict[str, Any]) -> ConvertRequest:
    request_id = payload.get("request_id")
    input_pdf = payload.get("input_pdf")
    output_xlsx = payload.get("output_xlsx")
    pages = payload.get("pages")

    if not isinstance(request_id, str) or not request_id:
        raise ProtocolError("INVALID_REQUEST", "request_id must be a non-empty string.")
    if not isinstance(input_pdf, str) or not input_pdf:
        raise ProtocolError("INVALID_REQUEST", "input_pdf must be a non-empty string.")
    if not isinstance(output_xlsx, str) or not output_xlsx:
        raise ProtocolError("INVALID_REQUEST", "output_xlsx must be a non-empty string.")
    if pages is not None and not isinstance(pages, str):
        raise ProtocolError("INVALID_REQUEST", "pages must be a string or null.")
    if pages is not None and not PAGE_RANGE_RE.fullmatch(pages.strip()):
        raise ProtocolError("INVALID_REQUEST", f"Invalid page range: {pages!r}.")

    pdf_path = Path(input_pdf)
    xlsx_path = Path(output_xlsx)
    if not pdf_path.is_file():
        raise ProtocolError("PDF_UNREADABLE", f"Input PDF not found: {input_pdf}")
    if pdf_path.suffix.lower() != ".pdf":
        raise ProtocolError("PDF_UNREADABLE", "Input file must have a .pdf extension.")
    parent = xlsx_path.parent
    if not parent.exists():
        raise ProtocolError("INVALID_REQUEST", f"Output directory does not exist: {parent}")
    if not parent.is_dir():
        raise ProtocolError("INVALID_REQUEST", f"Output parent is not a directory: {parent}")

    return ConvertRequest(
        request_id=request_id,
        input_pdf=pdf_path.resolve(),
        output_xlsx=xlsx_path.resolve(),
        pages=pages.strip() if isinstance(pages, str) else None,
    )


def error_event(request_id: str | None, code: str, message: str) -> dict[str, Any]:
    event: dict[str, Any] = {"type": "error", "code": code, "message": message}
    if request_id is not None:
        event["request_id"] = request_id
    return event
