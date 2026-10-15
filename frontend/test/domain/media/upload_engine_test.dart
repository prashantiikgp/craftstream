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

  test('upload session answers: done, continue, retry, everything else rejected', () {
    expect(engine.answerFor(200), UploadAnswer.done);
    expect(engine.answerFor(201), UploadAnswer.done);
    expect(engine.answerFor(308), UploadAnswer.more);
    for (final s in [408, 429, 500, 503, 599]) {
      expect(engine.answerFor(s), UploadAnswer.retry, reason: '$s');
    }
    for (final s in [400, 403, 404, 410, 302]) {
      expect(engine.answerFor(s), UploadAnswer.reject, reason: '$s');
    }
    expect(
      () => UploadEngine(rules((t) => t.replaceFirst('done: [200, 201]', 'done: [200, 201, 503]'))),
      throwsA(isA<UploadRulesError>()),
      reason: '503 would be in two places',
    );
    expect(
      () => UploadEngine(rules((t) => t.replaceFirst('continue: [308]', 'continue: [3oo]'))),
      throwsA(isA<UploadRulesError>()),
    );
  });

  test('picking: file types by extension, the dialog filter and the metadata timeout', () {
    expect(engine.mimeTypeFor('MOV'), 'video/quicktime');
    expect(engine.mimeTypeFor('3gp'), 'video/3gpp');
    expect(engine.mimeTypeFor('avi'), 'video/mp4');
    expect(engine.mimeTypeFor(null), 'video/mp4');
    expect(engine.pickerAccept, 'video/*');
    expect(engine.metadataTimeout, const Duration(seconds: 15));
  });

  test('tags: chips first, then the typed ones, trimmed, lower case, no repeats', () {
    expect(engine.mergeTags({'pottery'}, ' Kitchen, ,pottery,  Blue Glaze '), ['pottery', 'kitchen', 'blue glaze']);
    expect(engine.mergeTags(const {}, ''), isEmpty);
  });

  test('price: thousands separators ignored; not a number or below the minimum is null', () {
    expect(engine.parsePrice('1,200', min: 1), 1200);
    expect(engine.parsePrice(' 499.5 ', min: 1), 499.5);
    expect(engine.parsePrice('abc', min: 1), isNull);
    expect(engine.parsePrice('0.5', min: 1), isNull);
    expect(engine.parsePrice('Infinity', min: 1), isNull);
    expect(engine.currency, 'INR');
  });

  test('bad files are rejected', () {
    expect(
      () => UploadEngine(rules((t) => t.replaceFirst('[1, 2, 5, 10, 30]', '[]'))),
      throwsA(isA<UploadRulesError>()),
    );
    expect(() => rules((t) => '$t\nchunk_size_kib: 8192\n'), throwsA(isA<ConfigError>()));
  });
}
