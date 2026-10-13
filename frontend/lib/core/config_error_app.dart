/// Shown instead of the app when the environment or a YAML rule file is invalid.
/// Uses no design tokens on purpose: the tokens themselves may be what failed to load.
library;

import 'package:flutter/material.dart';

class ConfigErrorApp extends StatelessWidget {
  final Object error;
  const ConfigErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFF4F0),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CraftStream cannot start',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
                const SizedBox(height: 12),
                const Text('The app configuration is invalid. Fix it and rebuild:'),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText('$error', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
