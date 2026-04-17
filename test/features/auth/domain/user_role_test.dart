import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

void main() {
  group('userRoleFromString', () {
    test('parses driver role with normalization', () {
      expect(userRoleFromString('driver'), UserRole.driver);
      expect(userRoleFromString(' DRIVER '), UserRole.driver);
      expect(userRoleFromString('سائق'), UserRole.driver);
    });

    test('parses parent aliases and defaults safely', () {
      expect(userRoleFromString('parent'), UserRole.parent);
      expect(userRoleFromString('guardian'), UserRole.parent);
      expect(userRoleFromString('passenger'), UserRole.parent);
      expect(userRoleFromString('USER'), UserRole.parent);
      expect(userRoleFromString('راكب'), UserRole.parent);
      expect(userRoleFromString('unknown'), UserRole.parent);
      expect(userRoleFromString(''), UserRole.parent);
    });
  });
}
