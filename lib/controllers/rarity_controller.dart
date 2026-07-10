import 'dart:math';
import '../models/car_model.dart';

class RarityController {
  // ==========================================
  // 1. CALCOLO RARITÀ (Da Comune a Leggendario)
  // ==========================================
  static RarityTier calculateRarity({
    required int brandScore,
    required int productionRun,
    required double priceEuro,
    required int horsepower,
  }) {
    // ⬇️ 1. CURVA DI PRODUZIONE A GRADINI (Il cuore del bilanciamento)
    // Punisce severamente le auto prodotte in massa e premia le tirature limitate
    double prodScore;
    if (productionRun <= 1000) {
      prodScore = 100;
    } else if (productionRun <= 3000) {
      prodScore = 95;
    } else if (productionRun <= 10000) {
      prodScore = 90;
    } else if (productionRun <= 15000) {
      prodScore = 85; // Es: Audi R8 (15k) prende 85 punti qui
    } else if (productionRun <= 20000) {
      prodScore = 65; // Es: Grecale (20k) prende 65
    } else if (productionRun <= 30000) {
      prodScore = 45; // Es: Urus (25k) crolla a 45
    } else if (productionRun <= 50000) {
      prodScore = 35; // Es: M4 (40k) scende a 35
    } else if (productionRun <= 100000) {
      prodScore = 25; // Es: GT500 (65k) scende a 25
    } else if (productionRun <= 300000) {
      prodScore = 15;
    } else if (productionRun <= 1000000) {
      prodScore = 5;
    } else {
      prodScore = 0; // Oltre il milione (Es: Giulietta, Punto) = 0 punti
    }

    // ⬇️ 2. CALCOLO PREZZO E PERFORMANCE
    double priceScore = (min(priceEuro, 250000) / 250000) * 100;
    double perfScore = (min(horsepower, 750) / 750) * 100;

    // ⚖️ 3. PESI FINALI (La potenza conta di più per salvare le Muscle Car)
    double finalScore =
        (brandScore * 0.15) +
        (prodScore * 0.35) +
        (priceScore * 0.20) +
        (perfScore * 0.30);

    // 🚦 4. SOGLIE PERFETTE
    if (finalScore <= 30) {
      return RarityTier.common;
    } // Es: Giulietta (~19 pt)
    if (finalScore <= 45) {
      return RarityTier.uncommon;
    }
    if (finalScore <= 55) {
      return RarityTier.rare;
    } // Es: M4 (~52.1 pt), Grecale (~52.7 pt)
    if (finalScore <= 75) {
      return RarityTier.epic;
    } // Es: GT500 (~55.5 pt), Urus (~74.4 pt)
    return RarityTier.legendary; // Es: R8 (~75.3 pt), LaFerrari (~99.8 pt)
  }

  // ==========================================
  // 2. CALCOLO ICONA (Il fuoco 🔥)
  // ==========================================
  static bool checkIfIcon({
    required int salesVolume,
    required int brandHeritage,
    required int popCultureScore,
    required int technicalInnovation,
    required int launchYear,
  }) {
    int currentYear = DateTime.now().year;
    int legacyYears = currentYear - launchYear;
    if (legacyYears < 0) legacyYears = 0;

    // Raggiunge il massimo del prestigio storico a 40 anni di età
    double legacyScore = (min(legacyYears, 40) / 40 * 100);

    // ❌ RIMOSSO IL SALES VOLUME: Un'icona non deve per forza aver venduto tanto!
    // ⚖️ Nuovi Pesi: Il 50% del punteggio ora dipende puramente dal Pop Culture Score.
    double iconScore =
        (popCultureScore * 0.51) +
        (technicalInnovation * 0.21) +
        (brandHeritage * 0.22) +
        (legacyScore * 0.6);

    // 📈 Alziamo la soglia a 80. Solo le auto con un alto impatto culturale ce la faranno.
    return iconScore >= 89;
  }
}
