import 'dart:io';

import 'package:craftstream/core/yaml_loader.dart';
import 'package:craftstream/domain/media/upload_engine.dart';
import 'package:craftstream/schemas/media/upload_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const path = 'assets/config/media/upload.yml';
UploadSchema rules([String Function(String)? edit]) {
  final text = File(path).readAsStringSync();
  return parseYaml(edit == null ? text : edit(text), path, UploadSchema.fromJson);
}

void main() {
  final engine = UploadEngine(rules());

  test('backoff follows the list, then repeats the last value', () {
    expect(engine.backoff(1), const Duration(seconds: 1));
    expect(engine.backoff(3), const Duration(seconds: 5));
    expect(engine.backoff(50), const Duration(seconds: 30));
  });

  test('chunks never run past the end of the file', () {
    expect(engine.nextChunk(offset: 0, total: 100, chunkSize: 40), (start: 0, length: 40));
    expect(engine.nextChunk(offset: 80, total: 100, chunkSize: 40), (start: 80, length: 20));
    expect(engine.nextChunk(offset: 100, total: 100, chunkSize: 40), (start: 100, length: 0));
  });

  test('duration check against the server limit', () {
    expect(UploadEngine.fitsDuration(const Duration(minutes: 15), 900), isTrue);
    expect(UploadEngine.fitsDuration(const Duration(minutes: 15, seconds: 1), 900), isFalse);
  });

  test('polling settings', () {
    expect(engine.statusPollInterval, const Duration(seconds: 3));
    expect(engine.statusPollTimeout, const Duration(minutes: 30));
  });

  test('bad files are rejected', () {
    expect(() => UploadEngine(rules((t) => t.replaceFirst('[1, 2, 5, 10, 30]', '[]'))), throwsA(isA<UploadRulesError>()));
    expect(() => rules((t) => '$t\nchunk_size_kib: 8192\n'), throwsA(isA<ConfigError>()));
  });
}
