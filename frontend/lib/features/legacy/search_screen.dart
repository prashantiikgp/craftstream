// Legacy first slice (search + play), kept working until the F4 screens replace it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../data/api_provider.dart';
import '../../data/generated/models.dart';
import 'player_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  late Future<ProductPage> _results = ref.read(apiClientProvider).listProducts();

  void _search() => setState(() {
        final q = _query.text.trim();
        _results = ref.read(apiClientProvider).listProducts(q: q.isEmpty ? null : q);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('CraftStream'), actions: [
          if (ref.watch(appConfigProvider).env.devTools)
            IconButton(
              tooltip: 'Design system',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => context.go('/catalog'),
            ),
        ]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(
                hintText: 'Search handmade products',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: FutureBuilder<ProductPage>(
              future: _results,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!.items;
                if (items.isEmpty) return const Center(child: Text('No products yet'));
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return ListTile(
                      title: Text(p.title),
                      subtitle: Text('${p.artisanName} · ${p.tags.join(', ')}'),
                      trailing: Text('${p.currency} ${p.price.toStringAsFixed(0)}'),
                      onTap: () async {
                        // Search results are summaries; fetch the full product (with its HLS URL) to play it.
                        final product = await ref.read(apiClientProvider).getProduct(p.id);
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PlayerScreen(product: product)),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}
