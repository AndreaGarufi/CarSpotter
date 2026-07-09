import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../models/brand.dart';
import '../models/car_model.dart';
import '../models/user_spot.dart';
import 'rarity_controller.dart';

class DbService {
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

    // Se il database è vuoto, leggiamo il JSON e lo popoliamo!
    await _seedInitialData();
  }

  // ==========================================
  // INIEZIONE DATI E CALCOLO ALGORITMICO PRO
  // ==========================================
  static Future<void> _seedInitialData() async {
    final count = await isar.brands.count();
    if (count > 0) return; // Database già popolato

    debugPrint("🌱 Avvio iniezione PRO dal file JSON...");

    try {
      final String response = await rootBundle.loadString(
        'assets/data/cars_database.json',
      );
      final data = await json.decode(response) as Map<String, dynamic>;

      await isar.writeTxn(() async {
        for (var brandName in data.keys) {
          final brandInfo = data[brandName] as Map<String, dynamic>;
          final brandScore = brandInfo["brandScore"] as int;
          final brandHeritage = brandInfo["brandHeritage"] as int;

          final brand = Brand()..name = brandName;
          await isar.brands.put(brand);

          final modelsData = brandInfo["models"] as List<dynamic>;
          for (var item in modelsData) {
            final m = item as Map<String, dynamic>;

            final rarityTier = RarityController.calculateRarity(
              brandScore: brandScore,
              productionRun: m["productionRun"] as int,
              priceEuro: (m["priceEuro"] as num).toDouble(),
              horsepower: m["horsepower"] as int,
            );

            final isIcon = RarityController.checkIfIcon(
              salesVolume: m["salesVolume"] as int,
              brandHeritage: brandHeritage,
              popCultureScore: m["popCultureScore"] as int,
              technicalInnovation: m["technicalInnovation"] as int,
              launchYear: m["launchYear"] as int,
            );

            int baseScore;
            switch (rarityTier) {
              case RarityTier.legendary:
                baseScore = 95;
                break;
              case RarityTier.epic:
                baseScore = 85;
                break;
              case RarityTier.rare:
                baseScore = 70;
                break;
              case RarityTier.uncommon:
                baseScore = 50;
                break;
              case RarityTier.common:
                baseScore = 30;
                break;
            }

            final carModel = CarModel()
              ..name = m["name"] as String
              ..isIcon = isIcon
              ..baseRarityScore = baseScore
              ..rarityTier = rarityTier
              ..iconScore = isIcon ? 90 : 50
              ..engineHp = m["horsepower"] as int
              ..productionRun = m["productionRun"] as int
              ..launchYear = m["launchYear"] as int;

            carModel.brand.value = brand;
            await isar.carModels.put(carModel);
            await carModel.brand.save();
          }
        }
      });
      debugPrint("✅ Catalogo PRO generato con successo dai calcoli!");
    } catch (e) {
      debugPrint("❌ Errore durante la lettura o il calcolo del JSON: $e");
    }
  }

  // --- UTILITY PER RECUPERARE DATI ---
  static Future<List<UserSpot>> getAllSpots() async {
    return await isar.userSpots.where().findAll();
  }

  static Future<List<UserSpot>> getFavoriteSpots() async {
    return await isar.userSpots.filter().isFavoriteEqualTo(true).findAll();
  }

  static Future<int> getTotalCarModelsCount() async {
    return await isar.carModels.count();
  }

  static Future<int> getTotalUserSpotsCount() async {
    return await isar.userSpots.count();
  }

  static Future<int> getUniqueSpottedModelsCount() async {
    final spots = await isar.userSpots.where().findAll();
    final uniqueModelIds = spots
        .map((s) => s.carModel.value?.id)
        .whereType<int>()
        .toSet();
    return uniqueModelIds.length;
  }

  static Future<int> getLegendarySpotsCount() async {
    final spots = await isar.userSpots.where().findAll();
    return spots.where((spot) {
      final model = spot.carModel.value;
      return model != null &&
          (model.rarityTier == RarityTier.legendary ||
              model.baseRarityScore >= 85);
    }).length;
  }

  static Future<int> getIconicSpotsCount() async {
    final spots = await isar.userSpots.where().findAll();
    return spots.where((s) => s.carModel.value?.isIcon == true).length;
  }

  static Future<List<CarModel>> getAllCarModels() async {
    return await isar.carModels.where().findAll();
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
      final data = await json.decode(jsonString) as Map<String, dynamic>;

      int addedCars = 0;
      int updatedCars = 0;
      int deletedCars = 0;
      int deletedBrands = 0;

      // Lista di controllo del contenuto JSON
      final jsonBrands = <String>{};
      final jsonCars = <String>{};

      for (var brandName in data.keys) {
        jsonBrands.add(brandName);

        final brandInfo = data[brandName] as Map<String, dynamic>;
        final modelsData = brandInfo["models"] as List<dynamic>;

        for (var item in modelsData) {
          final m = item as Map<String, dynamic>;
          jsonCars.add(m["name"] as String);
        }
      }

      await isar.writeTxn(() async {
        // ==========================
        // AGGIUNTA / UPDATE DATI
        // ==========================

        for (var brandName in data.keys) {
          final brandInfo = data[brandName] as Map<String, dynamic>;

          final brandScore = brandInfo["brandScore"] as int;
          final brandHeritage = brandInfo["brandHeritage"] as int;

          var brand = await isar.brands
              .filter()
              .nameEqualTo(brandName)
              .findFirst();

          if (brand == null) {
            brand = Brand()..name = brandName;
            await isar.brands.put(brand);

            debugPrint("🟢 Nuova marca aggiunta: $brandName");
          }

          final modelsData = brandInfo["models"] as List<dynamic>;

          for (var item in modelsData) {
            final m = item as Map<String, dynamic>;

            final carName = m["name"] as String;

            final rarityTier = RarityController.calculateRarity(
              brandScore: brandScore,
              productionRun: m["productionRun"] as int,
              priceEuro: (m["priceEuro"] as num).toDouble(),
              horsepower: m["horsepower"] as int,
            );

            final isIcon = RarityController.checkIfIcon(
              salesVolume: m["salesVolume"] as int,
              brandHeritage: brandHeritage,
              popCultureScore: m["popCultureScore"] as int,
              technicalInnovation: m["technicalInnovation"] as int,
              launchYear: m["launchYear"] as int,
            );

            int baseScore;

            switch (rarityTier) {
              case RarityTier.legendary:
                baseScore = 95;
                break;
              case RarityTier.epic:
                baseScore = 85;
                break;
              case RarityTier.rare:
                baseScore = 70;
                break;
              case RarityTier.uncommon:
                baseScore = 50;
                break;
              case RarityTier.common:
                baseScore = 30;
                break;
            }

            var existingCar = await isar.carModels
                .filter()
                .nameEqualTo(carName)
                .findFirst();

            if (existingCar == null) {
              final newCar = CarModel()
                ..name = carName
                ..isIcon = isIcon
                ..baseRarityScore = baseScore
                ..rarityTier = rarityTier
                ..iconScore = isIcon ? 90 : 50
                ..engineHp = m["horsepower"] as int
                ..productionRun = m["productionRun"] as int
                ..launchYear = m["launchYear"] as int;

              newCar.brand.value = brand;

              await isar.carModels.put(newCar);
              await newCar.brand.save();

              addedCars++;
            } else {
              existingCar
                ..name = carName
                ..isIcon = isIcon
                ..baseRarityScore = baseScore
                ..rarityTier = rarityTier
                ..iconScore = isIcon ? 90 : 50
                ..engineHp = m["horsepower"] as int
                ..productionRun = m["productionRun"] as int
                ..launchYear = m["launchYear"] as int;

              existingCar.brand.value = brand;

              await isar.carModels.put(existingCar);
              await existingCar.brand.save();

              updatedCars++;
            }
          }
        }

        // ==========================
        // ELIMINAZIONE MODELLI REMOVI
        // ==========================

        final allCars = await isar.carModels.where().findAll();

        for (var car in allCars) {
          if (!jsonCars.contains(car.name)) {
            final spots = await isar.userSpots
                .filter()
                .carModel((q) => q.idEqualTo(car.id))
                .findAll();

            if (spots.isEmpty) {
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
          if (!jsonBrands.contains(brand.name)) {
            final models = await isar.carModels
                .filter()
                .brand((q) => q.idEqualTo(brand.id))
                .findAll();

            if (models.isEmpty) {
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
}
