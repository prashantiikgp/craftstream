/// Shape of assets/config/app/navigation.yml: the Buy and Sell roles.
library;

import 'package:json_annotation/json_annotation.dart';

part 'navigation_schema.g.dart';

@JsonSerializable()
class NavigationSchema {
  final Map<String, RoleSchema> roles;

  const NavigationSchema({required this.roles});

  factory NavigationSchema.fromJson(Map<String, dynamic> json) => _$NavigationSchemaFromJson(json);
}

@JsonSerializable()
class RoleSchema {
  final String number;

  /// A strings.yml key.
  final String label;

  /// An accent name from ui/theme.yml.
  final String accent;
  final String home;
  final List<String> paths;

  const RoleSchema({
    required this.number,
    required this.label,
    required this.accent,
    required this.home,
    required this.paths,
  });

  factory RoleSchema.fromJson(Map<String, dynamic> json) => _$RoleSchemaFromJson(json);
}
