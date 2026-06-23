import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/debug/debug_config.dart';

enum LocationFailure {
  none,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  error,
}

class LocationResult {
  final double? latitude;
  final double? longitude;
  final bool isFromGps;
  final LocationFailure failure;

  const LocationResult({
    this.latitude,
    this.longitude,
    required this.isFromGps,
    this.failure = LocationFailure.none,
  });
}

class LocationService {
  LocationService._();

  /// Session cache — avoids repeated GPS within short time.
  static LocationResult? _sessionLocation;
  static DateTime? _sessionTimestamp;
  static const _sessionCacheDuration = Duration(minutes: 5);

  /// Requests GPS permission and returns current position if granted.
  /// [forceRefresh] = true (default): always attempts live GPS.
  /// [forceRefresh] = false: returns session cache if < 5min old (faster, no GPS).
  static Future<LocationResult> getCurrentLocation({bool forceRefresh = true}) async {
    DebugConfig.log(DebugConfig.gpsPermissions, 'getCurrentLocation: start');

    // Session cache hit (forceRefresh = false AND cache is fresh)
    if (!forceRefresh && _sessionLocation != null && _sessionTimestamp != null) {
      final age = DateTime.now().difference(_sessionTimestamp!);
      if (age < _sessionCacheDuration) {
        DebugConfig.log(DebugConfig.gpsLocation,
            'Session cache: ${_sessionLocation!.latitude}, ${_sessionLocation!.longitude} age=${age.inMinutes}min');
        return _sessionLocation!;
      }
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        DebugConfig.log(DebugConfig.gpsPermissions, 'Location services disabled');
        return const LocationResult(
          isFromGps: false,
          failure: LocationFailure.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        DebugConfig.log(DebugConfig.gpsPermissions, 'Permission denied');
        return const LocationResult(
          isFromGps: false,
          failure: LocationFailure.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        DebugConfig.log(DebugConfig.gpsPermissions, 'Permission denied forever');
        return const LocationResult(
          isFromGps: false,
          failure: LocationFailure.permissionDeniedForever,
        );
      }

      // 1. Try live GPS first
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        ).timeout(const Duration(seconds: 12));

        DebugConfig.log(DebugConfig.gpsLocation,
            'Position: ${position.latitude}, ${position.longitude} (±${position.accuracy}m)');
        final result = LocationResult(
          latitude: position.latitude,
          longitude: position.longitude,
          isFromGps: true,
        );
        _sessionLocation = result;
        _sessionTimestamp = DateTime.now();
        return result;
      } on TimeoutException {
        DebugConfig.warn('getCurrentLocation: GPS timeout — falling back to last known');
      } catch (e) {
        DebugConfig.warn('getCurrentLocation: GPS error — falling back to last known', data: e);
      }

      // 2. Fallback to last known position
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        DebugConfig.log(DebugConfig.gpsLocation,
            'Fallback (last known): ${last.latitude}, ${last.longitude} (±${last.accuracy}m)');
        final result = LocationResult(
          latitude: last.latitude,
          longitude: last.longitude,
          isFromGps: true,
        );
        _sessionLocation = result;
        _sessionTimestamp = DateTime.now();
        return result;
      }

      // 3. No GPS and no cache — failure
      DebugConfig.warn('getCurrentLocation: no GPS fix and no last known');
      return const LocationResult(
        isFromGps: false,
        failure: LocationFailure.timeout,
      );
    } catch (e, s) {
      DebugConfig.error('getCurrentLocation failed', data: e, exception: s);
      return const LocationResult(
        isFromGps: false,
        failure: LocationFailure.error,
      );
    }
  }

  /// Reverse geocode lat/lng to city/country.
  /// Returns [LocationName] with locality and country, or null on failure.
  static Future<LocationName?> reverseGeocode(double lat, double lng) async {
    DebugConfig.log(DebugConfig.gpsGeoHash, 'reverseGeocode: ($lat, $lng)');
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        DebugConfig.warn('reverseGeocode: no placemarks found');
        return null;
      }
      final p = placemarks.first;
      final name = LocationName(
        city: p.locality?.isNotEmpty == true ? p.locality : p.subAdministrativeArea,
        country: p.country,
      );
      DebugConfig.log(DebugConfig.gpsGeoHash,
          'reverseGeocode: city=${name.city}, country=${name.country}');
      return name;
    } catch (e, s) {
      DebugConfig.error('reverseGeocode failed', data: e, exception: s);
      return null;
    }
  }
}

class LocationName {
  final String? city;
  final String? country;
  const LocationName({this.city, this.country});
}
