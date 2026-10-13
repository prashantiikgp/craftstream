import 'package:craftstream/shared/format/bytes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file sizes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(8 * 1024 * 1024), '8 MB');
    expect(formatBytes(2150 * 1024 * 1024), '2.1 GB');
  });

  test('video lengths', () {
    expect(formatDuration(const Duration(minutes: 12, seconds: 40)), '12:40');
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 5)), '1:02:05');
  });
}
