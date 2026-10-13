import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../shared/widgets/ds.dart';
import '../discover_controller.dart';

/// Search box: waits filters.yml search.debounce_ms after the last keystroke; Enter searches at once.
class SearchField extends ConsumerStatefulWidget {
  const SearchField({super.key});

  @override
  ConsumerState<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<SearchField> {
  late final _text = TextEditingController(text: ref.read(discoverControllerProvider).text);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      ref.read(appConfigProvider).filters.debounce,
      () => ref.read(discoverControllerProvider.notifier).setText(value),
    );
    setState(() {}); // show or hide the clear button
  }

  void _submit(String value) {
    _debounce?.cancel();
    ref.read(discoverControllerProvider.notifier).setText(value);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the box in step when something else changes the query (Clear filters, a tag from a product).
    ref.listen(discoverControllerProvider.select((q) => q.text), (_, next) {
      if (_text.text != next) _text.text = next;
    });
    final t = context.tokens;
    return TextField(
      controller: _text,
      onChanged: _changed,
      onSubmitted: _submit,
      textInputAction: TextInputAction.search,
      style: context.type.body,
      decoration: InputDecoration(
        hintText: context.s('discover.search_hint'),
        prefixIcon: Icon(Icons.search, color: t.sub),
        suffixIcon: _text.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.s('discover.clear_search'),
                icon: Icon(Icons.close, color: t.sub),
                onPressed: () {
                  _text.clear();
                  _submit('');
                },
              ),
      ),
    );
  }
}
