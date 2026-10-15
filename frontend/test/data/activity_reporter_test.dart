// Reporting upload steps never fails an upload: reports that cannot be sent wait (oldest first, at most
// pending_max) and go out, in order, before the next one.
import 'package:craftstream/data/generated/models.dart';
import 'package:craftstream/data/logs/activity_reporter.dart';
import 'package:craftstream/data/repositories/log_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

class _FlakyLogs implements LogRepository {
  bool down = true;
  final sent = <LogEntryCreate>[];

  @override
  Future<LogEntry> report(LogEntryCreate entry) async {
    if (down) throw Exception('offline');
    sent.add(entry);
    return LogEntry(
      id: 'x',
      event: entry.event,
      details: const [],
      level: 'info',
      group: 'upload',
      source: 'app',
      message: '',
      at: DateTime(2026),
    );
  }

  @override
  Future<LogPage> page({String? group, String? level, String? productId, String? cursor, int? limit}) async =>
      const LogPage(items: []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('steps wait while offline and go out in order', () async {
    final c = await testConfig();
    final repo = _FlakyLogs();
    final r = ActivityReporter(repo, c.activityLog);
    r.step(UploadStep.started, productId: 'p1', values: {'size': 100, 'chunks': 2, 'ignored': 1});
    r.step(UploadStep.interrupted, productId: 'p1', values: {'sent': 50, 'size': 100, 'reason': 'network'});
    await Future<void>.delayed(Duration.zero);
    expect(repo.sent, isEmpty);
    expect(r.pending.map((e) => e.event), ['upload_started', 'upload_interrupted']);

    repo.down = false;
    r.step(UploadStep.resumed, productId: 'p1', values: {'from': 50, 'size': 100});
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 5 && r.pending.isNotEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(repo.sent.map((e) => e.event), ['upload_started', 'upload_interrupted', 'upload_resumed']);
    expect(repo.sent.first.details.map((d) => d.key), ['size', 'chunks']);
    expect(r.pending, isEmpty);
  });

  test('at most pending_max reports wait', () async {
    final c = await testConfig();
    final r = ActivityReporter(_FlakyLogs(), c.activityLog);
    for (var i = 0; i < c.activityLog.pendingMax + 5; i++) {
      r.step(UploadStep.failed, values: {'reason': 'r$i'});
    }
    await Future<void>.delayed(Duration.zero);
    expect(r.pending, hasLength(c.activityLog.pendingMax));
    expect(r.pending.last.details.single.value, 'r${c.activityLog.pendingMax + 4}');
  });
}
