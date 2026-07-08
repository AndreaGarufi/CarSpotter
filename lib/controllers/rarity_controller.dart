import 'dart:math';
import '../models/car_model.dart';

class RarityController {
  // Calcolo Rarity Score (0-100) basato su pesi: 40% Brand, 25% Produzione, 25% Prezzo, 10% Prestazioni
  static RarityTier calculateRarity({
    required int brandScore,
    required int productionRun,
    required double priceEuro,
    required int horsepower,
  }) {
    double prodScore = 100 - (min(productionRun, 1000000) / 1000000 * 100);
    double priceScore = (min(priceEuro, 2000000) / 2000000 * 100);
    double perfScore = (min(horsepower, 1000) / 1000 * 100);

    double finalScore =
        (brandScore * 0.40) +
        (prodScore * 0.25) +
        (priceScore * 0.25) +
        (perfScore * 0.10);

    if (finalScore <= 35) return RarityTier.common;
    if (finalScore <= 55) return RarityTier.uncommon;
    if (finalScore <= 75) return RarityTier.rare;
    if (finalScore <= 90) return RarityTier.epic;
    return RarityTier.legendary;
  }

  // Calcolo Icon Score ( >= 75 attiva il flag Icon )
  static bool checkIfIcon({
    required int salesVolume,
    required int brandHeritage,
    required int popCultureScore,
    required int technicalInnovation,
    required int launchYear, // <-- CAMBIATO: Ora riceve l'anno di produzione
  }) {
    // ⏳ Calcolo dinamico dell'età dell'auto
    int currentYear = DateTime.now().year;
    int legacyYears = currentYear - launchYear;
    // Evitiamo anni negativi se inserisci un'auto che deve ancora uscire
    if (legacyYears < 0) legacyYears = 0;

    // Normalizziamo i numeri grandi in una scala da 0 a 100
    double salesScore = (min(salesVolume, 500000) / 500000 * 100);

    // 50 anni di legacy danno il massimo del punteggio storico (100)
    double legacyScore = (min(legacyYears, 50) / 50 * 100);

    double iconScore =
        (salesScore * 0.10) +
        (brandHeritage * 0.15) +
        (popCultureScore * 0.45) +
        (technicalInnovation * 0.15) +
        (legacyScore * 0.15);

    return iconScore >= 75;
  }
}
