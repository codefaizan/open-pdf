import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/services/conversion_protocol.dart';

void main() {
  group('page range validation', () {
    test('accepts empty or null as all pages', () {
      expect(isValidPageRange(null), isTrue);
      expect(isValidPageRange(''), isTrue);
      expect(isValidPageRange('   '), isTrue);
    });

    test('accepts single pages and ranges', () {
      expect(isValidPageRange('1'), isTrue);
      expect(isValidPageRange('1-3'), isTrue);
      expect(isValidPageRange('1-3,5'), isTrue);
      expect(isValidPageRange('2,4-6,8'), isTrue);
    });

    test('rejects invalid page ranges', () {
      expect(isValidPageRange('0'), isFalse);
      expect(isValidPageRange('1-'), isFalse);
      expect(isValidPageRange('-3'), isFalse);
      expect(isValidPageRange('1,,2'), isFalse);
      expect(isValidPageRange('abc'), isFalse);
    });
  });
}
