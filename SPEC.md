## Problem Statement

People need a fast, professional desktop application for reading PDFs and converting PDF content into editable Excel workbooks without depending on Adobe Acrobat or uploading private documents to a cloud service. Existing alternatives often have inconsistent interfaces, weak conversion quality, or require separate runtimes and tools.

The application must run well on macOS during development and be distributable to Windows users as one installer. Its conversion workflow should be simple enough for non-technical users while preserving table data and structure closely enough that switching from Adobe Acrobat does not feel like a downgrade.

## Solution

Open PDF will be a local-first Flutter desktop application for macOS and Windows. Its first release will provide a polished PDF viewer and a single, obvious Convert to Excel workflow.

PDF viewing will use PDFium through a Flutter-native integration. Excel conversion will run in a bundled Python worker selected for conversion quality, with no separate Python installation, local server, account, or network connection. The worker will detect digital and scanned pages, choose an appropriate table-extraction path, create editable worksheets, and identify uncertain results rather than silently presenting them as accurate.

Each platform will receive one installable package containing the Flutter application, PDF engine, conversion worker, models, and required notices. Conversion quality will be measured against a reproducible corpus before release. Adobe-level parity will remain a release claim to prove with representative Acrobat exports or customer documents, not an assumption.

## User Stories

1. As a desktop user, I want to install Open PDF from one package, so that I do not have to install Python or supporting tools.
2. As a Windows user, I want Open PDF to behave like a normal Windows application, so that it feels familiar and trustworthy.
3. As a macOS user, I want Open PDF to behave like a normal macOS application, so that development and daily use are predictable.
4. As a privacy-conscious user, I want my documents processed entirely on my computer, so that sensitive information is not uploaded.
5. As an offline user, I want viewing and conversion to work without internet access, so that connectivity does not block my work.
6. As a user, I want to open a PDF from a native file dialog, so that selecting a document is familiar.
7. As a user, I want to open password-protected PDFs after entering the password, so that protected documents remain usable.
8. As a user, I want large PDFs to open without rendering every page at once, so that the application stays responsive.
9. As a reader, I want page thumbnails, so that I can move through a document visually.
10. As a reader, I want to enter a page number, so that I can jump directly to a known page.
11. As a reader, I want next-page and previous-page controls, so that sequential navigation is easy.
12. As a reader, I want predictable zoom controls, so that I can comfortably inspect small content.
13. As a reader, I want fit-width and fit-page options, so that common viewing layouts require one action.
14. As a keyboard user, I want standard shortcuts for opening, searching, paging, and zooming, so that the application is efficient.
15. As a reader, I want to search selectable PDF text, so that I can find information quickly.
16. As a reader, I want search results highlighted and navigable, so that I can understand each match in context.
17. As a reader, I want document links and outlines to work, so that built-in PDF navigation is preserved.
18. As a user, I want clear messages for damaged or unsupported PDFs, so that failures are understandable.
19. As a user, I want the application to recover from a failed document without restarting, so that one bad file does not interrupt other work.
20. As a user, I want one prominent Convert to Excel action, so that I do not have to understand conversion technology.
21. As a user, I want to convert the complete PDF by default, so that the common workflow requires minimal configuration.
22. As a user, I want to choose a page range, so that I can avoid converting irrelevant pages.
23. As a user, I want to choose the output location with a native save dialog, so that I know where the workbook will be created.
24. As a user, I want conversion progress, so that I know the application is still working.
25. As a user, I want to cancel a conversion, so that I can stop an accidental or slow operation.
26. As a user, I want cancellation to leave no misleading partial workbook, so that I do not mistake incomplete output for a result.
27. As a user, I want successful conversion to identify the saved file, so that I can open it immediately.
28. As a user, I want digital PDFs converted without OCR when embedded text is reliable, so that results are fast and accurate.
29. As a user, I want scanned PDFs recognized locally, so that image-only documents can still produce editable data.
30. As a user, I want ruled tables detected, so that common invoices, reports, and forms convert correctly.
31. As a user, I want borderless tables detected, so that modern reports without visible cell lines remain useful.
32. As a user, I want multiple tables on one page separated into understandable worksheets, so that unrelated data is not mixed.
33. As a user, I want tables spanning multiple pages handled consistently, so that long reports do not require manual reconstruction.
34. As a user, I want merged cells preserved when the structure is clear, so that headings retain their meaning.
35. As a user, I want rows and columns to remain editable Excel cells, so that I can calculate, sort, and filter the result.
36. As a user, I want numeric and date-like values retained without destructive guessing, so that identifiers and leading zeroes are not lost.
37. As a user, I want source-page information in the workbook, so that I can trace extracted data back to the PDF.
38. As a user, I want uncertain extraction identified clearly, so that I know which output needs review.
39. As a user, I want low-confidence warnings to be unobtrusive when no review is needed, so that good conversions stay simple.
40. As a user, I want safe worksheet names, so that every generated workbook opens correctly in Excel.
41. As a user, I want conversion failures to explain whether the PDF, page content, destination, or local storage caused the problem, so that I can recover.
42. As a user, I want files with spaces and non-English characters in their paths to work, so that naming conventions do not cause failures.
43. As a user, I want the application to avoid overwriting an existing workbook without confirmation, so that my work is protected.
44. As a user, I want temporary conversion files cleaned up, so that repeated use does not consume unnecessary disk space.
45. As a user, I want the interface to remain responsive during conversion, so that progress and cancellation continue to work.
46. As a user, I want conversion results to be deterministic for the same document and application version, so that repeated runs are predictable.
47. As a user, I want the application version and conversion-engine version available for support, so that problems can be reproduced.
48. As a user, I want Open PDF to start without downloading models, so that the first offline conversion succeeds.
49. As a security-conscious user, I want document paths passed safely to the converter, so that unusual filenames cannot be interpreted as commands.
50. As a user, I want signed and notarized packages, so that the operating system can verify the publisher.
51. As a maintainer, I want malformed PDFs and converter crashes isolated from the main workflow, so that errors can be reported and recovered from.
52. As a maintainer, I want conversion quality measured on clean, complex, rotated, noisy, and scanned documents, so that regressions are caught before release.
53. As a maintainer, I want benchmark failures reported by document and table type, so that improvements target real weaknesses.
54. As a maintainer, I want the production package to contain one conversion stack, so that installation size and support complexity remain controlled.
55. As a maintainer, I want platform-specific builds produced on their native operating systems, so that bundled binaries are valid and testable.
56. As a maintainer, I want all third-party notices included, so that distribution respects dependency licenses.
57. As a maintainer, I want signing credentials supplied only by secure build environments, so that secrets are never stored in the source.
58. As a support engineer, I want useful local diagnostics that exclude document contents, so that failures can be investigated without exposing private data.

