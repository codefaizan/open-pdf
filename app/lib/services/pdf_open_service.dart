import 'package:file_selector/file_selector.dart';

/// Opens PDFs through the platform file picker.
abstract class PdfOpenService {
  Future<String?> pickPdfFile();
}

class NativePdfOpenService implements PdfOpenService {
  const NativePdfOpenService();

  static const _pdfTypeGroup = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    uniformTypeIdentifiers: ['com.adobe.pdf'],
  );

  @override
  Future<String?> pickPdfFile() async {
    final file = await openFile(acceptedTypeGroups: const [_pdfTypeGroup]);
    return file?.path;
  }
}
