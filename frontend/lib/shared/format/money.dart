/// Money for people: Indian digit grouping for INR (₹1,20,000), western for USD ($1,234.50).
/// Paise/cents are shown only when they are not zero.
library;

String formatMoney(num amount, String currency) {
  final negative = amount < 0;
  final cents = (amount.abs() * 100).round();
  final whole = (cents ~/ 100).toString();
  final fraction = cents % 100;
  final grouped = currency == 'INR' ? _groupIndian(whole) : _groupWestern(whole);
  final symbol = switch (currency) { 'INR' => '₹', 'USD' => r'$', _ => '$currency ' };
  final decimals = fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}';
  return '${negative ? '−' : ''}$symbol$grouped$decimals';
}

String _groupWestern(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Last three digits, then groups of two: 12345678 -> 1,23,45,678.
String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final parts = <String>[];
  for (var end = head.length; end > 0; end -= 2) {
    parts.insert(0, head.substring(end - 2 < 0 ? 0 : end - 2, end));
  }
  return '${parts.join(',')},$tail';
}
