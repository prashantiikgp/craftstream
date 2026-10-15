/// Writes money, file sizes, video lengths, dates and times the way format.yml says. Pure Dart: bricks and screen
/// sources call it instead of building text by hand.
library;

import 'dart:math' as math;

import '../../schemas/ui/format_schema.dart';

class FormatRulesError implements Exception {
  final String message;
  const FormatRulesError(this.message);
  @override
  String toString() => 'format.yml: $message';
}

final _placeholder = RegExp(r'\{(\w+)\}');

/// What each kind of pattern may name.
const _datePlaceholders = {'yyyy', 'MM', 'dd', 'HH', 'mm', 'ss'};
const _durationPlaceholders = {'h', 'm', 'mm', 'ss'};
const _bytesPlaceholders = {'value', 'unit'};
const _symbolPlaceholders = {'code'};

class FormatEngine {
  final FormatSchema rules;

  FormatEngine(this.rules) {
    final m = rules.money;
    if (m.decimals < 0 || m.decimals > 4) throw const FormatRulesError('money.decimals must be 0-4');
    for (final (name, c) in [
      ...m.currencies.entries.map((e) => ('money.currencies.${e.key}', e.value)),
      ('money.other', m.other),
    ]) {
      if (c.grouping.isEmpty || c.grouping.any((g) => g < 1)) {
        throw FormatRulesError('$name.grouping must be a non-empty list of sizes >= 1');
      }
      _check('$name.symbol', c.symbol, _symbolPlaceholders);
    }
    final b = rules.bytes;
    if (b.base < 2) throw const FormatRulesError('bytes.base must be at least 2');
    if (b.units.isEmpty || b.units.last.power != 0) {
      throw const FormatRulesError('bytes.units must end with the power-0 unit (bytes)');
    }
    for (var i = 1; i < b.units.length; i++) {
      if (b.units[i].power >= b.units[i - 1].power) throw const FormatRulesError('bytes.units must go biggest first');
    }
    if (b.units.any((u) => u.decimals < 0 || u.decimals > 4)) {
      throw const FormatRulesError('bytes decimals must be 0-4');
    }
    _check('bytes.pattern', b.pattern, _bytesPlaceholders, required: _bytesPlaceholders);
    _check('duration.short', rules.duration.short, _durationPlaceholders);
    _check('duration.long', rules.duration.long, _durationPlaceholders);
    _check('date', rules.date, _datePlaceholders);
    _check('time', rules.time, _datePlaceholders);
  }

  static void _check(String where, String pattern, Set<String> allowed, {Set<String> required = const {}}) {
    final named = {for (final m in _placeholder.allMatches(pattern)) m[1]!};
    final unknown = named.difference(allowed);
    if (unknown.isNotEmpty) {
      throw FormatRulesError('$where: unknown {${unknown.join('}, {')}} (allowed: ${allowed.join(', ')})');
    }
    final missing = required.difference(named);
    if (missing.isNotEmpty) throw FormatRulesError('$where must contain {${missing.join('}, {')}}');
  }

  static String _fill(String pattern, Map<String, String> values) =>
      pattern.replaceAllMapped(_placeholder, (m) => values[m[1]] ?? m[0]!);

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `₹1,20,000`, `₹499.50`, `$1,234.50`, `−₹450`.
  String money(num amount, String currency) {
    final m = rules.money;
    final c = m.currencies[currency] ?? m.other;
    final scale = math.pow(10, m.decimals).toInt();
    final minor = (amount.abs() * scale).round();
    final fraction = minor % scale;
    final grouped = _group((minor ~/ scale).toString(), c.grouping, m.thousands);
    final decimals = m.decimals == 0 || (fraction == 0 && m.hideZeroFraction)
        ? ''
        : '${m.decimalPoint}${fraction.toString().padLeft(m.decimals, '0')}';
    final symbol = _fill(c.symbol, {'code': currency});
    return '${amount < 0 ? m.minus : ''}$symbol$grouped$decimals';
  }

  /// Digit groups from the right; the last size repeats ([3, 2]: 1,23,45,678).
  static String _group(String digits, List<int> sizes, String separator) {
    final parts = <String>[];
    var end = digits.length;
    for (var i = 0; end > 0; i++) {
      final start = math.max(0, end - sizes[math.min(i, sizes.length - 1)]);
      parts.insert(0, digits.substring(start, end));
      end = start;
    }
    return parts.join(separator);
  }

  /// `512 B`, `8 MB`, `2.1 GB`: the biggest unit the size reaches.
  String bytes(int n) {
    final b = rules.bytes;
    final u = b.units.firstWhere((u) => n >= math.pow(b.base, u.power), orElse: () => b.units.last);
    final v = n / math.pow(b.base, u.power);
    return _fill(b.pattern, {
      'value': u.decimals == 0 ? '${v.round()}' : v.toStringAsFixed(u.decimals),
      'unit': u.unit,
    });
  }

  /// `12:40`, `0:05`, `1:02:05`.
  String duration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return _fill(h > 0 ? rules.duration.long : rules.duration.short, {
      'h': '$h',
      'm': '$m',
      'mm': _two(m),
      'ss': _two(s),
    });
  }

  Map<String, String> _dateValues(DateTime at) => {
    'yyyy': '${at.year}',
    'MM': _two(at.month),
    'dd': _two(at.day),
    'HH': _two(at.hour),
    'mm': _two(at.minute),
    'ss': _two(at.second),
  };

  /// [at] as a date (`2026-10-15`), in the time zone [at] is in.
  String date(DateTime at) => _fill(rules.date, _dateValues(at));

  /// [at] as a time of day (`09:05:07`), in the time zone [at] is in.
  String time(DateTime at) => _fill(rules.time, _dateValues(at));
}
