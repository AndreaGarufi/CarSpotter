import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/brand.dart';
import '../models/car_model.dart';
import '../models/user_spot.dart';
import 'rarity_controller.dart';

typedef HomeStats = ({
  int totalModels,
  int totalSpots,
  int uniqueModels,
  int legendarySpots,
  int iconicSpots,
  List<UserSpot> favorites,
});

class DbService {
  static const _manualIconBadgesAppliedKey = 'manualIconBadgesApplied';
  static Isar? _isar;

  static Isar get isar {
    if (_isar == null) {
      throw Exception("Database non inizializzato. Chiamare DbService.init()");
    }
    return _isar!;
  }

  // Inizializzazione all'apertura dell'app
  static Future<void> init() async {
    if (_isar != null) return;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([
      BrandSchema,
      CarModelSchema,
      UserSpotSchema,
    ], directory: dir.path);

    await _initializeCatalog();
  }

  // ==========================================
  // INIEZIONE DATI E CALCOLO ALGORITMICO PRO
  // ==========================================
  static Future<void> _initializeCatalog() async {
    try {
      final hasCatalog = await isar.brands.count() > 0;
      final prefs = await SharedPreferences.getInstance();
      if (hasCatalog && prefs.getBool(_manualIconBadgesAppliedKey) == true) {
        return;
      }

      final String response = await rootBundle.loadString(
        'assets/data/cars_database.json',
        cache: false,
      );
      final data = json.decode(response) as Map<String, dynamic>;

      if (hasCatalog) {
        await _updateStoredIconBadges(data);
        await prefs.setBool(_manualIconBadgesAppliedKey, true);
        return;
      }

      debugPrint("🌱 Avvio iniezione PRO dal file JSON...");

      await isar.writeTxn(() async {
        for (var brandName in data.keys) {
          final brandInfo = data[brandName] as Map<String, dynamic>;
          final brandScore = brandInfo["brandScore"] as int;

          final brand = Brand()..name = brandName;
          await isar.brands.put(brand);

          final models = <CarModel>[];
          for (final entry in brandInfo["models"]) {
            final model = CarModel();
            _applyCatalogEntry(model, entry, brandScore);
            models.add(model);
          }
          await isar.carModels.putAll(models);
          for (final model in models) {
            model.brand.value = brand;
            await model.brand.save();
          }
        }
      });
      await prefs.setBool(_manualIconBadgesAppliedKey, true);
      debugPrint("✅ Catalogo PRO generato con successo dai calcoli!");
    } catch (e) {
      debugPrint("❌ Errore durante la lettura o il calcolo del JSON: $e");
    }
  }

  // Restituisce true solo se occorre scrivere i dati del modello.
  static bool _applyCatalogEntry(
    CarModel model,
    Map<String, dynamic> entry,
    int brandScore,
  ) {
    final name = entry['name'] as String;
    final production = entry['productionRun'] as int;
    final horsepower = entry['horsepower'] as int;
    final year = entry['launchYear'] as int;
    final tier = RarityController.calculateRarity(
      brandScore: brandScore,
      productionRun: production,
      priceEuro: (entry['priceEuro'] as num).toDouble(),
      horsepower: horsepower,
      popCultureScore: entry['popCultureScore'] as int,
      technicalInnovation: entry['technicalInnovation'] as int,
      rarityOverride: RarityController.rarityTierFromOverride(
        entry['rarityOverride'] as String?,
      ),
    );
    final baseScore = switch (tier) {
      RarityTier.common => 30,
      RarityTier.uncommon => 50,
      RarityTier.rare => 70,
      RarityTier.epic => 85,
      RarityTier.legendary => 95,
    };
    final existing = model.id != Isar.autoIncrement;
    final isIcon = entry['isIcon'] as bool? ?? (existing && model.isIcon);
    final iconScore = isIcon ? 90 : 50;
    if (existing &&
        model.name == name &&
        model.productionRun == production &&
        model.engineHp == horsepower &&
        model.launchYear == year &&
        model.rarityTier == tier &&
        model.baseRarityScore == baseScore &&
        model.isIcon == isIcon &&
        model.iconScore == iconScore) {
      return false;
    }
    model
      ..name = name
      ..productionRun = production
      ..engineHp = horsepower
      ..launchYear = year
      ..rarityTier = tier
      ..baseRarityScore = baseScore
      ..isIcon = isIcon
      ..iconScore = iconScore;
    return true;
  }

