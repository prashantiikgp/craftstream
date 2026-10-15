import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/logs/activity_log_engine.dart';
import 'package:craftstream/schemas/logs/activity_log_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/logs/activity_log.yml';
ActivityLogSchema rules([String Function(String yaml)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, ActivityLogSchema.fromJson);
}

void main() {
  final engine = ActivityLogEngine(rules());

  test('activity_log.yml loads', () {
    expect(engine.reports, isTrue);
    expect(engine.stepNames, containsAll(['too_long', 'started', 'interrupted', 'resumed', 'finished', 'failed']));
    expect(engine.groups, ['upload', 'video', 'order', 'system']);
    expect(engine.levelLabel('warning'), 'logs.level_warning');
    expect(engine.stringKeys, contains('logs.group_video'));
    expect(engine.levels, ['info', 'warning', 'error']);
    expect(engine.toneOf('error'), 'danger');
  });

  test('a step becomes its event with the listed values, in order, missing ones left out', () {
    final r = engine.report('interrupted', {'reason': 'network', 'size': 2048, 'sent': 1024, 'extra': 'x'})!;
    expect(r.event, 'upload_interrupted');
    expect(r.details, [('sent', '1024'), ('size', '2048'), ('reason', 'network')]);
    expect(engine.report('resumed', {'size': 5})!.details, [('size', '5')]);
    expect(engine.report('no_such_step', const {}), isNull);
  });

  test('reporting off: nothing is sent', () {
    final quiet = ActivityLogEngine(rules((y) => y.replaceFirst('report: true', 'report: false')));
    expect(quiet.report('started', {'size': 1}), isNull);
  });

  test('only the newest pending reports are kept', () {
    final two = ActivityLogEngine(rules((y) => y.replaceFirst('pending_max: 20', 'pending_max: 2')));
    expect(two.keepPending([1, 2, 3]), [2, 3]);
    expect(two.keepPending([1]), [1]);
  });

  test('refresh 0 means only on request', () {
    expect(engine.refresh, const Duration(seconds: 15));
    expect(ActivityLogEngine(rules((y) => y.replaceFirst('refresh_seconds: 15', 'refresh_seconds: 0'))).refresh, isNull);
  });

  test('bad rules fail at load', () {
    expect(() => ActivityLogEngine(rules((y) => y.replaceFirst('page_size: 30', 'page_size: 0'))),
        throwsA(isA<ActivityLogRulesError>()));
    expect(() => rules((y) => y.replaceFirst('pending_max:', 'pending_maxx:')), throwsA(isA<ConfigError>()));
  });
}
