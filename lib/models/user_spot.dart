import 'package:isar_community/isar.dart';
import 'car_model.dart';

part 'user_spot.g.dart';

@collection
class UserSpot {
  Id id = Isar.autoIncrement;

  final carModel = IsarLink<CarModel>();

  late String imagePath;
  late DateTime dateCaptured;

  double? latitude;
  double? longitude;
  String?
  locationName; // <-- AGGIUNTO: per salvare la scritta "GPS: 37.07, 15.28" o l'indirizzo

  String? customColor; // <-- Manteniamo il TUO nome esatto!
  int? year; // <-- AGGIUNTO: per l'anno di produzione (es. 1991)
  String? notes;

  bool isRacing =
      false; // <-- Tolto "late" e inizializzato a false per sicurezza
  bool isFavorite =
      false; // <-- Tolto "late" e inizializzato a false per sicurezza
}
