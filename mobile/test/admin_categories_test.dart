import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/features/operations/admin_categories_page.dart';

void main() {
  test('Category names are validated without accepting empty values', () {
    expect(validateCategoryName(null), isNotNull);
    expect(validateCategoryName(''), isNotNull);
    expect(validateCategoryName(' '), isNotNull);
    expect(validateCategoryName('a'), isNotNull);
    expect(validateCategoryName('  Internet  '), isNull);
    expect(validateCategoryName('Building maintenance'), isNull);
    expect(validateCategoryName('x' * 80), isNull);
    expect(validateCategoryName('x' * 81), isNotNull);
  });
}
