from __future__ import annotations

import json
import sys
import tempfile
import threading
from pathlib import Path

from open_pdf_worker.converter import convert_pdf_to_excel
from open_pdf_worker.errors import ConversionCancelledError
from open_pdf_worker.protocol import (
    ProtocolError,
    emit,
    error_event,
    log_diagnostic,
    parse_convert_request,
    parse_message,
    validate_handshake,
)
from open_pdf_worker.version import PROTOCOL_VERSION, WORKER_VERSION


class WorkerSession:
    def __init__(self) -> None:
        self._cancel_event = threading.Event()
        self._active_request_id: str | None = None
        self._convert_thread: threading.Thread | None = None

    def run(self) -> int:
        handshake_complete = False
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                payload = parse_message(line)
            except ProtocolError as exc:
                emit(error_event(None, exc.code, exc.message))
                return 1

            message_type = payload["type"]
            if message_type == "handshake":
                try:
                    validate_handshake(payload, PROTOCOL_VERSION)
                except ProtocolError as exc:
                    emit(error_event(None, exc.code, exc.message))
                    return 1
                emit(
                    {
                        "type": "handshake_ack",
                        "protocol_version": PROTOCOL_VERSION,
                        "worker_version": WORKER_VERSION,
                    }
                )
                handshake_complete = True
                continue

            if not handshake_complete:
                emit(error_event(None, "PROTOCOL_MISMATCH", "Handshake required before other messages."))
                return 1

            if message_type == "convert":
                exit_code = self._start_convert(payload)
                if exit_code is not None:
                    return exit_code
                continue

            if message_type == "cancel":
                request_id = payload.get("request_id")
                if request_id == self._active_request_id:
                    self._cancel_event.set()
                continue

            request_id = payload.get("request_id") if isinstance(payload.get("request_id"), str) else None
            emit(error_event(request_id, "INVALID_REQUEST", f"Unknown message type: {message_type!r}."))
            return 1

        if self._convert_thread is not None:
            self._convert_thread.join()
        return 0

    def _start_convert(self, payload: dict) -> int | None:
        if self._convert_thread is not None and self._convert_thread.is_alive():
            request_id = payload.get("request_id") if isinstance(payload.get("request_id"), str) else None
            emit(error_event(request_id, "INVALID_REQUEST", "A conversion is already in progress."))
            return 1

        request_id = payload.get("request_id") if isinstance(payload.get("request_id"), str) else None
        try:
            request = parse_convert_request(payload)
        except ProtocolError as exc:
            emit(error_event(request_id, exc.code, exc.message))
            return 1

        self._active_request_id = request.request_id
        self._cancel_event.clear()
        self._convert_thread = threading.Thread(
            target=self._run_convert,
            args=(request,),
            daemon=True,
        )
        self._convert_thread.start()
        return None

    def _run_convert(self, request) -> None:
        temp_path: Path | None = None
        try:
            if request.output_xlsx.exists():
                emit(
                    error_event(
                        request.request_id,
                        "INVALID_REQUEST",
                        f"Output workbook already exists: {request.output_xlsx}",
                    )
                )
                return

            with tempfile.NamedTemporaryFile(
                suffix=".xlsx",
                delete=False,
                dir=request.output_xlsx.parent,
            ) as temp_file:
                temp_path = Path(temp_file.name)

            def on_progress(stage: str, percent: int, message: str) -> None:
                if self._cancel_event.is_set():
                    raise ConversionCancelledError()
                emit(
                    {
                        "type": "progress",
                        "request_id": request.request_id,
                        "stage": stage,
                        "percent": percent,
                        "message": message,
                    }
                )

            result = convert_pdf_to_excel(
                request.input_pdf,
                temp_path,
                request.pages,
                on_progress,
            )
            if self._cancel_event.is_set():
                raise ConversionCancelledError()

            temp_path.replace(request.output_xlsx)
            temp_path = None

            emit(
                {
                    "type": "complete",
                    "request_id": request.request_id,
                    "output_xlsx": str(request.output_xlsx),
                    "worksheets": [
                        {
                            "name": sheet.name,
                            "source_pages": sheet.source_pages,
                            "extraction_method": sheet.extraction_method,
                        }
                        for sheet in result.worksheets
                    ],
                }
            )
        except ConversionCancelledError:
            emit(error_event(request.request_id, "CANCELLED", "Conversion cancelled."))
        except RuntimeError as exc:
            emit(error_event(request.request_id, "CONVERSION_FAILED", str(exc)))
        except Exception as exc:
            log_diagnostic(f"Conversion failed: {exc}")
            emit(error_event(request.request_id, "CONVERSION_FAILED", str(exc)))
        finally:
            self._active_request_id = None
            if temp_path is not None and temp_path.exists():
                temp_path.unlink(missing_ok=True)


def main() -> None:
    raise SystemExit(WorkerSession().run())


if __name__ == "__main__":
    main()
