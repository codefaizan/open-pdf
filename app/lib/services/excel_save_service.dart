import 'dart:io';

import 'package:file_selector/file_selector.dart';

/// Chooses workbook destinations through the platform save dialog.
abstract class ExcelSaveService {
  Future<String?> pickSaveLocation({required String suggestedName});

  bool destinationExists(String path);
}

class NativeExcelSaveService implements ExcelSaveService {
  const NativeExcelSaveService();

  static const _xlsxTypeGroup = XTypeGroup(
    label: 'Excel Workbook',
    extensions: ['xlsx'],
    uniformTypeIdentifiers: ['org.openxmlformats.spreadsheetml.sheet'],
  );

  @override
  Future<String?> pickSaveLocation({required String suggestedName}) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_xlsxTypeGroup],
      suggestedName: suggestedName,
      confirmButtonText: 'Save',
    );
    return location?.path;
  }

  @override
  bool destinationExists(String path) => File(path).existsSync();
}
