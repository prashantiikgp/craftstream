// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'art_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArtSchema _$ArtSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ArtSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['backdrops', 'doors', 'poster']);
      final val = ArtSchema(
        backdrops: $checkedConvert(
          'backdrops',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) => MapEntry(
              k,
              (e as List<dynamic>)
                  .map((e) => ShapeSchema.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ),
          ),
        ),
        doors: $checkedConvert(
          'doors',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) => MapEntry(
              k,
              (e as List<dynamic>)
                  .map((e) => ShapeSchema.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ),
          ),
        ),
        poster: $checkedConvert(
          'poster',
          (v) => PosterSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

ShapeSchema _$ShapeSchemaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ShapeSchema', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const [
      'shape',
      'accent',
      'opacity',
      'size',
      'w',
      'h',
      'left',
      'right',
      'top',
      'bottom',
      'rotate',
    ],
  );
  final val = ShapeSchema(
    shape: $checkedConvert('shape', (v) => $enumDecode(_$ShapeKindEnumMap, v)),
    accent: $checkedConvert('accent', (v) => v as String),
    opacity: $checkedConvert('opacity', (v) => (v as num?)?.toDouble() ?? 1),
    size: $checkedConvert('size', (v) => (v as num?)?.toDouble()),
    w: $checkedConvert('w', (v) => (v as num?)?.toDouble()),
    h: $checkedConvert('h', (v) => (v as num?)?.toDouble()),
    left: $checkedConvert('left', (v) => (v as num?)?.toDouble()),
    right: $checkedConvert('right', (v) => (v as num?)?.toDouble()),
    top: $checkedConvert('top', (v) => (v as num?)?.toDouble()),
    bottom: $checkedConvert('bottom', (v) => (v as num?)?.toDouble()),
    rotate: $checkedConvert('rotate', (v) => (v as num?)?.toDouble() ?? 0),
  );
  return val;
});

const _$ShapeKindEnumMap = {
  ShapeKind.circle: 'circle',
  ShapeKind.square: 'square',
  ShapeKind.bar: 'bar',
};

PosterSchema _$PosterSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PosterSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['colors', 'circle', 'bar']);
      final val = PosterSchema(
        colors: $checkedConvert(
          'colors',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
        circle: $checkedConvert(
          'circle',
          (v) => PosterCircleSchema.fromJson(v as Map<String, dynamic>),
        ),
        bar: $checkedConvert(
          'bar',
          (v) => PosterBarSchema.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

PosterCircleSchema _$PosterCircleSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PosterCircleSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['size', 'x', 'y']);
      final val = PosterCircleSchema(
        size: $checkedConvert(
          'size',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
        x: $checkedConvert(
          'x',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
        y: $checkedConvert(
          'y',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
      );
      return val;
    });

PosterBarSchema _$PosterBarSchemaFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PosterBarSchema', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['thickness', 'y', 'rotate']);
      final val = PosterBarSchema(
        thickness: $checkedConvert('thickness', (v) => (v as num).toDouble()),
        y: $checkedConvert(
          'y',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
        rotate: $checkedConvert(
          'rotate',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
      );
      return val;
    });
