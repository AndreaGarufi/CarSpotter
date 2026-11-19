import 'dart:async';

import 'package:car_spotter/controllers/spot_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _TestGeolocator extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission permissionAfterRequest = LocationPermission.whileInUse;
  Object? positionError;
  int permissionRequests = 0;
  LocationSettings? requestedSettings;

  final position = Position(
    latitude: 37.0755,
    longitude: 15.2866,
    timestamp: DateTime.utc(2026),
    accuracy: 12,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = permissionAfterRequest;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    requestedSettings = locationSettings;
    if (positionError case final error?) throw error;
    return position;
  }
}

void main() {
  late _TestGeolocator geolocator;

  setUp(() {
    final original = GeolocatorPlatform.instance;
    geolocator = _TestGeolocator();
    GeolocatorPlatform.instance = geolocator;
    addTearDown(() => GeolocatorPlatform.instance = original);
  });

  test('Acquisisce la posizione dopo aver attivato il GPS', () async {
    geolocator.enabled = false;
    await expectLater(
      SpotLocationService.getCurrentPosition(),
      throwsA(SpotLocationFailure.serviceDisabled),
    );
    expect(geolocator.permissionRequests, 0);
    expect(geolocator.requestedSettings, isNull);

    geolocator.enabled = true;
    expect(await SpotLocationService.getCurrentPosition(), geolocator.position);
    expect(geolocator.permissionRequests, 1);
    expect(geolocator.requestedSettings?.accuracy, LocationAccuracy.high);
    expect(geolocator.requestedSettings?.timeLimit, const Duration(seconds: 30));
  });

  test('Distingue il rifiuto del permesso dal rifiuto permanente', () async {
    geolocator.permissionAfterRequest = LocationPermission.denied;
    await expectLater(
      SpotLocationService.getCurrentPosition(),
      throwsA(SpotLocationFailure.permissionDenied),
    );

    geolocator.permissionAfterRequest = LocationPermission.deniedForever;
    await expectLater(
      SpotLocationService.getCurrentPosition(),
      throwsA(SpotLocationFailure.permissionDeniedForever),
    );
    expect(geolocator.requestedSettings, isNull);
  });

  test('Distingue la scadenza e consente un nuovo tentativo', () async {
    geolocator.permission = LocationPermission.whileInUse;
    geolocator.positionError = TimeoutException('GPS');
    await expectLater(
      SpotLocationService.getCurrentPosition(),
      throwsA(SpotLocationFailure.timedOut),
    );
    geolocator.positionError = null;
    expect(await SpotLocationService.getCurrentPosition(), geolocator.position);
    expect(geolocator.permissionRequests, 0);
  });
}