## Implementation Decisions

- The first release includes PDF viewing and PDF-to-Excel conversion only.
- Flutter is the desktop application framework for both macOS and Windows.
- PDFium, accessed through `pdfrx`, is the rendering engine on both platforms to keep behavior consistent.
- Native operating-system file dialogs are used for opening PDFs and choosing workbook destinations.
- The application uses native window chrome and familiar desktop controls. Custom window behavior is added only when required by a demonstrated interaction.
- The viewer contains a thumbnail rail, document canvas, compact navigation and zoom controls, search, and one primary conversion action.
- Application state uses Flutter's built-in state primitives initially. A larger state-management dependency is introduced only if the implemented workflows require it.
- Excel conversion runs in a bundled Python worker. Users do not install or manage Python.
- The initial production conversion stack is Camelot 2.0 with classic, machine-learning, and OCR extraction paths, plus `openpyxl` for workbook creation.
- Digital pages use deterministic text and geometry extraction first. Difficult or low-confidence pages retry with machine-learning table recognition. Image-only pages use local OCR.
- Heavier or overlapping engines are not bundled initially. PaddleOCR or Docling may replace or supplement the selected engine only when benchmark evidence identifies a material quality gap worth the package-size and maintenance cost.
- The Flutter application starts the worker directly as a child process with no shell and no local HTTP service.
- The application and worker exchange newline-delimited JSON through standard input and output.
- The worker protocol supports a version handshake, conversion request, progress event, warning event, completion event, cancellation, and structured failure.
- Standard error is reserved for diagnostics and must always be drained to prevent process deadlocks.
- The application enforces timeouts, supports cancellation, and treats abnormal worker termination as a recoverable conversion failure.
- A conversion produces one worksheet per detected table rather than attempting pixel-perfect page reconstruction.
- Workbooks preserve editable values and confident merged-cell structure, include source-page metadata, and include a review worksheet only when warnings exist.
- Potentially destructive type inference is avoided. Values remain text where numeric or date conversion would risk changing their meaning.
- Low-confidence output is surfaced explicitly. The application must not represent uncertain extraction as verified.
- Models and native libraries are bundled during the build. Runtime model downloads are disabled.
- The Python worker is frozen as a one-folder application and embedded inside the platform package. The distributed product remains one installer per platform.
- Windows distribution targets a signed x64 MSIX package initially.
- macOS distribution targets signed and notarized application packages for Apple silicon and Intel, or a universal package when all embedded native components support it.
- Windows artifacts are built on Windows and macOS artifacts are built on macOS.
- Installed application directories are treated as read-only. Logs, temporary files, and user state are written only to platform-appropriate user locations.
- PDF and workbook paths are passed as process arguments or protocol fields without command-string construction.
- The application performs all document processing locally and has no account, telemetry, cloud-conversion, or network requirement in the first release.
- Dependency versions, model artifacts, and license notices are pinned and recorded for reproducible builds.
- Conversion quality is a release gate. The initial corpus includes generated and redistributable digital, scanned, ruled, borderless, merged-cell, multi-page, rotated, and noisy examples with manually verified expected workbooks.
- Adobe-parity claims require later evidence from actual Acrobat exports or representative customer documents. Synthetic tests alone cannot prove that switching users will see no degradation.

