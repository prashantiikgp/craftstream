/// Shape of assets/config/app/app.yml: the app's name, where it opens and the theme it starts in.
library;

import 'package:json_annotation/json_annotation.dart';

part 'app_schema.g.dart';

@JsonSerializable()
class AppSchema {
  final String name;
  final String initialRoute;

  /// light | dark | system
  final String themeMode;

  const AppSchema({required this.name, required this.initialRoute, required this.themeMode});

  factory AppSchema.fromJson(Map<String, dynamic> json) => _$AppSchemaFromJson(json);
}
