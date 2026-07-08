import 'package:isar_community/isar.dart'; // <-- Modificato qui
import 'brand.dart';

part 'car_model.g.dart';

enum RarityTier { common, uncommon, rare, epic, legendary }

@collection
class CarModel {
  Id id = Isar.autoIncrement;

  final brand = IsarLink<Brand>();

  late String name;
  late int baseRarityScore;

  @enumerated
  late RarityTier rarityTier;

  late int iconScore;
  late bool isIcon;

  int? engineHp;
  int? productionRun;
  int? launchYear;
}
