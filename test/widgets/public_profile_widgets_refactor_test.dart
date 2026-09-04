import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/l10n/l10n.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/discovery/widgets/public_profile_photo_gallery.dart';
import 'package:near_me/features/discovery/widgets/public_profile_sections.dart';
import 'package:near_me/features/settings/providers/app_settings_provider.dart';
import 'package:near_me/shared/models/public_profile.dart';

class _MockAppSettingsNotifier extends AppSettingsNotifier {
  _MockAppSettingsNotifier(this.settings);
  final AppSettingsTableData settings;

  @override
  AsyncValue<AppSettingsTableData> build() => AsyncValue.data(settings);
}

AppSettingsTableData _settings({required bool blurExplicitEnabled}) {
  return AppSettingsTableData(
    id: 0,
    locale: 'el',
    themeMode: 'system',
    notificationsEnabled: true,
    biometricLockEnabled: false,
    screenshotPreventionEnabled: false,
    crashReportsEnabled: false,
    blurExplicitEnabled: blurExplicitEnabled,
    blurSigma: 12.0,
    autoLockMinutes: 5,
    searchRadiusKm: 10.0,
    updatedAt: DateTime(2026, 1, 1),
  );
}

PublicProfile _fullProfile() {
  return PublicProfile(
    uid: 'u1',
    photoUrls: ['p1.jpg', 'p2.jpg', 'p3.jpg'],
    lookingFor: 'friendship',
    interests: ['music', 'travel'],
    bio: 'Γεια, είμαι ο Νίκος',
    allowVideoCall: false,
    allowDirectChat: true,
    email: 'nikos@example.com',
    phone: '+30 6900000000',
  );
}

PublicProfile _minimalProfile() {
  return PublicProfile(uid: 'u1');
}

Widget _localized(Widget child) {
  return MaterialApp(
    locale: const Locale('el'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

class _SectionsHarness extends StatelessWidget {
  final PublicProfile profile;
  const _SectionsHarness({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        buildProfileLookingForCard(context, profile, theme, isGreek),
        buildProfileInterestsCard(context, profile, theme, isGreek),
        buildProfileBioCard(context, profile, theme, isGreek),
        buildProfileCommunicationCard(context, profile, theme, isGreek),
        buildProfileContactCard(context, profile, theme, isGreek, profile.uid),
      ],
    );
  }
}

void main() {
  testWidgets(
      'PhotoGallery εμφανίζει την καρτέλα Φωτογραφίες και τους placeholder τόνους',
      (tester) async {
    final profile = _fullProfile();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(
              () => _MockAppSettingsNotifier(_settings(blurExplicitEnabled: false))),
        ],
        child: _localized(PublicProfilePhotoGallery(profile: profile)),
      ),
    );
    await tester.pump();

    expect(find.text('Φωτογραφίες'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsNWidgets(3),
        reason: '3 placeholder εικονίδια για τις 3 φωτογραφίες (CachedNetworkImage δεν φορτώνει στα tests)');
  });

  testWidgets('Section cards εμφανίζουν όλα τα πεδία ενός πλήρους προφίλ',
      (tester) async {
    final profile = _fullProfile();
    await tester.pumpWidget(_localized(_SectionsHarness(profile: profile)));
    await tester.pump();

    // LookingFor
    expect(find.text('Ενδιαφέρεται για'), findsOneWidget);
    expect(find.text('Φιλία'), findsOneWidget);
    // Interests
    expect(find.text('Ενδιαφέροντα'), findsOneWidget);
    expect(find.text('Μουσική'), findsOneWidget);
    expect(find.text('Ταξίδια'), findsOneWidget);
    // Bio
    expect(find.text('Σχετικά'), findsOneWidget);
    expect(find.text('Γεια, είμαι ο Νίκος'), findsOneWidget);
    // Communication
    expect(find.text('Επικοινωνία'), findsOneWidget);
    expect(find.text('Ναι'), findsOneWidget);
    expect(find.text('Όχι'), findsOneWidget);
    // Contact
    expect(find.text('Στοιχεία Επικοινωνίας'), findsOneWidget);
    expect(find.textContaining('nikos@example.com'), findsOneWidget);
    expect(find.textContaining('+30 6900000000'), findsOneWidget);

    // Αφήνουμε τον timer του DebugConfig.log (contact card κάνει log) να τρέξει.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Section cards κρύβουν τις κάρτες με κενά πεδία',
      (tester) async {
    final profile = _minimalProfile();
    await tester.pumpWidget(_localized(_SectionsHarness(profile: profile)));
    await tester.pump();

    expect(find.text('Ενδιαφέρεται για'), findsNothing);
    expect(find.text('Ενδιαφέροντα'), findsNothing);
    expect(find.text('Σχετικά'), findsNothing);
    // Communication εμφανίζεται πάντα (not conditional)
    expect(find.text('Επικοινωνία'), findsOneWidget);
    // Contact καρτέλα κρύβεται (χωρίς email/phone)
    expect(find.text('Στοιχεία Επικοινωνίας'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });
}
