enum UserRole { driver, passenger }

UserRole userRoleFromString(String value) {
  if (value == 'driver') {
    return UserRole.driver;
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
