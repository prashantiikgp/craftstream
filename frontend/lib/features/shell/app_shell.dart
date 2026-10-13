/// The app frame: wordmark, Buy/Sell switch (stands in for login) and navigation. Phones and portrait
/// tablets get a bottom bar; landscape tablets and desktop get a rail (layout.yml decides).
/// The role comes from the route: /studio/* is the artisan side, everything else the buyer side.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../shared/widgets/ds.dart';
import 'shell_controller.dart';
import 'widgets/role_switch.dart';
import 'widgets/wordmark.dart';

class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final role = roleForLocation(location);
    final destinations = destinationsFor(role);
    final selected = selectedDestination(destinations, location);
    final t = context.tokens;

    return LayoutBuilder(builder: (context, box) {
      final rail = config.layout.usesRail(box.maxWidth);
      final appBar = AppBar(
        titleSpacing: rail ? t.space.xl : t.space.lg,
        title: Wordmark(compact: !rail),
        actions: [
          RoleSwitch(role: role, onChanged: (r) => context.go(destinationsFor(r).first.path)),
          if (config.env.devTools)
            IconButton(
              tooltip: context.s('shell.design_system'),
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => context.go('/catalog'),
            ),
          SizedBox(width: t.space.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.hairSoft),
        ),
      );
      void go(int i) => context.go(destinations[i].path);
      if (rail) {
        return Scaffold(
          appBar: appBar,
          body: Row(children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(context.s(d.labelKey)),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: t.hairSoft),
            Expanded(child: child),
          ]),
        );
      }
      return Scaffold(
        appBar: appBar,
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: go,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon, color: t.brandInk),
                label: context.s(d.labelKey),
              ),
          ],
        ),
      );
    });
  }
}
