// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';

void main() {
  test('Passenger entity stores values', () {
    const passenger = Passenger(
      id: '0123456789',
      name: 'Ali',
      phone: '0123456789',
      address: 'Cairo',
      pickupTime: '07:30',
      updatedAtMillis: 1,
    );

    expect(passenger.id, '0123456789');
    expect(passenger.pickupTime, '07:30');
  });
}
