"""Conversion release-gate thresholds, evaluation, and frozen-worker resolution."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

from open_pdf_worker.harness import (
    WORKER_ROOT,
    benchmark_digital_corpus,
    benchmark_scan_corpus,
)

ADOBE_PARITY_DISCLAIMER = (
    "Adobe parity is unproven until representative Acrobat exports or customer "
    "documents pass comparable checks. Synthetic corpus results alone do not "
    "justify an Adobe Acrobat conversion-parity claim."
)

# Agreed minima for the first release. Per-class overrides narrow expectations
# only where the corpus already documents weaker quality (e.g. rotated_scan).
DEFAULT_THRESHOLDS: dict[str, Any] = {
    "digital": {
        "default": {
            "cell_recall": 1.0,
            # multi_page workbooks include repeated headers across pages
            "cell_precision": 0.3,
            "table_detection": 1.0,
            "structural_accuracy": 1.0,
            "max_runtime_seconds": 120.0,
            "max_peak_memory_bytes": 2_000_000_000,
        }
    },
    "scan": {
        "default": {
            "cell_recall": 1.0,
            "cell_precision": 0.35,
            "table_detection": 1.0,
            # OCR row matching can miss a header-adjacent row while recall stays perfect
            "structural_accuracy": 0.9,
            "max_runtime_seconds": 180.0,
            "max_peak_memory_bytes": 2_000_000_000,
            "require_ocr": True,
        },
        "rotated_scan": {
            "cell_recall": 0.5,
            "cell_precision": 0.2,
            "table_detection": 1.0,
            "structural_accuracy": 0.5,
            "max_runtime_seconds": 180.0,
            "max_peak_memory_bytes": 2_000_000_000,
            "require_ocr": True,
        },
    },
}


def frozen_worker_executable() -> Path:
    name = "open_pdf_worker.exe" if sys.platform.startswith("win") else "open_pdf_worker"
    return WORKER_ROOT / "dist" / "open_pdf_worker" / name


def frozen_worker_command() -> list[str]:
    return [str(frozen_worker_executable())]


def require_frozen_worker() -> list[str]:
    path = frozen_worker_executable()
    if not path.is_file():
        raise FileNotFoundError(
            f"Frozen worker not found at {path}. Run scripts/freeze_worker.sh first."
        )
    return [str(path)]


def thresholds_for(family: str, class_id: str, thresholds: dict[str, Any]) -> dict[str, Any]:
    family_thresholds = thresholds[family]
    defaults = dict(family_thresholds["default"])
    overrides = family_thresholds.get(class_id) or {}
    defaults.update(overrides)
    return defaults


def evaluate_release_gate(report: dict[str, Any], thresholds: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []

    worker = report.get("worker") or {}
    if worker.get("kind") != "frozen":
        failures.append("Release gate requires the frozen worker shipped with the application.")

    if report.get("heavier_fallback_engine"):
        failures.append(
            "Heavier fallback engines are not permitted without measured failures "
            "that justify package-size and maintenance cost."
        )

    for family in ("digital", "scan"):
        by_class = (report.get(family) or {}).get("by_class") or {}
        for class_id, metrics in by_class.items():
            limits = thresholds_for(family, class_id, thresholds)
            label = f"{family}/{class_id}"

            if not metrics.get("completed"):
                failures.append(f"{label}: conversion did not complete")
                continue

            for metric in (
                "cell_recall",
                "cell_precision",
                "table_detection",
                "structural_accuracy",
            ):
                actual = float(metrics.get(metric, 0.0))
                minimum = float(limits[metric])
                if actual < minimum:
                    failures.append(
                        f"{label}: {metric} {actual:.4f} < minimum {minimum:.4f}"
                    )

            runtime = float(metrics.get("runtime_seconds", 0.0))
            if runtime > float(limits["max_runtime_seconds"]):
                failures.append(
                    f"{label}: runtime_seconds {runtime:.3f} > "
                    f"max {limits['max_runtime_seconds']}"
                )

            peak = int(metrics.get("peak_memory_bytes", 0))
            if peak > int(limits["max_peak_memory_bytes"]):
                failures.append(
                    f"{label}: peak_memory_bytes {peak} > "
                    f"max {limits['max_peak_memory_bytes']}"
                )

            if limits.get("require_ocr"):
                methods = metrics.get("extraction_methods") or []
                if not methods or not all(str(method).startswith("ocr") for method in methods):
                    failures.append(f"{label}: expected OCR extraction methods, got {methods!r}")

    return {
        "passed": not failures,
        "failures": failures,
        "adobe_parity_disclaimer": ADOBE_PARITY_DISCLAIMER,
        "conversion_engine": report.get("conversion_engine", "camelot+ocr"),
        "heavier_fallback_engine": bool(report.get("heavier_fallback_engine", False)),
        "thresholds": thresholds,
    }


def build_release_report(
    output_dir: Path,
    *,
    worker_command: list[str] | None = None,
) -> dict[str, Any]:
    """Run the full corpus through the frozen worker and assemble the gate report."""
    command = worker_command or require_frozen_worker()
    digital_dir = output_dir / "digital"
    scan_dir = output_dir / "scan"
    digital_dir.mkdir(parents=True, exist_ok=True)
    scan_dir.mkdir(parents=True, exist_ok=True)

    digital = benchmark_digital_corpus(digital_dir, worker_command=command)
    scan = benchmark_scan_corpus(scan_dir, worker_command=command)

    return {
        "digital": digital,
        "scan": scan,
        "worker": {"kind": "frozen", "command": command},
        "conversion_engine": "camelot+ocr",
        "heavier_fallback_engine": False,
        "adobe_parity_disclaimer": ADOBE_PARITY_DISCLAIMER,
    }


def run_release_gate(
    output_dir: Path,
    *,
    thresholds: dict[str, Any] | None = None,
    worker_command: list[str] | None = None,
) -> dict[str, Any]:
    report = build_release_report(output_dir, worker_command=worker_command)
    evaluation = evaluate_release_gate(report, thresholds or DEFAULT_THRESHOLDS)
    report["gate"] = evaluation
    return report
