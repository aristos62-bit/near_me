import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/repositories/search_repository.dart';

/// Pure freezed models `SearchFilters`/`SearchCursor`/`SearchResult`.
void main() {
  group('SearchFilters', () {
    test('defaults: limit 20, όλα τα άλλα null', () {
      const f = SearchFilters();
      expect(f.limit, 20);
      expect(f.city, isNull);
      expect(f.radiusKm, isNull);
      expect(f.minAge, isNull);
      expect(f.interests, isNull);
    });

    test('copyWith αλλάζει μόνο τα δοσμένα', () {
      const f = SearchFilters(city: 'Athens', limit: 20);
      final g = f.copyWith(limit: 50);
      expect(g.city, 'Athens');
      expect(g.limit, 50);
    });

    test('equality ίδιο περιεχόμενο → equal', () {
      const a = SearchFilters(city: 'Athens', minAge: 20, maxAge: 30);
      const b = SearchFilters(city: 'Athens', minAge: 20, maxAge: 30);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('πλήρες φίλτρο κρατάει τιμές', () {
      const f = SearchFilters(
        city: 'Athens',
        country: 'Greece',
        radiusKm: 10.0,
        gender: 'female',
        interests: ['music'],
        lookingFor: 'friendship',
        allowVideoCall: true,
        allowDirectChat: false,
        isOnlineNow: true,
      );
      expect(f.country, 'Greece');
      expect(f.interests, ['music']);
      expect(f.allowVideoCall, isTrue);
      expect(f.isOnlineNow, isTrue);
    });
  });

  group('SearchCursor/SearchResult', () {
    test('cursor κρατάει docId + sortValue', () {
      final c = SearchCursor('doc1', 'sx3q7');
      expect(c.docId, 'doc1');
      expect(c.sortValue, 'sx3q7');
    });

    test('result κρατάει results/hasMore/cursor', () {
      final r = SearchResult(const [], true, SearchCursor('d', null));
      expect(r.results, isEmpty);
      expect(r.hasMore, isTrue);
      expect(r.cursor?.docId, 'd');
    });
  });
}
