/// Shape of assets/config/app/routes.yml: every route and what it shows.
library;

import 'package:json_annotation/json_annotation.dart';

part 'routes_schema.g.dart';

@JsonSerializable()
class RoutesSchema {
  final String initial;
  final List<RouteSchema> routes;

  const RoutesSchema({required this.initial, required this.routes});

  factory RoutesSchema.fromJson(Map<String, dynamic> json) => _$RoutesSchemaFromJson(json);
}

@JsonSerializable()
class RouteSchema {
  final String path;

  /// A screen YAML in ui/screens/ (exactly one of [screen] and [legacy]).
  final String? screen;

  /// A v1 Dart screen, registered in core/router.dart, until it moves to YAML.
  final String? legacy;
  final bool devOnly;
  final List<RouteSchema> routes;

  const RouteSchema({
    required this.path,
    this.screen,
    this.legacy,
    this.devOnly = false,
    this.routes = const [],
  });

  factory RouteSchema.fromJson(Map<String, dynamic> json) => _$RouteSchemaFromJson(json);
}
