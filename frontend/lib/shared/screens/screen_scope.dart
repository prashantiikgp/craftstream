/// What a brick can see while it builds: the screen's data, the route's parameters, the current list item, and a
/// way to run actions. Bindings in screen YAML (`order.total`, `item.id`, `params.order_id`) resolve here.
library;

import 'package:flutter/widgets.dart';

import '../../domain/ui/bricks_engine.dart';

enum SourceState { loading, empty, error, ready }

/// A data source's answer for one screen: its state and the values bindings read. Values are maps and lists whose
/// keys are the field names in models/*.yml (`toJson()` of the generated models), plus a few derived fields.
class ScreenData {
  final SourceState state;
  final Map<String, Object?> values;
  const ScreenData(this.state, [this.values = const {}]);
  const ScreenData.ready(this.values) : state = SourceState.ready;
}

class BrickScope extends InheritedWidget {
  final Map<String, Object?> values;
  final Map<String, String> params;
  final Object? item;

  /// Position of [item] in its list (the newest order is 0).
  final int index;

  /// True when the brick is given a share of the screen height (`fill: true` screens): doors then share it.
  final bool fill;
  final void Function(BuildContext context, ActionSpec action, BrickScope scope) run;

  const BrickScope({
    super.key,
    required this.values,
    required this.params,
    required this.run,
    this.item,
    this.index = 0,
    this.fill = false,
    required super.child,
  });

  static BrickScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrickScope>() ??
      (throw StateError('a brick was built outside a ScreenHost'));

  /// The same scope with [item] as the current list entry (for `list` children).
  BrickScope withItem(Object? item, int index, Widget child) =>
      BrickScope(values: values, params: params, run: run, item: item, index: index, fill: fill, child: child);

  /// The same scope, telling bricks whether they have a share of the screen height.
  BrickScope withFill(bool fill, Widget child) =>
      BrickScope(values: values, params: params, run: run, item: item, index: index, fill: fill, child: child);

  /// `order.total` -> the value, or null when any step is missing. `item.*` reads the list entry, `params.*` the
  /// route parameters, anything else the screen's data.
  Object? lookup(String path) {
    final parts = path.split('.');
    Object? node = switch (parts.first) {
      'item' => item,
      'params' => params,
      _ => values[parts.first],
    };
    for (final p in parts.skip(1)) {
      node = node is Map ? node[p] : null;
    }
    return node;
  }

  /// `/placed/{item.id}` -> `/placed/3129d7a45f42`. Values are URI-encoded; a missing value leaves the route
  /// unmatched rather than guessing.
  String fillTemplate(String template) =>
      template.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) => Uri.encodeComponent('${lookup(m[1]!) ?? ''}'));

  void act(BuildContext context, ActionSpec? action) {
    if (action != null) run(context, action, this);
  }

  @override
  bool updateShouldNotify(BrickScope old) =>
      old.values != values || old.params != params || old.item != item || old.index != index || old.fill != fill;
}
