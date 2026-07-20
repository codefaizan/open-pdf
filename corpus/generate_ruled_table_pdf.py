"""Generate the representative ruled-table PDF used by ticket 1."""

from __future__ import annotations

from generate_digital_corpus import CORPUS_DIR, generate_ruled_table

PDF_PATH = CORPUS_DIR / "ruled_table.pdf"


def main() -> None:
    generate_ruled_table(PDF_PATH)
    print(f"Wrote {PDF_PATH}")


if __name__ == "__main__":
    main()
