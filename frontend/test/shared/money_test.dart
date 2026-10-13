import 'package:craftstream/shared/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('INR uses Indian grouping and hides zero paise', () {
    expect(formatMoney(450, 'INR'), '₹450');
    expect(formatMoney(1000, 'INR'), '₹1,000');
    expect(formatMoney(120000, 'INR'), '₹1,20,000');
    expect(formatMoney(12345678, 'INR'), '₹1,23,45,678');
    expect(formatMoney(499.5, 'INR'), '₹499.50');
    expect(formatMoney(0.3, 'INR'), '₹0.30');
  });

  test('USD uses western grouping', () {
    expect(formatMoney(1234.5, 'USD'), r'$1,234.50');
    expect(formatMoney(1000000, 'USD'), r'$1,000,000');
  });
}
