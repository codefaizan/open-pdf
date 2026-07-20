# Tickets: Open PDF MVP

These tickets build the local-first PDF reader and Excel converter defined in [SPEC.md](SPEC.md).

Work the **frontier**: any ticket whose blockers are all done.

## Ticket 1: Prove one PDF-to-Excel conversion

**What to build:** A reproducible converter-protocol workflow that accepts one representative digital PDF, produces an editable Excel workbook, validates its observable contents, and records baseline quality and performance.

**Blocked by:** None — can start immediately.

- [x] A versioned converter request can select an input PDF, output workbook, and page range without invoking a shell.
- [x] Progress and completion are emitted as newline-delimited JSON events.
- [x] One representative ruled-table PDF produces a valid workbook with expected cell values and structure.
- [x] The workflow preserves leading zeroes and other values that unsafe type inference could alter.
- [x] A repeatable check reports cell accuracy, runtime, and peak memory for the sample.
- [x] Invalid requests and unreadable inputs return structured failures without a partial workbook.

## Ticket 2: Open and read a PDF

**What to build:** A macOS and Windows Flutter application that opens a local PDF through the native file dialog and renders it inside a professional desktop shell.

**Blocked by:** None — can start immediately.

- [x] The application launches on supported macOS and Windows development environments.
- [x] The empty state presents one clear action for opening a PDF.
- [x] Selecting a valid PDF renders its first visible pages without loading every page eagerly.
- [x] The window uses native chrome and a stable reader layout with a toolbar, thumbnail area, and document canvas.
- [x] Closing one document and opening another works without restarting the application.
- [x] A damaged or unsupported PDF produces a clear, recoverable error.
- [x] The reader remains usable with paths containing spaces and non-English characters.

## Ticket 3: Navigate and search real documents

**What to build:** A complete reading workflow for large, linked, searchable, and password-protected PDFs using familiar desktop controls.

**Blocked by:** Ticket 2 — Open and read a PDF.

- [x] Users can navigate with thumbnails, previous/next controls, and direct page-number entry.
- [x] Users can zoom in or out and choose fit-width or fit-page behavior.
- [x] Standard keyboard shortcuts cover opening, searching, paging, and zooming.
- [x] Text search highlights matches and supports moving to the next or previous result.
- [x] Document links and outlines navigate to their destinations.
- [x] Password-protected PDFs can be opened after a successful password prompt and can recover from a rejected password.
- [x] Large documents scroll and navigate without rendering all pages simultaneously or making controls unresponsive.
- [x] Stable high-level layout tests cover the empty, reading, searching, password, and error states.

## Ticket 4: Convert the open PDF with one action

**What to build:** A complete happy-path workflow from the open document to an editable workbook using the bundled local converter, with no separate Python installation or network service.

**Blocked by:** Ticket 1 — Prove one PDF-to-Excel conversion; Ticket 2 — Open and read a PDF.

- [x] The reader presents one prominent Convert to Excel action only when a document is open.
- [x] Conversion defaults to all pages and allows an optional valid page range.
- [x] A native save dialog selects the destination and prevents accidental overwrite.
- [x] The application launches the worker directly, completes the version handshake, and never constructs a shell command.
- [x] The interface stays responsive and displays ordered conversion progress.
- [x] Successful completion identifies the saved workbook and offers a direct way to reveal or open it.
- [x] The produced workbook contains editable cells matching the representative source PDF.
- [x] The complete app-to-worker path is exercised by an end-to-end test using the distributable worker build.

## Ticket 5: Preserve complex digital tables safely

**What to build:** Reliable digital-PDF conversion across common business table layouts, with useful workbook structure and visible warnings when extraction is uncertain.

**Blocked by:** Ticket 4 — Convert the open PDF with one action.

- [ ] The benchmark corpus contains redistributable ruled, borderless, merged-cell, multi-table, multi-page, and rotated digital examples with verified expected workbooks.
- [ ] Clean digital pages use embedded text without unnecessary OCR.
- [ ] Multiple detected tables are separated into understandable, safely named worksheets.
- [ ] Confident merged-cell and row/column structure is retained in editable Excel cells.
- [ ] Long identifiers, leading zeroes, dates, and numeric-looking text are not destructively converted.
- [ ] Every extracted table records its source page or page range.
- [ ] Low-confidence results add an unobtrusive review worksheet; high-confidence results do not.
- [ ] Repeated conversion with the same application version produces deterministic workbook content.
- [ ] Accuracy results are reported separately for each digital document class.

## Ticket 6: Convert scanned PDFs offline

**What to build:** Local OCR-backed conversion for image-only, rotated, and noisy PDF pages using models included in the installed application.

**Blocked by:** Ticket 4 — Convert the open PDF with one action.

