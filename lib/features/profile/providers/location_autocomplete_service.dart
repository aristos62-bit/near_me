import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/debug/debug_config.dart';

class LocationSuggestion {
  final String name;
  final String displayName;
  final String type;
  const LocationSuggestion({
    required this.name,
    required this.displayName,
    required this.type,
  });
}

class LocationAutocompleteService {
  LocationAutocompleteService._();

  static DateTime _lastRequestTime = DateTime(2000);

  static Future<List<LocationSuggestion>> autocomplete(String query, {int limit = 5}) async {
    if (query.trim().length < 2) return [];
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        DebugConfig.log(DebugConfig.networkLocation, 'Nominatim: no connectivity');
        return [];
      }
    } catch (_) {}

    final now = DateTime.now();
    final diff = now.difference(_lastRequestTime).inMilliseconds;
    if (diff < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - diff));
    }
    _lastRequestTime = DateTime.now();

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      DebugConfig.log(DebugConfig.networkLocation, 'Nominatim: q=$query, limit=$limit');
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': limit.toString(),
        'accept-language': 'el',
        'addressdetails': '1',
      });
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'NearMe/1.0');
      final response = await request.close();

      if (response.statusCode != 200) {
        DebugConfig.warn('Nominatim: HTTP ${response.statusCode}');
        return [];
      }

      final body = await response.transform(utf8.decoder).join();
      final List<dynamic> data = jsonDecode(body) as List<dynamic>;

      final suggestions = data.map((item) {
        final map = item as Map<String, dynamic>;
        final displayName = map['display_name'] as String? ?? '';
        final type = map['type'] as String? ?? '';
        final name = type == 'country' ? displayName : displayName.split(',').first.trim();
        return LocationSuggestion(name: name, displayName: displayName, type: type);
      }).toList();

      DebugConfig.log(DebugConfig.networkLocation, 'Nominatim: ${suggestions.length} results');
      return suggestions;
    } catch (e) {
      DebugConfig.error('Nominatim autocomplete failed', data: e);
      return [];
    } finally {
      client.close();
    }
  }
}
