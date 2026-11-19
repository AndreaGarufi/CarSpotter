import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum SpotLocationFailure implements Exception {
  serviceDisabled('Attiva la posizione del telefono e riprova.'),
  permissionDenied('Consenti a Car Spotter di accedere alla posizione.'),
  permissionDeniedForever(
    'Consenti a Car Spotter di accedere alla posizione nelle impostazioni del telefono.',
  ),
  timedOut('Posizione non rilevata in tempo. Riprova tra poco.'),
  unavailable('Impossibile rilevare la posizione. Riprova tra poco.');

  const SpotLocationFailure(this.message);

  final String message;
}

class SpotLocationService {
  static Future<Position> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw SpotLocationFailure.serviceDisabled;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw SpotLocationFailure.permissionDeniedForever;
      }
      if (permission == LocationPermission.denied) {
        throw SpotLocationFailure.permissionDenied;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } on SpotLocationFailure {
      rethrow;
    } on LocationServiceDisabledException {
      throw SpotLocationFailure.serviceDisabled;
    } on PermissionDeniedException {
      throw SpotLocationFailure.permissionDenied;
    } on TimeoutException {
      throw SpotLocationFailure.timedOut;
    } catch (error) {
      debugPrint('Acquisizione della posizione GPS: $error');
      throw SpotLocationFailure.unavailable;
    }
  }
}
