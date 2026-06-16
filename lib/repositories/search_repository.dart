import 'package:freezed_annotation/freezed_annotation.dart';
import '../shared/models/public_profile.dart';

part 'search_repository.freezed.dart';

@freezed
abstract class SearchFilters with _$SearchFilters {
  const factory SearchFilters({
    String? city,
    String? country,
    String? geoHash,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int? minAge,
    int? maxAge,
    String? gender,
    List<String>? interests,
    String? lookingFor,
    bool? allowVideoCall,
    bool? allowDirectChat,
    bool? isOnlineNow,
    @Default(20) int limit,
  }) = _SearchFilters;
}

class SearchCursor {
  final String docId;
  final String? sortValue;

  SearchCursor(this.docId, this.sortValue);
}

class SearchResult {
  final List<PublicProfile> results;
  final bool hasMore;
  final SearchCursor? cursor;

  SearchResult(this.results, this.hasMore, this.cursor);
}

abstract class SearchRepository {
  Future<SearchResult> search(SearchFilters filters, {SearchCursor? cursor});
  Future<SearchResult> searchNearby(double lat, double lng, double radiusKm, {SearchCursor? cursor});
}
