import 'package:archives/core/utils/role_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isAdminOrHigher allows only admin', () {
    expect(isAdminOrHigher('admin'), isTrue);
    expect(isAdminOrHigher('user'), isFalse);
    expect(isAdminOrHigher(null), isFalse);
  });
}
