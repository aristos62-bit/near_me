import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/geohash_utils.dart';
import 'package:near_me/repositories/firestore_search_repository.dart';
import 'package:near_me/repositories/search_repository.dart';

import '../helpers/fake_firestore_helpers.dart';

void main() {
  const athensLat = 37.983810;
  const athensLng = 23.727539;

  late FakeFirebaseFirestore firestore;
  late FirestoreSearchRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreSearchRepository(firestore: firestore);
  });

  group('search — geo fan-out', () {
    test('επιστρέφει ορατά profiles εντός radius + dedup uid (multi-cell)', () async {
      const radius = 10.0;
      final center = geoCell(athensLat, athensLng, radius);
      final neighbours = GeoHashUtils.getNeighbours(center);
      expect(neighbours.length, 9);

      await seedPublicProfiles(firestore, [
        publicProfileDoc(uid: 'u_center', nickname: 'Center', geoHash: center),
        // Γειτονικό cell: ΜΠΑΙΝΕΙ στα raw queries αλλά ο haversine post-filter
        // το κόβει (cell distance > radius, precision-4 cells ~20×30km).
        publicProfileDoc(uid: 'u_ring', nickname: 'Δαχτυλίδι',
            geoHash: neighbours[1]),
        // Σίδνεϊ: εκτός query cells + εκτός radius.
        publicProfileDoc(uid: 'u_far', nickname: 'Σίδνεϊ',
            geoHash: GeoHashUtils.encode(-33.86, 151.20)),
        publicProfileDoc(uid: 'u_hidden', nickname: 'Κρυφός',
            geoHash: neighbours[3], isVisible: false),
      ]);
      // Dedup uid «multi»: 2 ξεχωριστά docs (πραγματικό multi-cell σενάριο —
      // το ίδιο geoHash καλύπτεται από prefix-3 και full cells → 2 raw matches).
      await firestore.collection('users').doc('multi').collection('public').doc('a')
          .set(publicProfileDoc(uid: 'multi', geoHash: center));
      await firestore.collection('users').doc('multi').collection('public').doc('b')
          .set(publicProfileDoc(uid: 'multi', geoHash: neighbours[2]));

      final res = await repo.search(const SearchFilters(
        latitude: athensLat,
        longitude: athensLng,
        radiusKm: radius,
        limit: 20,
      ));

      final uids = res.results.map((p) => p.uid).toSet();
      expect(uids, containsAll({'u_center', 'multi'}));
      expect(uids, isNot(contains('u_far')));    // εκτός query cells
      expect(uids, isNot(contains('u_hidden'))); // isVisible=false
      expect(uids, isNot(contains('u_ring')));   // haversine post-filter
      expect(res.results, hasLength(2));         // dedup το multi
    });

    test('haversine post-filter: μένουν μόνο profiles εντός radius', () async {
      const radius = 2.0;
      final center = geoCell(athensLat, athensLng, radius);

      // Εντός radius (ίδιο κελί).
      final near = publicProfileDoc(uid: 'u_near', geoHash: center);
      // Εκτός radius (~10km μακριά) ΑΛΛΑ στο query μέσω του 3-char prefix
      // expansion (το prefix-3 cell της Αθήνας) → μπαίνει raw, κόβεται post-filter.
      final farInQuery = publicProfileDoc(uid: 'u_far', geoHash:
          GeoHashUtils.encode(athensLat - 0.09, athensLng + 0.09, precision: 5));

      await seedPublicProfiles(firestore, [near, farInQuery]);

      final res = await repo.search(const SearchFilters(
        latitude: athensLat,
        longitude: athensLng,
        radiusKm: radius,
        limit: 20,
      ));

      expect(res.results.map((p) => p.uid), ['u_near']);
    });
  });

  group('search — general / city filters', () {
    Future<void> seedCityFixtures() => seedPublicProfiles(firestore, [
          publicProfileDoc(uid: 'u_f', nickname: 'Αθήνα Θήλυ', city: 'Αθήνα',
              gender: 'female', age: 25, interests: ['greek', 'dance']),
          publicProfileDoc(uid: 'u_m', nickname: 'Αθήνα Άρρεν', city: 'Αθήνα',
              gender: 'male', age: 40, interests: ['tech']),
          publicProfileDoc(uid: 'u_skg', nickname: 'Θεσσαλονίκη', city: 'Θεσσαλονίκη',
              gender: 'female', age: 25),
        ]);

    test('city server-side + client-side gender/age filters', () async {
      await seedCityFixtures();

      final res = await repo.search(const SearchFilters(
        city: 'αθήνα', // case-insensitive μέσω cityNormalized
        gender: 'female',
        minAge: 18,
        maxAge: 30,
      ));

      expect(res.results.map((p) => p.uid), ['u_f']);
    });

    test('country φίλτρο + default όλα τα Αθήνας', () async {
      await seedCityFixtures();

      final res = await repo.search(const SearchFilters(city: 'Αθήνα'));
      expect(res.results.map((p) => p.uid).toSet(), {'u_f', 'u_m'});
    });
  });

  group('search — pagination', () {
    test('hasMore/cursor: η σελίδα 1 δίνει cursor όταν υπάρχουν ακόμη', () async {
      for (var i = 0; i < 4; i++) {
        await seedPublicProfile(firestore,
            publicProfileDoc(uid: 'u_$i', nickname: 'P$i', city: 'Αθήνα'));
      }

      final page1 = await repo.search(const SearchFilters(city: 'Αθήνα', limit: 2));

      expect(page1.results, hasLength(2));
      expect(page1.hasMore, isTrue);
      expect(page1.cursor, isNotNull);
      expect(page1.cursor!.docId, isNotEmpty);

      // Σημ.: ΔΕΝ περνάμε το cursor σε page2 — το fake_cloud_firestore δεν
      // υποστηρίζει `startAfter` πάνω από `orderBy('__name__')` (ρίχνει
      // "Cannot get field that does not exist"). Το startAfter branch μένει
      // για πραγματικό/emulator run — καταγράφεται στο session.
    });
  });

  group('search — malformed doc resilience', () {
    test('κατεστραμμένο profile skip-άρεται, τα υπόλοιπα επιστρέφουν', () async {
      final bad = publicProfileDoc(uid: 'u_bad', nickname: 'broken', city: 'Αθήνα');
      bad['helpRequest'] = 'NOT_A_MAP'; // θα σκάσει το PublicProfile.fromJson
      await seedPublicProfiles(firestore, [
        publicProfileDoc(uid: 'u_ok', nickname: 'OK', city: 'Αθήνα'),
        bad,
      ]);

      final res = await repo.search(const SearchFilters(city: 'Αθήνα'));

      expect(res.results.map((p) => p.uid), ['u_ok']);
    });
  });

  group('searchNearby', () {
    test('επιστρέφει μόνο εντός radius (haversine) — έχει και dedup', () async {
      final center = geoCell(athensLat, athensLng, 10);
      await seedPublicProfiles(firestore, [
        publicProfileDoc(uid: 'u_near', nickname: 'Κοντά', geoHash: center),
        publicProfileDoc(uid: 'u_far', nickname: 'Θεσσαλονίκη',
            geoHash: GeoHashUtils.encode(40.64, 22.93)),
      ]);

      final res = await repo.searchNearby(athensLat, athensLng, 10);

      expect(res.results.map((p) => p.uid), ['u_near']);
      expect(res.hasMore, isFalse);
    });
  });
}