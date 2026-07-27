import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../debug/debug_config.dart';
import '../l10n/l10n.dart';

class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool? _cachedIsWide;
  double _lastWidth = -1;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 900;
    if (isWide != _cachedIsWide) _cachedIsWide = isWide;
    if (w != _lastWidth) {
      _lastWidth = w;
      DebugConfig.log(DebugConfig.uiRebuild,
          'MainShell build: isWide=$isWide (${w.toStringAsFixed(0)}px)');
    }
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Row(
        children: [
          if (isWide) _navRail(context),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: isWide ? null : _navBar(context),
    );
  }

  Widget _navRail(BuildContext context) {
    final greek = L10n.isGreek(context);
    return NavigationRail(
      selectedIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: (i) {
        DebugConfig.log(DebugConfig.uiInteraction, 'MainShell: tab=$i (rail)');
        widget.navigationShell.goBranch(i, initialLocation: true);
      },
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Icon(Icons.near_me, color: Theme.of(context).colorScheme.primary, size: 28),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.person_search),
          selectedIcon: const Icon(Icons.person_search),
          label: Text(greek ? 'Ανακάλυψη' : 'Discover'),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.chat_bubble_outline),
          selectedIcon: const Icon(Icons.chat_bubble),
          label: Text(greek ? 'Συνομιλίες' : 'Chats'),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: Text(greek ? 'Προφίλ' : 'Profile'),
        ),
      ],
    );
  }

  Widget _navBar(BuildContext context) {
    final greek = L10n.isGreek(context);
    return NavigationBar(
      selectedIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: (i) {
        DebugConfig.log(DebugConfig.uiInteraction, 'MainShell: tab=$i (bar)');
        widget.navigationShell.goBranch(i, initialLocation: true);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.person_search),
          label: greek ? 'Ανακάλυψη' : 'Discover',
        ),
        NavigationDestination(
          icon: const Icon(Icons.chat_bubble_outline),
          label: greek ? 'Συνομιλίες' : 'Chats',
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          label: greek ? 'Προφίλ' : 'Profile',
        ),
      ],
    );
  }
}
