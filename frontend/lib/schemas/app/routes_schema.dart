/// Shape of assets/config/app/routes.yml: every route and what it shows.
library;

import 'package:json_annotation/json_annotation.dart';

part 'routes_schema.g.dart';

@JsonSerializable()
class RoutesSchema {
  final List<RouteSchema> routes;

  const RoutesSchema({required this.routes});

  factory RoutesSchema.fromJson(Map<String, dynamic> json) => _$RoutesSchemaFromJson(json);
}

@JsonSerializable()
class RouteSchema {
  final String path;

  /// The screen YAML in ui/screens/ this route shows.
  final String screen;
  final List<RouteSchema> routes;

  const RouteSchema({required this.path, required this.screen, this.routes = const []});

  factory RouteSchema.fromJson(Map<String, dynamic> json) => _$RouteSchemaFromJson(json);
}
