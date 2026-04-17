enum UserRole { driver, parent }

UserRole userRoleFromString(String value) {
  final normalized = value.trim().toLowerCase();

  if (normalized == 'driver' || normalized == 'سائق') {
    return UserRole.driver;
  }

  if (normalized == 'parent' ||
      normalized == 'ولي_امر' ||
      normalized == 'ولي أمر' ||
      normalized == 'guardian' ||
      normalized == 'passenger' ||
      normalized == 'user' ||
      normalized == 'راكب') {
    return UserRole.parent;
  }

  return UserRole.parent;
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.driver:
      return 'driver';
    case UserRole.parent:
      return 'parent';
  }
}
