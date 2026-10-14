/// Shape of assets/config/ui/bricks.yml: every brick's props and style.
library;

import 'package:json_annotation/json_annotation.dart';

part 'bricks_schema.g.dart';

@JsonSerializable()
class BricksSchema {
  final Map<String, BrickSchema> bricks;

  const BricksSchema({required this.bricks});

  factory BricksSchema.fromJson(Map<String, dynamic> json) => _$BricksSchemaFromJson(json);
}

@JsonSerializable()
class BrickSchema {
  final String about;
  final Map<String, PropSchema> props;

  /// Free-form look: spacing steps, radius names, text styles, colours or numbers. Each brick reads its own keys.
  final Map<String, Object?> style;

  const BrickSchema({required this.about, required this.props, this.style = const {}});

  factory BrickSchema.fromJson(Map<String, dynamic> json) => _$BrickSchemaFromJson(json);
}

@JsonEnum(fieldRename: FieldRename.snake)
enum PropType { text, args, bind, action, icon, role, tone, color, style, space, doorArt, enumeration, bool, number, node, nodes, rows, steps }

@JsonSerializable()
class PropSchema {
  @JsonKey(fromJson: _propType)
  final PropType type;
  final bool required;
  final List<String>? options;
  @JsonKey(name: 'default')
  final Object? defaultValue;

  const PropSchema({required this.type, this.required = false, this.options, this.defaultValue});

  factory PropSchema.fromJson(Map<String, dynamic> json) => _$PropSchemaFromJson(json);
}

/// `enum` is a Dart keyword, so the YAML word maps to [PropType.enumeration].
PropType _propType(Object? v) {
  final s = v.toString();
  if (s == 'enum') return PropType.enumeration;
  return PropType.values.firstWhere(
    (t) => t != PropType.enumeration && _snake(t.name) == s,
    orElse: () => throw ArgumentError('unknown prop type "$s"'),
  );
}

String _snake(String camel) => camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
