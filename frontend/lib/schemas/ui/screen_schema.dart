/// Shape of one file in assets/config/ui/screens/: a screen as a list of bricks. The bricks themselves are checked
/// against ui/bricks.yml by the screen engine.
library;

import 'package:json_annotation/json_annotation.dart';

part 'screen_schema.g.dart';

@JsonEnum()
enum ScreenWidth { narrow, wide, auto }

@JsonSerializable()
class ScreenSchema {
  final String about;

  /// The data source (lib/shared/screens/sources.dart) that fills the screen's bindings; none for static screens.
  final String? data;

  /// narrow: forms and confirmations (layout.yml form_max_width); wide: grids and lists (max_content_width);
  /// auto: narrow where layout.yml stacks (phones, portrait tablets), wide where it goes side by side.
  final ScreenWidth width;

  /// Spacing step between body bricks.
  final String gap;

  /// true: the body fills the screen height (doors share it, a spacer pushes what follows down) and scrolls only
  /// when it does not fit.
  final bool fill;

  /// A backdrop from ui/art.yml drawn behind everything.
  final String? backdrop;

  final List<Object?> top;
  final List<Object?> body;
  final List<Object?> bottom;

  /// Shown instead of body when the data source has nothing (no orders yet) or fails.
  final List<Object?> empty;
  final List<Object?> error;

  const ScreenSchema({
    required this.about,
    this.data,
    this.width = ScreenWidth.wide,
    this.gap = 'lg',
    this.fill = false,
    this.backdrop,
    this.top = const [],
    required this.body,
    this.bottom = const [],
    this.empty = const [],
    this.error = const [],
  });

  factory ScreenSchema.fromJson(Map<String, dynamic> json) => _$ScreenSchemaFromJson(json);
}
