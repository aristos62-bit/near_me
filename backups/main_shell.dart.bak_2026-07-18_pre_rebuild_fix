import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../debug/debug_config.dart';
import '../l10n/l10n.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

 @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        DebugConfig.log(DebugConfig.uiRebuild, 'MainShell build: isWide=$isWide');
        return Scaffold(
          // ── FIX Πρόβλημα 2 ──
          // Το MainShell δεν έχει δικό του TextField, άρα δεν χρειάζεται να
          // αλλάζει μέγεθος όταν ανοίγει το πληκτρολόγιο σε άλλο route (π.χ.
          // Phone Verify, που είναι ΠΑΝΩ από αυτό). Χωρίς αυτό, το καθολικό
          // MediaQuery.viewInsets προκαλούσε πραγματικό, επαναλαμβανόμενο
          // resize του body του MainShell σε κάθε frame του keyboard animation,
          // που διαδιδόταν μέσα από το IndexedStack σε ΟΛΑ τα branches
          // (Discovery, Chats) που έχουν ListView με bounded height — σπατάλη
          // CPU/μπαταρίας ενώ ο χρήστης βρίσκεται σε εντελώς άλλη οθόνη.
          // Τα modals με TextField (Phone Verify κλπ.) ΔΕΝ επηρεάζονται —
          // έχουν δικό τους Scaffold με resizeToAvoidBottomInset: true (default).
          resizeToAvoidBottomInset: false,
          body: Row(
            children: [
              if (isWide) _navRail(context),
              if (isWide) const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
          bottomNavigationBar: isWide ? null : _navBar(context),
        );
      },
    );
  }

  Widget _navRail(BuildContext context) {
    final greek = L10n.isGreek(context);
    return NavigationRail(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (i) {
        DebugConfig.log(DebugConfig.uiInteraction, 'MainShell: tab=$i (rail)');
        navigationShell.goBranch(i, initialLocation: true);
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
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (i) {
        DebugConfig.log(DebugConfig.uiInteraction, 'MainShell: tab=$i (bar)');
        navigationShell.goBranch(i, initialLocation: true);
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
