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

  /// Requests GPS permission and returns current position if granted.
  /// Returns [LocationResult] with lat/lng, or isFromGps=false if denied.
  static Future<LocationResult> getCurrentLocation() async {
    DebugConfig.log(DebugConfig.gpsPermissions, 'getCurrentLocation: start');

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

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        DebugConfig.log(DebugConfig.gpsLocation,
            'Last known: ${last.latitude}, ${last.longitude} (±${last.accuracy}m)');
        return LocationResult(
          latitude: last.latitude,
          longitude: last.longitude,
          isFromGps: true,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 12));

      DebugConfig.log(DebugConfig.gpsLocation,
          'Position: ${position.latitude}, ${position.longitude} (±${position.accuracy}m)');
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        isFromGps: true,
      );
    } on TimeoutException {
      DebugConfig.warn('getCurrentLocation: GPS timeout');
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
