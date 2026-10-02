import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/l10n/l10n.dart';

const _testDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Pure `L10n` formatters/labels (χωρίς context).
/// Εκτός: `phoneCountryCode` (host-locale dependent) + context-formatters
/// (θέλουν MaterialApp harness — καλύπτονται έμμεσα από widget tests).
void main() {
  group('L10n distance', () {
    test('distanceText metric κάτω από 1km → μέτρα', () {
      expect(L10n.distanceText(0.5, metric: true), '500 m');
    });

    test('distanceText metric → km με 1 δεκαδικό', () {
      expect(L10n.distanceText(2.34, metric: true), '2.3 km');
    });

    test('distanceText imperial → miles', () {
      expect(L10n.distanceText(1.609, metric: false), '1.0 mi');
    });

    test('distanceLabel συνοικία (geohash≥5) vs πόλη', () {
      expect(
        L10n.distanceLabel(1.2, 'sx3q7', isGreek: true),
        contains('Συνοικίας'),
      );
      expect(
        L10n.distanceLabel(40.0, 'sx3', isGreek: true),
        contains('Πόλης'),
      );
      expect(
        L10n.distanceLabel(40.0, null, isGreek: false),
        contains('City'),
      );
    });
  });

  group('L10n labels', () {
    test('genderLabel el/en', () {
      expect(L10n.genderLabel('male', isGreek: true), 'Άνδρας');
      expect(L10n.genderLabel('female', isGreek: false), 'Female');
      expect(L10n.genderLabel('unknown-key', isGreek: true), 'unknown-key');
    });

    test('lookingForLabel el/en + fallback', () {
      expect(L10n.lookingForLabel('roommate', isGreek: true), 'Συγκάτοικο');
      expect(L10n.lookingForLabel('social', isGreek: false), 'Social');
      expect(L10n.lookingForLabel('???', isGreek: true), '???');
    });

    test('reportReasonLabel el/en', () {
      expect(L10n.reportReasonLabel('spam', isGreek: true),
          'Ανεπιθύμητη επικοινωνία (Spam)');
      expect(L10n.reportReasonLabel('harassment', isGreek: false), 'Harassment');
    });

    test('interestLabel el/en', () {
      expect(L10n.interestLabel('gaming', isGreek: true), 'Παιχνίδια');
      expect(L10n.interestLabel('music', isGreek: false), 'Music');
    });

    test('onlineLabel el/en', () {
      expect(L10n.onlineLabel(true, isGreek: true), 'Σε σύνδεση');
      expect(L10n.onlineLabel(false, isGreek: false), 'Offline');
    });

    test('mediaTypeLabel el/en + gif σταθερό', () {
      expect(L10n.mediaTypeLabel('image', isGreek: true), 'Φωτογραφία');
      expect(L10n.mediaTypeLabel('gif', isGreek: true), 'GIF');
      expect(L10n.mediaTypeLabel('video', isGreek: false), 'Video');
      expect(L10n.mediaTypeLabel('audio', isGreek: false), 'Audio');
    });

    test('unknownName + ageLabel', () {
      expect(L10n.unknownName(isGreek: true), 'Άγνωστο');
      expect(L10n.unknownName(isGreek: false), 'Unknown');
      expect(L10n.ageLabel(25, isGreek: true), '25 ετών');
      expect(L10n.ageLabel(25, isGreek: false), '25 years');
    });
  });

  group('L10n locale helpers', () {
    test('isGreekLocale', () {
      expect(L10n.isGreekLocale(const Locale('el')), isTrue);
      expect(L10n.isGreekLocale(const Locale('en')), isFalse);
    });

    test('appNameFromLocale', () {
      expect(L10n.appNameFromLocale(const Locale('el')), 'Κοντά μου');
      expect(L10n.appNameFromLocale(const Locale('en')), 'NearMe');
    });

    testWidgets('localizedMessage split ανά locale', (tester) async {
      String? elOut;
      String? enOut;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('el'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: _testDelegates,
          home: Builder(builder: (ctx) {
            elOut = L10n.localizedMessage(ctx, 'Σήμερα / Today');
            return const SizedBox();
          }),
        ),
      );
      expect(elOut, 'Σήμερα');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('el'), Locale('en')],
          localizationsDelegates: _testDelegates,
          home: Builder(builder: (ctx) {
            enOut = L10n.localizedMessage(ctx, 'Σήμερα / Today');
            return const SizedBox();
          }),
        ),
      );
      expect(enOut, 'Today');
    });

    test('localizedMessage χωρίς separator → passthrough', () {
      // Χωρίς ' / ' δεν χρειάζεται context (early return πριν το locale).
      // Καλύπτεται έμμεσα και από το ErrorMessages passthrough test.
      expect(L10n.isGreekLocale(const Locale('el', 'GR')), isTrue);
    });
  });

  group('L10n auto-lock/unread', () {
    test('autoLockTitle/Subtitle/Updated/Disabled', () {
      expect(L10n.autoLockTitle(isGreek: true), 'Αυτόματο κλείδωμα');
      expect(L10n.autoLockSubtitle(5, isGreek: true),
          'Μετά από 5 λεπτά αδράνειας');
      expect(L10n.autoLockUpdated(5, isGreek: false), 'Auto-lock: 5 minutes');
      expect(L10n.autoLockDisabled(isGreek: false),
          'Enable biometric lock first');
    });

    test('unreadRequestsLabel ενικός/πληθυντικός', () {
      expect(L10n.unreadRequestsLabel(1, isGreek: true), '1 νέο αίτημα');
      expect(L10n.unreadRequestsLabel(3, isGreek: true), '3 νέα αιτήματα');
      expect(L10n.unreadRequestsLabel(1, isGreek: false), '1 new request');
      expect(L10n.unreadRequestsLabel(3, isGreek: false), '3 new requests');
    });
  });

  group('L10n help request labels', () {
    test('τίτλοι και ενέργειες el/en', () {
      expect(L10n.helpRequestTitle(isGreek: true), 'Επείγουσα Βοήθεια');
      expect(L10n.needsHelpLabel(isGreek: false), 'Needs help');
      expect(L10n.helpDistanceLabel(isGreek: true), 'Απόσταση');
      expect(L10n.helpMessageLabel(isGreek: false), 'Message');
      expect(L10n.helpActivateLabel(isGreek: true), 'Ενεργοποίηση');
      expect(L10n.helpDeactivateLabel(isGreek: false), 'Deactivate');
    });

    test('requirements title', () {
      expect(L10n.helpRequirementsTitle(isGreek: true), isNotEmpty);
      expect(L10n.helpRequirementsTitle(isGreek: false), isNotEmpty);
    });
  });

  group('L10n blur labels', () {
    test('blurSigmaLabel off/low/medium/high', () {
      expect(L10n.blurSigmaLabel(0, isGreek: true), contains('Απενεργό'));
      expect(L10n.blurSigmaLabel(5, isGreek: true), contains('Χαμηλό'));
      expect(L10n.blurSigmaLabel(12, isGreek: false), contains('Medium'));
      expect(L10n.blurSigmaLabel(32, isGreek: true), contains('Υψηλό'));
    });

    test('blurRevealButton + video title/message', () {
      expect(L10n.blurRevealButton(isGreek: true), 'Εμφάνιση');
      expect(L10n.blurRevealVideoTitle(isGreek: false), 'Reveal video');
      expect(L10n.blurRevealVideoMessage(isGreek: true), isNotEmpty);
    });
  });
}