  static Future<void> _updateStoredIconBadges(Map<String, dynamic> data) async {
    final badgesByName = <String, bool>{};
    for (final brand in data.values) {
      for (final model in brand["models"] as List<dynamic>) {
        badgesByName[model["name"] as String] = model["isIcon"] == true;
      }
    }

    await isar.writeTxn(() async {
      final updatedModels = <CarModel>[];
      for (final model in await isar.carModels.where().findAll()) {
        final isIcon = badgesByName[model.name];
        if (isIcon == null || model.isIcon == isIcon) continue;
        model
          ..isIcon = isIcon
          ..iconScore = isIcon ? 90 : 50;
        updatedModels.add(model);
      }
      await isar.carModels.putAll(updatedModels);
    });
  }

  // --- UTILITY PER RECUPERARE DATI ---
  static Future<List<UserSpot>> getAllSpots() async {
    return await isar.userSpots.where().findAll();
  }

  static Future<HomeStats> getHomeStats() async {
    final totalModels = await isar.carModels.count();
    final spots = await getAllSpots();
    final seen = <int>{};
    final favorites = <UserSpot>[];
    var iconic = 0;
    var legendary = 0;
    for (final spot in spots) {
      if (spot.isFavorite) favorites.add(spot);
      final model = spot.carModel.value;
      if (model == null) continue;
      seen.add(model.id);
      if (model.isIcon) iconic++;
      if (model.rarityTier == RarityTier.legendary) legendary++;
    }
    return (
      totalModels: totalModels,
      totalSpots: spots.length,
      uniqueModels: seen.length,
      legendarySpots: legendary,
      iconicSpots: iconic,
      favorites: favorites,
    );
  }

  static Future<List<CarModel>> getAllCarModels() async {
    return await isar.carModels.where().findAll();
  }

  static Future<List<CarModel>> getModelsForBrand(int brandId) {
    return isar.carModels.filter().brand((q) => q.idEqualTo(brandId)).findAll();
  }

  static Future<List<Brand>> getAllBrands() async {
    return await isar.brands.where().findAll();
  }

  static Future<Set<int>> getSpottedModelIds() async {
    final spots = await isar.userSpots.where().findAll();
    return spots.map((s) => s.carModel.value?.id).whereType<int>().toSet();
  }

  // --- AZIONI SUI DATI ---
  static Future<void> saveNewSpot({
    required String originalImagePath,
    required CarModel selectedModel,
    String? notes,
    bool isFavorite = false,
    bool isRacing = false,
    String? color,
    int? year,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'spot_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile = await File(
      originalImagePath,
    ).copy('${appDir.path}/$fileName');

    final newSpot = UserSpot()
      ..imagePath = savedFile.path
      ..dateCaptured = DateTime.now()
      ..notes = notes?.trim()
      ..isFavorite = isFavorite
      ..isRacing = isRacing
      ..customColor = color?.trim()
      ..year = year
      ..latitude = latitude
      ..longitude = longitude
      ..locationName = locationName?.trim();

    await isar.writeTxn(() async {
      await isar.userSpots.put(newSpot);
      newSpot.carModel.value = selectedModel;
      await newSpot.carModel.save();
    });
  }

  static Future<void> updateSpot(UserSpot spot) async {
    await isar.writeTxn(() async {
      await isar.userSpots.put(spot);
    });
  }

  // ==========================================
  // RESET CORRETTO: Elimina SOLO le foto e gli avvistamenti
  // ==========================================
  static Future<void> resetDatabase() async {
    final spots = await getAllSpots();
    for (var spot in spots) {
      if (spot.imagePath.isNotEmpty) {
        final imgFile = File(spot.imagePath);
        if (await imgFile.exists()) {
          await imgFile.delete();
        }
      }
    }

    await isar.writeTxn(() async {
      await isar.userSpots.clear();
    });
  }

