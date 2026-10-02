import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/models/public_profile.dart';
import 'package:near_me/shared/utils/help_request_config.dart';

/// Pure `HelpRequestConfig` — TTL, radii, eligibility (sos.md §5.2).
void main() {
  PublicProfile pub({
    bool direct = false,
    bool video = false,
    String? email,
    String? phone,
  }) =>
      PublicProfile(
        uid: 'u1',
        allowDirectChat: direct,
        allowVideoCall: video,
        email: email,
        phone: phone,
      );

  group('HelpRequestConfig constants', () {
    test('ttl 60 λεπτά + default radius 10 + max message 80', () {
      expect(HelpRequestConfig.ttl, const Duration(minutes: 60));
      expect(HelpRequestConfig.defaultRadiusKm, 10.0);
      expect(HelpRequestConfig.maxMessageLength, 80);
      expect(HelpRequestConfig.radiusOptions, containsAll([5, 10, 25, 50]));
    });
  });

  group('HelpRequestConfig.canRequestHelp', () {
    test('όλα true → true', () {
      expect(
        HelpRequestConfig.canRequestHelp(
          canComm: true,
          isPublished: true,
          hasGps: true,
          hasChannel: true,
          hasVisibleLocation: true,
        ),
        isTrue,
      );
    });

    test('κάθε missing → false', () {
      const base = {
        'canComm': true,
        'isPublished': true,
        'hasGps': true,
        'hasChannel': true,
        'hasVisibleLocation': true,
      };
      for (final key in base.keys) {
        final args = Map<String, bool>.of(base)..[key] = false;
        expect(
          HelpRequestConfig.canRequestHelp(
            canComm: args['canComm']!,
            isPublished: args['isPublished']!,
            hasGps: args['hasGps']!,
            hasChannel: args['hasChannel']!,
            hasVisibleLocation: args['hasVisibleLocation']!,
          ),
          isFalse,
          reason: key,
        );
      }
    });
  });

  group('HelpRequestConfig.missingRequirements', () {
    test('όλα ok → κενή λίστα', () {
      expect(
        HelpRequestConfig.missingRequirements(
          canComm: true,
          isPublished: true,
          hasGps: true,
          hasChannel: true,
          hasVisibleLocation: true,
        ),
        isEmpty,
      );
    });

    test('επιστρέφει keys verify/publish/gps/channel/visibleLocation', () {
      expect(
        HelpRequestConfig.missingRequirements(
          canComm: false,
          isPublished: false,
          hasGps: false,
          hasChannel: false,
          hasVisibleLocation: false,
        ),
        ['verify', 'publish', 'gps', 'channel', 'visibleLocation'],
      );
    });
  });

  group('HelpRequestConfig.hasChannel', () {
    test('null → false', () {
      expect(HelpRequestConfig.hasChannel(null), isFalse);
    });

    test('διαβάζει το δημοσιευμένο προφίλ, όχι local toggles', () {
      expect(HelpRequestConfig.hasChannel(pub(direct: true)), isTrue);
      expect(HelpRequestConfig.hasChannel(pub(video: true)), isTrue);
      expect(HelpRequestConfig.hasChannel(pub(email: 'a@b.gr')), isTrue);
      expect(HelpRequestConfig.hasChannel(pub(phone: '+301')), isTrue);
      expect(HelpRequestConfig.hasChannel(pub()), isFalse);
    });
  });

  group('HelpRequestConfig ttl helpers', () {
    test('isActiveWithinTtl: null/inactive/null-updated → false', () {
      final now = DateTime.now();
      expect(HelpRequestConfig.isActiveWithinTtl(null, now), isFalse);
      expect(
        HelpRequestConfig.isActiveWithinTtl(
            const HelpRequest(active: false), now),
        isFalse,
      );
      expect(
        HelpRequestConfig.isActiveWithinTtl(
            const HelpRequest(active: true), now),
        isFalse,
      );
    });

    test('isActiveWithinTtl: φρέσκο true, παλιό false', () {
      final now = DateTime.now();
      expect(
        HelpRequestConfig.isActiveWithinTtl(
          HelpRequest(
              active: true, updatedAt: now.subtract(const Duration(minutes: 5))),
          now,
        ),
        isTrue,
      );
      expect(
        HelpRequestConfig.isActiveWithinTtl(
          HelpRequest(
              active: true, updatedAt: now.subtract(const Duration(hours: 2))),
          now,
        ),
        isFalse,
      );
    });

    test('isUrgentForDistance: null απόσταση/εκτός ακτίνας → false', () {
      final now = DateTime.now();
      final h = HelpRequest(
          active: true,
          radiusKm: 10,
          updatedAt: now.subtract(const Duration(minutes: 5)));
      expect(HelpRequestConfig.isUrgentForDistance(h, null, now), isFalse);
      expect(HelpRequestConfig.isUrgentForDistance(h, 50.0, now), isFalse);
      expect(HelpRequestConfig.isUrgentForDistance(h, 3.0, now), isTrue);
    });
  });
}
