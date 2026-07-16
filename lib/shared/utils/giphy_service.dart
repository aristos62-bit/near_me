import 'dart:convert';
import 'dart:io';
import '../../core/debug/debug_config.dart';
import '../../core/utils/app_exception.dart';

class GiphyGif {
  final String id;
  final String url;
  final String previewUrl;
  final int width;
  final int height;

  const GiphyGif({
    required this.id,
    required this.url,
    required this.previewUrl,
    this.width = 0,
    this.height = 0,
  });

  factory GiphyGif.fromJson(Map<String, dynamic> json) {
    try {
      final images = json['images'] as Map<String, dynamic>? ?? {};
      final original = images['original'] as Map<String, dynamic>?;
      final fixedWidth = images['fixed_width'] as Map<String, dynamic>?;
      return GiphyGif(
        id: json['id'] as String? ?? '',
        url: original?['url'] as String? ?? '',
        previewUrl: fixedWidth?['url'] as String? ?? '',
        width: int.tryParse(fixedWidth?['width'] as String? ?? '') ?? 0,
        height: int.tryParse(fixedWidth?['height'] as String? ?? '') ?? 0,
      );
    } catch (e) {
      DebugConfig.warn('GiphyGif.fromJson: parse error', data: e);
      return GiphyGif(id: '', url: '', previewUrl: '');
    }
  }
}

class GiphyService {
  GiphyService._();

  static const _apiKey = String.fromEnvironment('GIPHY_API_KEY');

  static Future<List<GiphyGif>> search(String query, {int limit = 20}) async {
    if (_apiKey.isEmpty) {
      DebugConfig.error('GiphyService: GIPHY_API_KEY not set');
      throw AppException.network('giphy_search', 'API key missing');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      DebugConfig.log(DebugConfig.repositoryCall,
          'GiphyService.search: q=$query limit=$limit');

      final uri = Uri.https('api.giphy.com', '/v1/gifs/search', {
        'api_key': _apiKey,
        'q': query,
        'limit': limit.toString(),
        'rating': 'g',
        'lang': 'en',
      });

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'NearMe/1.0');
      final response = await request.close();

      if (response.statusCode != 200) {
        DebugConfig.warn('GiphyService.search: HTTP ${response.statusCode}');
        throw AppException.network('giphy_search',
            'GIPHY API error: ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final results = json['data'] as List? ?? [];

      return results
          .map((r) => GiphyGif.fromJson(r as Map<String, dynamic>))
          .where((g) => g.url.isNotEmpty && g.previewUrl.isNotEmpty)
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.error('GiphyService.search failed', data: e);
      throw AppException.network('giphy_search', e);
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<GiphyGif>> trending({int limit = 20}) async {
    if (_apiKey.isEmpty) {
      DebugConfig.error('GiphyService: GIPHY_API_KEY not set');
      throw AppException.network('giphy_trending', 'API key missing');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      DebugConfig.log(DebugConfig.repositoryCall,
          'GiphyService.trending: limit=$limit');

      final uri = Uri.https('api.giphy.com', '/v1/gifs/trending', {
        'api_key': _apiKey,
        'limit': limit.toString(),
        'rating': 'g',
      });

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'NearMe/1.0');
      final response = await request.close();

      if (response.statusCode != 200) {
        DebugConfig.warn('GiphyService.trending: HTTP ${response.statusCode}');
        throw AppException.network('giphy_trending',
            'GIPHY API error: ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final results = json['data'] as List? ?? [];

      return results
          .map((r) => GiphyGif.fromJson(r as Map<String, dynamic>))
          .where((g) => g.url.isNotEmpty && g.previewUrl.isNotEmpty)
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      DebugConfig.error('GiphyService.trending failed', data: e);
      throw AppException.network('giphy_trending', e);
    } finally {
      client.close(force: true);
    }
  }
}
