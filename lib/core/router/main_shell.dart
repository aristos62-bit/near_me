import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/l10n.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Row(
        children: [
          if (isWide) _navRail(context),
          if (isWide) const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: isWide ? null : _navBar(context),
    );
  }

  Widget _navRail(BuildContext context) {
    final greek = L10n.isGreek(context);
    return NavigationRail(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: true),
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
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: true),
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
