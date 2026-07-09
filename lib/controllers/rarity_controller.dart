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
    // ⬇️ Tetti abbassati per premiare di più le vere sportive.
    // Oltre i 200k Euro o i 700 CV, l'auto prende il massimo dei punti.
    double prodScore = 100 - (min(productionRun, 500000) / 500000 * 100);
    double priceScore = (min(priceEuro, 200000) / 200000 * 100);
    double perfScore = (min(horsepower, 700) / 700 * 100);

    // ⚖️ Nuovi pesi: Il brand conta meno (15%), la tiratura domina (35%),
    // prezzo e performance pesano in modo equilibrato (25% e 25%).
    double finalScore =
        (brandScore * 0.15) +
        (prodScore * 0.35) +
        (priceScore * 0.25) +
        (perfScore * 0.25);

    // 🚦 Nuove Soglie Bilanciate
    if (finalScore <= 25)
      return RarityTier.common; // Es. Giulietta (scende a ~20 pt)
    if (finalScore <= 45) return RarityTier.uncommon;
    if (finalScore <= 55) return RarityTier.rare;
    if (finalScore <= 72) return RarityTier.epic;
    return RarityTier
        .legendary; // Es. R8 (~73 pt) e 812 Superfast (~99 pt) diventano Leggendarie!
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
        (popCultureScore * 0.50) +
        (technicalInnovation * 0.20) +
        (brandHeritage * 0.20) +
        (legacyScore * 0.10);

    // 📈 Alziamo la soglia a 80. Solo le auto con un alto impatto culturale ce la faranno.
    return iconScore >= 80;
  }
}
