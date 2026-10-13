// Thin first slice: search products and play a video. Upload and order screens come next.
import 'package:flutter/material.dart';

import 'data/generated/api_client.dart';
import 'data/generated/models.dart';
import 'screens/player_screen.dart';

const apiHost = String.fromEnvironment('API_HOST', defaultValue: 'http://localhost:8000');
final api = ApiClient(apiHost);

void main() => runApp(const CraftStreamApp());

class CraftStreamApp extends StatelessWidget {
  const CraftStreamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CraftStream',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF8B5E3C), useMaterial3: true),
        home: const SearchScreen(),
      );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  late Future<ProductPage> _results = api.listProducts();

  void _search() => setState(() {
        final q = _query.text.trim();
        _results = api.listProducts(q: q.isEmpty ? null : q);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('CraftStream')),
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
                        final product = await api.getProduct(p.id);
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
