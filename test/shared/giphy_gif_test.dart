import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/utils/giphy_service.dart';

/// Pure `GiphyGif.fromJson` (ποτέ δεν πετάει — εσωτερικό try/catch).
/// Τα network paths (search/trending/downloadBytes με έγκυρο URL) εκτός —
/// θέλουν δίκτυο/key.
void main() {
  Map<String, dynamic> gifJson({
    String id = 'abc',
    String? original,
    String? fixed,
    String? w,
    String? h,
  }) =>
      {
        'id': id,
        'images': {
          'original': {'url': original},
          'fixed_width': {'url': fixed, 'width': w, 'height': h},
        },
      };

  group('GiphyGif.fromJson', () {
    test('πλήρες json → όλα τα πεδία', () {
      final g = GiphyGif.fromJson(gifJson(
        original: 'https://o.gif',
        fixed: 'https://p.gif',
        w: '200',
        h: '100',
      ));
      expect(g.id, 'abc');
      expect(g.url, 'https://o.gif');
      expect(g.previewUrl, 'https://p.gif');
      expect(g.width, 200);
      expect(g.height, 100);
    });

    test('λείπουν images → κενά με id', () {
      final g = GiphyGif.fromJson({'id': 'x'});
      expect(g.id, 'x');
      expect(g.url, isEmpty);
      expect(g.previewUrl, isEmpty);
      expect(g.width, 0);
    });

    test('μη-αριθμητικές διαστάσεις → 0', () {
      final g = GiphyGif.fromJson(gifJson(
        original: 'https://o.gif',
        fixed: 'https://p.gif',
        w: 'wide',
        h: null,
      ));
      expect(g.width, 0);
      expect(g.height, 0);
    });

    test('κατεστραμμένο json → empty fallback, όχι throw', () {
      final g = GiphyGif.fromJson({
        'id': 42,
        'images': 'όχι-map',
      });
      expect(g.id, '');
      expect(g.url, '');
    });

    test('κενό map → empty', () {
      final g = GiphyGif.fromJson({});
      expect(g.id, '');
      expect(g.previewUrl, '');
    });
  });

  group('GiphyService.downloadBytes χωρίς δίκτυο', () {
    test('άκυρο URL → null πριν το HTTP', () async {
      expect(await GiphyService.downloadBytes('όχι-url'), isNull);
      expect(await GiphyService.downloadBytes(''), isNull);
      expect(await GiphyService.downloadBytes('ftp://x/y'), isNull);
    });

    test('χωρίς API key → search/trending πετάνε network AppException', () async {
      // GIPHY_API_KEY κενό στα tests (fromEnvironment) → deterministικό throw.
      await expectLater(GiphyService.search('cats'),
          throwsA(isA<Exception>()));
      await expectLater(
          GiphyService.trending(), throwsA(isA<Exception>()));
    });
  });
}
