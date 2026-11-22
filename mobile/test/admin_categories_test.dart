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
    expect(validateCategoryName(List.filled(80, 'x').join()), isNull);
    expect(validateCategoryName(List.filled(81, 'x').join()), isNotNull);
  });
}