  // ==========================================
  // AGGIORNAMENTO OTA DA GITHUB (Con ricalcolo auto esistenti)
  // ==========================================
  static Future<int> syncCatalogWithJson() async {
    debugPrint("🔄 Avvio sincronizzazione catalogo da GITHUB...");

    try {
      const String githubRawUrl =
          'https://raw.githubusercontent.com/AndreaGarufi/CarSpotter/main/assets/data/cars_database.json';

      final response = await http.get(Uri.parse(githubRawUrl));

      if (response.statusCode != 200) {
        debugPrint(
          "❌ Errore di rete: impossibile raggiungere GitHub (${response.statusCode})",
        );
        return -1;
      }

      final String jsonString = utf8.decode(response.bodyBytes);
      final data = json.decode(jsonString) as Map<String, dynamic>;

      int addedCars = 0;
      int updatedCars = 0;
      int deletedCars = 0;
      int deletedBrands = 0;

      final jsonCars = <String>{};
      await isar.writeTxn(() async {
        final existingModels = await isar.carModels.where().findAll();
        final byName = <String, CarModel>{};
        for (final model in existingModels) {
          byName.putIfAbsent(model.name, () => model);
        }

        for (final brandEntry in data.entries) {
          final brandName = brandEntry.key;
          final brandInfo = brandEntry.value as Map<String, dynamic>;
          final brandScore = brandInfo['brandScore'] as int;
          var brand = await isar.brands.getByName(brandName);
          if (brand == null) {
            brand = Brand()..name = brandName;
            await isar.brands.put(brand);
            debugPrint("🟢 Nuova marca aggiunta: $brandName");
          }

          final brandId = brand.id;
          final modelIds = (await isar.carModels
                  .filter()
                  .brand((q) => q.idEqualTo(brandId))
                  .idProperty()
                  .findAll())
              .toSet();

          for (final entry in brandInfo['models']) {
            final name = entry['name'] as String;
            jsonCars.add(name);
            final model = byName.putIfAbsent(name, CarModel.new);
            final isNew = model.id == Isar.autoIncrement;
            final changed = _applyCatalogEntry(model, entry, brandScore);
            if (changed) await isar.carModels.put(model);
            final moved = modelIds.add(model.id);
            if (moved) {
              model.brand.value = brand;
              await model.brand.save();
            }
            if (isNew) {
              addedCars++;
            } else if (changed || moved) {
              updatedCars++;
            }
          }
        }

        // ==========================
        // ELIMINAZIONE MODELLI REMOVI
        // ==========================

        for (final car in existingModels) {
          if (!jsonCars.contains(car.name)) {
            final unused = await isar.userSpots
                .filter()
                .carModel((q) => q.idEqualTo(car.id))
                .isEmpty();

            if (unused) {
              await isar.carModels.delete(car.id);
              deletedCars++;

              debugPrint("🔴 Modello eliminato: ${car.name}");
            } else {
              debugPrint(
                "⚠️ Modello ${car.name} rimosso dal JSON ma mantenuto perché ha spot salvati",
              );
            }
          }
        }

        // ==========================
        // ELIMINAZIONE MARCHE VUOTE
        // ==========================

        final allBrands = await isar.brands.where().findAll();

        for (var brand in allBrands) {
          if (!data.containsKey(brand.name)) {
            final unused = await isar.carModels
                .filter()
                .brand((q) => q.idEqualTo(brand.id))
                .isEmpty();

            if (unused) {
              await isar.brands.delete(brand.id);
              deletedBrands++;

              debugPrint("🔴 Marca eliminata: ${brand.name}");
            }
          }
        }
      });

      debugPrint(
        "✅ Sync completato:"
        "\n+ $addedCars auto aggiunte"
        "\n↻ $updatedCars auto aggiornate"
        "\n- $deletedCars auto eliminate"
        "\n- $deletedBrands marche eliminate",
      );

      return addedCars;
    } catch (e) {
      debugPrint("❌ Errore durante sincronizzazione GitHub: $e");

      return -1;
    }
  }

  // ==========================================
  // ELIMINAZIONE SINGOLO SPOT
  // ==========================================
  static Future<void> deleteSpot(UserSpot spot) async {
    // 1. Elimina l'immagine dalla memoria del dispositivo
    if (spot.imagePath.isNotEmpty) {
      final imgFile = File(spot.imagePath);
      if (await imgFile.exists()) {
        await imgFile.delete();
        debugPrint("🗑️ File immagine eliminato: ${spot.imagePath}");
      }
    }

    // 2. Elimina il record dal database Isar
    await isar.writeTxn(() async {
      await isar.userSpots.delete(spot.id);
    });
    debugPrint("✅ Spot rimosso dal database.");
  }
}
