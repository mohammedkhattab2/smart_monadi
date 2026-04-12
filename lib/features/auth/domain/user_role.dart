enum UserRole { driver, passenger }

UserRole userRoleFromString(String value) {
  final normalized = value.trim().toLowerCase();

  if (normalized == 'driver' || normalized == 'سائق') {
    return UserRole.driver;
  }

  if (normalized == 'passenger' ||
      normalized == 'user' ||
      normalized == 'راكب') {
    return UserRole.passenger;
  }

  return UserRole.passenger;
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.driver:
      return 'driver';
    case UserRole.passenger:
      return 'passenger';
  }
}