## Testing Decisions

- Tests assert externally observable behavior rather than internal parser choices, widget structure, private methods, or implementation-specific calls.
- Desktop workflow and converter protocol are equal acceptance seams.
- The desktop workflow seam covers install and launch, opening a document, viewing and navigating it, searching, starting conversion, observing progress, cancelling, recovering from errors, saving a workbook, and opening another document afterward.
- The converter protocol seam covers handshake compatibility, request validation, progress ordering, cancellation, structured errors, abnormal termination, output-path handling, and workbook completion.
- Viewer tests verify visible page behavior, navigation, zoom, search, password prompts, and recoverable document errors using representative PDFs.
- Conversion tests provide input PDFs and assert workbook-observable results: worksheet count, names, values, row and column structure, merged ranges, source metadata, warning behavior, and workbook validity.
- Accuracy tests compare extracted cells and structure with manually verified expected outputs. Metrics include table detection, cell-text precision and recall, row and column structure, runtime, and peak memory.
- Benchmark results are grouped by document class so that strong results on clean digital PDFs cannot conceal poor scan or complex-layout performance.
- End-to-end tests launch the same frozen worker used by the packaged app rather than replacing it with a mock.
- Failure tests cover corrupted PDFs, unsupported encryption, invalid page ranges, read-only destinations, full disks where practical, worker crashes, timeouts, cancellation, paths containing spaces, and non-ASCII paths.
- Packaging smoke tests run on clean supported Windows and macOS environments and verify install, launch, open, convert, cancel, offline operation, and uninstall.
- Security-oriented tests include malformed PDF samples and confirm that filenames cannot cause shell execution.
- Performance checks use large documents and repeated conversions to detect unbounded memory growth or leftover worker processes.
- Visual tests focus on stable high-level layout and control availability. They do not snapshot platform-native dialogs or every rendered PDF pixel.
- There is no prior test architecture in the repository. The first implementation establishes these two high-level seams without adding lower-level seams unless a failure cannot be diagnosed otherwise.

## Out of Scope

- Editing PDF text or images
- Creating PDFs
- Annotations and comments
- Form authoring or form filling
- Electronic or cryptographic signatures
- Redaction
- Merge, split, reorder, rotate, compress, or optimize tools
- Conversion to Word, PowerPoint, images, or other formats
- Pixel-perfect reproduction of complete PDF pages inside Excel
- Guaranteed perfect conversion of arbitrary PDFs
- Cloud conversion or cloud storage
- User accounts, subscriptions, and team administration
- Mobile, web, and Linux releases
- Browser extensions
- Automatic updates
- Plugins or a public extension API
- Bundling multiple conversion engines without benchmark evidence
- A claim of Adobe Acrobat conversion parity without comparable output evidence

## Further Notes

- The repository is currently empty, so this specification establishes the initial product vocabulary and test boundaries.
- “Single executable” means one installer or application package for the user. The installed application may contain bundled native libraries, models, and a helper process.
- Offline machine-learning conversion will materially increase installer size. Quality takes priority over a small download, but every bundled engine must justify itself through benchmark results.
- A public and synthetic corpus can guide development but cannot reproduce every proprietary Acrobat behavior. Representative real-world documents and Acrobat-generated outputs should be added before making parity claims.
- Conversion confidence is a user-safety feature, not a substitute for accuracy. The preferred experience is a correct workbook with no warnings; warnings exist to prevent silent degradation on difficult documents.
