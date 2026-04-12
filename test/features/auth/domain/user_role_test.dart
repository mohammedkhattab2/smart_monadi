import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

void main() {
  group('userRoleFromString', () {
    test('parses driver role with normalization', () {
      expect(userRoleFromString('driver'), UserRole.driver);
      expect(userRoleFromString(' DRIVER '), UserRole.driver);
      expect(userRoleFromString('سائق'), UserRole.driver);
    });

    test('parses passenger/user values and defaults safely', () {
      expect(userRoleFromString('passenger'), UserRole.passenger);
      expect(userRoleFromString('USER'), UserRole.passenger);
      expect(userRoleFromString('راكب'), UserRole.passenger);
      expect(userRoleFromString('unknown'), UserRole.passenger);
      expect(userRoleFromString(''), UserRole.passenger);
    });
  });
}
