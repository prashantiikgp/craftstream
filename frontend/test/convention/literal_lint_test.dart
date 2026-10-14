// No literals in screens, bricks or components: colours, icons, durations, sizes, route paths and status strings
// belong in YAML. Files still being migrated are listed in literal_baseline.yml with their current counts.
// The baseline may only shrink: a new literal fails, and so does a count lower than the baseline (lower it then).
//
//   UPDATE_LITERAL_BASELINE=1 flutter test test/convention/literal_lint_test.dart   # rewrite the baseline
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const baselinePath = 'test/convention/literal_baseline.yml';

/// Code that composes UI. Engines, schemas, data and artwork (lib/shared/brand) are checked elsewhere or exempt.
const scanned = [
  'lib/features',
  'lib/shared/widgets',
  'lib/shared/bricks',
  'lib/shared/screens',
  'lib/core/router.dart',
  'lib/app.dart',
];

final kinds = <String, RegExp>{
  'colour': RegExp(r'Color\(0x'),
  'icon': RegExp(r'Icons\.\w+'),
  'duration': RegExp(r'Duration\((milliseconds|seconds|minutes)\s*:\s*\d'),
  'size': RegExp(r'\b(width|height|size|fontSize|maxLines|strokeWidth|radius|elevation|thickness|maxWidth|'
      r'minWidth|maxHeight|minHeight|blurRadius|spreadRadius|aspectRatio)\s*:\s*(\d+\.?\d*)'),
  'inset': RegExp(r'(EdgeInsets\.\w+\(\s*\d|circular\(\s*\d)'),
  'route': RegExp(r'''(\.(go|push|replace|pushReplacement)\(\s*['"]/|\bpath:\s*['"]/)'''),
  // A status compared or passed as a value; map keys ('failed': …) and lookups (m['failed']) are field names.
  'status': RegExp(r"""(?<!\[)['"](ready|processing|failed|awaiting_upload|placed)['"](?!\s*[:\]])"""),
};

Map<String, Map<String, int>> countLiterals() {
  final files = <File>[];
  for (final p in scanned) {
    if (File(p).existsSync()) {
      files.add(File(p));
    } else if (Directory(p).existsSync()) {
      files.addAll(Directory(p).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')));
    }
  }
  final out = <String, Map<String, int>>{};
  for (final f in files..sort((a, b) => a.path.compareTo(b.path))) {
    final lines = f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//'));
    final counts = <String, int>{};
    for (final line in lines) {
      kinds.forEach((kind, re) {
        for (final m in re.allMatches(line)) {
          // 0 and 1 are structure (no padding, one line, full flex), not design values.
          if (kind == 'size' && (double.tryParse(m.group(2)!) ?? 2) <= 1) continue;
          counts[kind] = (counts[kind] ?? 0) + 1;
        }
      });
    }
    if (counts.isNotEmpty) out[f.path] = counts;
  }
  return out;
}

void main() {
  final actual = countLiterals();

  if (Platform.environment['UPDATE_LITERAL_BASELINE'] == '1') {
    final b = StringBuffer('# Literals still in UI code, per file and kind (see literal_lint_test.dart).\n'
        '# This list may only shrink. Move the value to YAML, then lower or delete the entry.\n');
    actual.forEach((file, counts) {
      b.writeln('$file: {${counts.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}');
    });
    File(baselinePath).writeAsStringSync(b.toString());
  }

  test('no new literals in UI code, and the baseline only shrinks', () {
    final raw = loadYaml(File(baselinePath).readAsStringSync()) as YamlMap?;
    final baseline = {
      for (final e in (raw ?? YamlMap()).entries)
        e.key.toString(): {for (final c in (e.value as YamlMap).entries) c.key.toString(): c.value as int},
    };
    final problems = <String>[];
    for (final file in {...actual.keys, ...baseline.keys}) {
      final now = actual[file] ?? const {};
      final allowed = baseline[file] ?? const {};
      for (final kind in {...now.keys, ...allowed.keys}) {
        final n = now[kind] ?? 0, a = allowed[kind] ?? 0;
        if (n > a) problems.add('$file: $n $kind literal(s), baseline allows $a. Put the value in YAML.');
        if (n < a) problems.add('$file: $kind is down to $n. Lower the baseline from $a (nice).');
      }
    }
    expect(problems, isEmpty);
  });
}
