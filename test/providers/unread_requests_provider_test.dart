import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/requests/providers/requests_provider.dart';

/// Unit tests για το `unreadRequestsProvider` fold (template S271:
/// listen + microtask + read + close — κρατάει το autoDispose ζωντανό).
ProviderContainer _container(List<Map<String, dynamic>> rows) =>
    ProviderContainer(
      overrides: [
        incomingRequestsProvider.overrideWith((ref) => Stream.value(rows)),
      ],
    );

ProviderContainer _errorContainer() => ProviderContainer(
      overrides: [
        incomingRequestsProvider
            .overrideWith((ref) => Stream.error(Exception('boom'))),
      ],
    );

Map<String, dynamic> _req(String id,
        {String status = 'pending', bool read = false}) =>
    {
      'id': id,
      'status': status,
      if (read) 'readAt': 'seen',
    };

Future<int> _count(ProviderContainer c) async {
  final sub = c.listen(unreadRequestsProvider, (prev, next) {});
  await Future<void>.delayed(Duration.zero);
  final value = c.read(unreadRequestsProvider);
  sub.close();
  return value;
}

void main() {
  group('unreadRequestsProvider', () {
    test('pending+unread μετράνε, read/άλλα status όχι', () async {
      final c = _container([
        _req('r1'),
        _req('r2', read: true),
        _req('r3', status: 'accepted'),
        _req('r4'),
      ]);
      addTearDown(c.dispose);
      expect(await _count(c), 2);
    });

    test('κενή λίστα → 0', () async {
      final c = _container(const []);
      addTearDown(c.dispose);
      expect(await _count(c), 0);
    });

    test('όλα διαβασμένα → 0', () async {
      final c = _container([
        _req('r1', read: true),
        _req('r2', status: 'declined'),
      ]);
      addTearDown(c.dispose);
      expect(await _count(c), 0);
    });

    test('error stream → 0 (asData null)', () async {
      final c = _errorContainer();
      addTearDown(c.dispose);
      expect(await _count(c), 0);
    });
  });
}
