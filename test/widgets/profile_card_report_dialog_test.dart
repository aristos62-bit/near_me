import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/discovery/providers/status_provider.dart';
import 'package:near_me/features/settings/providers/app_settings_provider.dart';
import 'package:near_me/shared/models/public_profile.dart';
import 'package:near_me/shared/widgets/profile_card.dart';
import 'package:near_me/shared/widgets/report_user_dialog.dart';

class _MockAppSettingsNotifier extends AppSettingsNotifier {
  _MockAppSettingsNotifier(this.settings);
  final AppSettingsTableData settings;

  @override
  AsyncValue<AppSettingsTableData> build() => AsyncValue.data(settings);
}

AppSettingsTableData _settings({required bool blurExplicitEnabled, double blurSigma = 12.0}) {
  return AppSettingsTableData(
    id: 0,
    locale: 'el',
    themeMode: 'system',
    notificationsEnabled: true,
    biometricLockEnabled: false,
    screenshotPreventionEnabled: false,
    crashReportsEnabled: false,
    blurExplicitEnabled: blurExplicitEnabled,
    blurSigma: blurSigma,
    autoLockMinutes: 5,
    searchRadiusKm: 10.0,
    updatedAt: DateTime(2026, 1, 1),
  );
}

Widget _harness({bool blurOn = true, bool streamOnline = true, required Widget child}) {
  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(() => _MockAppSettingsNotifier(
            _settings(blurExplicitEnabled: blurOn),
          )),
      userStatusProvider.overrideWith((ref, uid) =>
          Stream.value(UserStatus(isOnline: streamOnline))),
    ],
    child: MaterialApp(
      locale: const Locale('el'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('el'), Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 320, child: child),
        ),
      ),
    ),
  );
}

PublicProfile _profile({
  String? nickname,
  int? age,
  String? city,
  String? country,
  String? lookingFor,
  bool isOnline = false,
  bool isManualLocation = false,
  HelpRequest? helpRequest,
}) {
  return PublicProfile(
    uid: 'u1',
    nickname: nickname,
    age: age,
    city: city,
    country: country,
    lookingFor: lookingFor,
    isOnline: isOnline,
    isManualLocation: isManualLocation,
    helpRequest: helpRequest,
  );
}

void main() {
  group('ProfileCard', () {
    testWidgets('εμφανίζει nickname, city, online status', (tester) async {
      await tester.pumpWidget(_harness(
        child: ProfileCard(
          profile: _profile(nickname: 'Νίκος', city: 'Αθήνα'),
        ),
      ));
      await tester.pump();
      expect(find.text('Νίκος'), findsOneWidget);
      expect(find.text('Αθήνα'), findsOneWidget);
      // stream online=true → "Σε σύνδεση"
      expect(find.text('Σε σύνδεση'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('χωρίς nickname → Άγνωστο', (tester) async {
      await tester.pumpWidget(_harness(
        child: ProfileCard(profile: _profile()),
      ));
      await tester.pump();
      expect(find.text('Άγνωστο'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('stream offline → Εκτός σύνδεσης', (tester) async {
      await tester.pumpWidget(_harness(
        streamOnline: false,
        child: ProfileCard(profile: _profile(nickname: 'Νίκος')),
      ));
      await tester.pump();
      expect(find.text('Εκτός σύνδεσης'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('manual location → help icon', (tester) async {
      await tester.pumpWidget(_harness(
        child: ProfileCard(
          profile: _profile(nickname: 'Νίκος', city: 'Αθήνα', isManualLocation: true),
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.help), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('βασικά πεδία: age + lookingFor', (tester) async {
      await tester.pumpWidget(_harness(
        child: ProfileCard(
          profile: _profile(
            nickname: 'Νίκος',
            age: 25,
            lookingFor: 'friendship',
          ),
          distanceKm: 3.5,
        ),
      ));
      await tester.pump();
      expect(find.text('25 ετών'), findsOneWidget);
      expect(find.text('Φιλία'), findsOneWidget);
      expect(find.textContaining('Απόσταση'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('χωρίς avatar → placeholder εικονίδιο', (tester) async {
      await tester.pumpWidget(_harness(
        child: ProfileCard(
          profile: _profile(nickname: 'Νίκος'),
        ),
      ));
      await tester.pump();
      // avatarUrl null → _avatarPlaceholder
      expect(find.byIcon(Icons.person), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('onTap καλείται', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_harness(
        child: ProfileCard(
          profile: _profile(nickname: 'Νίκος'),
          onTap: () => tapped = true,
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(ProfileCard));
      await tester.pump();
      expect(tapped, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('urgent SOS → εμφανίζει banner + κόκκινο περίγραμμα',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: ProfileCard(
          profile: _profile(
            nickname: 'Νίκος',
            helpRequest: HelpRequest(
              active: true,
              updatedAt: DateTime.now(),
              radiusKm: 10,
              message: 'Χρειάζομαι βοήθεια',
            ),
          ),
          distanceKm: 5,
        ),
      ));
      await tester.pump();
      expect(find.text('Χρειάζεται βοήθεια'), findsOneWidget);
      expect(find.text('Χρειάζομαι βοήθεια'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('SOS ανενεργό (out of range) → δεν εμφανίζει banner',
        (tester) async {
      await tester.pumpWidget(_harness(
        child: ProfileCard(
          profile: _profile(
            nickname: 'Νίκος',
            helpRequest: HelpRequest(
              active: true,
              updatedAt: DateTime.now(),
              radiusKm: 10,
            ),
          ),
          distanceKm: 50,
        ),
      ));
      await tester.pump();
      expect(find.text('Χρειάζεται βοήθεια'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('showReportUserDialog', () {
    late BuildContext appContext;
    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('el'), Locale('en')],
        home: Builder(builder: (context) {
          appContext = context;
          return const Scaffold(body: SizedBox());
        }),
      ));
    }

    testWidgets('ελληνικά: εμφανίζει τίτλο, λόγους, ακύρωση', (tester) async {
      await pumpApp(tester);
      final future = showReportUserDialog(appContext, true);
      await tester.pumpAndSettle();

      expect(find.text('Αναφορά Χρήστη'), findsOneWidget);
      expect(find.text('Ακύρωση'), findsOneWidget);
      // τουλάχιστον ένας λόγος (π.χ. spam)
      expect(find.byType(RadioListTile<String>), findsWidgets);

      await tester.tap(find.text('Ακύρωση'));
      await tester.pumpAndSettle();
      expect(await future, isNull);
    });

    testWidgets('αγγλικό: τίτλος "Report User"', (tester) async {
      await pumpApp(tester);
      final future = showReportUserDialog(appContext, false);
      await tester.pumpAndSettle();

      expect(find.text('Report User'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await future, isNull);
    });

    testWidgets('επιλογή λόγου → επιστρέφει τον λόγο', (tester) async {
      await pumpApp(tester);
      final future = showReportUserDialog(appContext, true);
      await tester.pumpAndSettle();

      // Πατάμε τον πρώτο λόγο (spam) μέσω RadioListTile
      final firstTile = tester.widgetList<RadioListTile<String>>(
        find.byType(RadioListTile<String>),
      );
      final firstValue = firstTile.first.value;
      await tester.tap(find.byType(RadioListTile<String>).first);
      await tester.pumpAndSettle();
      expect(await future, firstValue);
    });
  });
}