- [ ] The benchmark corpus contains verified clean-scan, noisy-scan, rotated, ruled, and borderless examples.
- [ ] Image-only pages are recognized automatically without requiring a separate user mode.
- [ ] Digital pages do not enter the slower OCR path when their embedded text is reliable.
- [ ] OCR models are available on first launch without a download or network connection.
- [ ] Extracted scan results produce editable worksheets with source-page metadata and confidence warnings.
- [ ] Rotated and noisy pages either meet the defined quality threshold or are explicitly flagged for review.
- [ ] Accuracy, runtime, and peak memory are reported separately for each scanned document class.
- [ ] Offline behavior is verified with network access disabled.

## Ticket 7: Cancel and recover failed conversions

**What to build:** A resilient conversion experience that users can stop and recover from without losing work or leaving misleading output.

**Blocked by:** Ticket 4 — Convert the open PDF with one action.

- [ ] Users can cancel an active conversion while the interface remains responsive.
- [ ] Cancellation stops the worker and leaves no workbook that could be mistaken for a complete result.
- [ ] Temporary conversion files and orphaned worker processes are cleaned up after completion, cancellation, timeout, or crash.
- [ ] Worker crashes, malformed events, protocol mismatches, and timeouts produce actionable errors.
- [ ] Invalid page ranges, unreadable PDFs, read-only destinations, and unsupported encryption are distinguished.
- [ ] Existing workbooks are never overwritten without explicit confirmation.
- [ ] A failed conversion does not require restarting the application before opening or converting another PDF.
- [ ] Local diagnostics include application and converter versions but exclude document contents.
- [ ] Filenames and protocol values cannot cause shell execution.

## Ticket 8: Pass the conversion release gate

**What to build:** Reproducible evidence that the bundled converter is safe, deterministic, and accurate enough for the claims made in the first release.

**Blocked by:** Ticket 5 — Preserve complex digital tables safely; Ticket 6 — Convert scanned PDFs offline; Ticket 7 — Cancel and recover failed conversions.

- [ ] The complete corpus runs through the same frozen worker shipped with the application.
- [ ] Reports show table detection, cell-text precision and recall, structural accuracy, runtime, and peak memory by document class.
- [ ] Agreed minimum thresholds pass for both digital and scanned documents, or unsupported classes are narrowed explicitly in product messaging.
- [ ] Malformed, encrypted, very large, and adversarially named inputs fail safely.
- [ ] Repeated and concurrent test runs leave no unbounded memory growth, temporary-file accumulation, or worker processes.
- [ ] Every production model, native library, and dependency is pinned and represented in the third-party notices.
- [ ] The report states that Adobe parity is unproven until representative Acrobat exports or customer documents pass comparable checks.
- [ ] No heavier fallback engine is added unless measured failures justify its package-size and maintenance cost.

## Ticket 9: Ship the macOS installer

**What to build:** A clean-machine-tested macOS package containing the complete offline reader and converter, ready for Developer ID signing and notarization.

**Blocked by:** Ticket 3 — Navigate and search real documents; Ticket 8 — Pass the conversion release gate.

- [ ] The package contains the Flutter application, compatible PDF engine, frozen worker, OCR models, and required license notices.
- [ ] Apple silicon and Intel are supported through verified architecture-specific or universal artifacts.
- [ ] The embedded helper resolves from the installed application and writes only to permitted user data or temporary locations.
- [ ] Nested executable signing, hardened runtime, entitlements, notarization, and stapling are automated without storing credentials in source control.
- [ ] A clean supported Mac can install, launch, open, navigate, search, convert, cancel, recover from a failure, and remove the application.
- [ ] Viewing and conversion pass with network access disabled.
- [ ] Paths containing spaces and non-English characters work from the installed application.
- [ ] Gatekeeper accepts a properly credentialed release artifact.

## Ticket 10: Ship the Windows installer

**What to build:** A clean-machine-tested Windows x64 MSIX containing the complete offline reader and converter, ready for trusted publisher signing.

**Blocked by:** Ticket 3 — Navigate and search real documents; Ticket 8 — Pass the conversion release gate.

- [ ] The MSIX contains the Flutter application, compatible PDF engine, frozen worker, OCR models, and required license notices.
- [ ] The embedded helper resolves from the read-only installation and writes only to permitted user data or temporary locations.
- [ ] Package creation and signing are automated on Windows without storing credentials in source control.
- [ ] A clean supported Windows x64 machine can install, launch, open, navigate, search, convert, cancel, recover from a failure, and uninstall the application.
- [ ] Viewing and conversion pass with network access disabled.
- [ ] Paths containing spaces and non-English characters work from the installed application.
- [ ] The installed product does not require Python, model downloads, a local server, or administrator-only runtime setup.
- [ ] Windows verifies a properly credentialed release artifact as coming from the expected publisher.
