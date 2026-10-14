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

  /// What `{call: name}` actions run; the argument is the action's `with:` value or the brick's own value.
  final Map<String, void Function(Object? arg)> calls;
  const ScreenData(this.state, [this.values = const {}, this.calls = const {}]);
  const ScreenData.ready(this.values, [this.calls = const {}]) : state = SourceState.ready;
}

/// Truthiness for `when:` / `unless:`: null, false, 0, '' and empty lists or maps are false.
bool truthy(Object? v) => switch (v) {
      null || false => false,
      num n => n != 0,
      String s => s.isNotEmpty,
      Iterable i => i.isNotEmpty,
      Map m => m.isNotEmpty,
      _ => true,
    };

class BrickScope extends InheritedWidget {
  final Map<String, Object?> values;
  final Map<String, String> params;
  final Object? item;

  /// Position of [item] in its list (the newest order is 0).
  final int index;

  /// True when the brick is given a share of the screen height (`fill: true` screens): doors then share it.
  final bool fill;

  /// The current size class from ui/layout.yml (for `only:`).
  final String sizeClass;
  final void Function(BuildContext context, ActionSpec action, BrickScope scope, [Object? value]) run;

  const BrickScope({
    super.key,
    required this.values,
    required this.params,
    required this.run,
    this.item,
    this.index = 0,
    this.fill = false,
    required this.sizeClass,
    required super.child,
  });

  static BrickScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrickScope>() ??
      (throw StateError('a brick was built outside a ScreenHost'));

  /// The same scope with [item] as the current list entry (for `list` children).
  BrickScope withItem(Object? item, int index, Widget child) =>
      BrickScope(
          values: values, params: params, run: run, item: item, index: index, fill: fill, sizeClass: sizeClass, child: child);

  /// The same scope, telling bricks whether they have a share of the screen height.
  BrickScope withFill(bool fill, Widget child) => BrickScope(
      values: values, params: params, run: run, item: item, index: index, fill: fill, sizeClass: sizeClass, child: child);

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

  /// Runs [action]. [value] is what the brick itself produced (the search text), used by `{call: name}` when the
  /// action has no `with:`.
  void act(BuildContext context, ActionSpec? action, [Object? value]) {
    if (action != null) run(context, action, this, value);
  }

  /// Whether a brick with these `when:` / `unless:` paths shows now.
  bool shows(BrickNode n) =>
      (n.only == null || n.only!.contains(sizeClass)) &&
      (n.when == null || truthy(lookup(n.when!))) &&
      (n.unless == null || !truthy(lookup(n.unless!)));

  @override
  bool updateShouldNotify(BrickScope old) =>
      old.values != values ||
      old.params != params ||
      old.item != item ||
      old.index != index ||
      old.fill != fill ||
      old.sizeClass != sizeClass;
}
