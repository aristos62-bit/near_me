import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../repositories/search_repository.dart';

class SearchFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() {
    DebugConfig.log(DebugConfig.providerCreate, 'SearchFiltersNotifier built');
    return const SearchFilters();
  }

  void updateAge(int? min, int? max) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: age $min-$max');
    state = state.copyWith(minAge: min, maxAge: max);
  }

  void updateGender(String? gender) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: gender $gender');
    state = state.copyWith(gender: gender);
  }

  void updateInterests(List<String>? interests) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: interests $interests');
    state = state.copyWith(interests: interests);
  }

  void updateLookingFor(String? lookingFor) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: lookingFor $lookingFor');
    state = state.copyWith(lookingFor: lookingFor);
  }

  void updateAllowVideoCall(bool allow) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: allowVideoCall $allow');
    state = state.copyWith(allowVideoCall: allow);
  }

  void updateAllowDirectChat(bool allow) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: allowDirectChat $allow');
    state = state.copyWith(allowDirectChat: allow);
  }

  void updateOnlineOnly(bool onlineOnly) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: onlineOnly $onlineOnly');
    state = state.copyWith(isOnlineNow: onlineOnly);
  }

  void updateCity(String? city) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: city $city');
    state = state.copyWith(city: city);
  }

  void updateLocation(double lat, double lng, {double? radiusKm}) {
    DebugConfig.log(DebugConfig.providerCreate,
        'filters: location ($lat, $lng) radius=$radiusKm');
    state = state.copyWith(
      latitude: lat,
      longitude: lng,
      radiusKm: radiusKm ?? state.radiusKm,
    );
  }

  void updateRadius(double? km) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: radius $km km');
    state = state.copyWith(radiusKm: km);
  }

  void updateLimit(int limit) {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: limit $limit');
    state = state.copyWith(limit: limit);
  }

  void reset() {
    DebugConfig.log(DebugConfig.providerCreate, 'filters: reset');
    state = const SearchFilters();
  }
}

final searchFiltersProvider = NotifierProvider<SearchFiltersNotifier, SearchFilters>(
  SearchFiltersNotifier.new,
);
