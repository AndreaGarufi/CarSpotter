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
    required int popCultureScore,
    required int technicalInnovation,
    RarityTier? rarityOverride,
  }) {
    if (rarityOverride != null) return rarityOverride;

    // La produzione diminuisce in modo graduale: non ci sono salti artificiali
    // tra due modelli con poche unità di differenza.
    final prodScore = (100 *
            (1 - (log(max(productionRun, 100)) / ln10 / 6)))
        .clamp(0, 100)
        .toDouble();
    final priceScore = (min(priceEuro, 250000) / 250000) * 100;
    final perfScore = (min(horsepower, 550) / 550) * 100;

    // Il segmento è un indicatore automatico, non un premio assegnato alla
    // marca: prezzo e prestazioni del singolo modello contano molto di più.
    final segmentScore = (brandScore * 0.25) +
        (min(priceEuro, 200000) / 200000 * 25) +
        (min(horsepower, 600) / 600 * 50);
    final modelSignificanceScore =
        (popCultureScore * 0.60) + (technicalInnovation * 0.40);

    final finalScore =
        (prodScore * 0.25) +
        (priceScore * 0.10) +
        (perfScore * 0.20) +
        (segmentScore * 0.25) +
        (modelSignificanceScore * 0.20);

    if (finalScore <= 28) return RarityTier.common;
    if (finalScore <= 43) return RarityTier.uncommon;
    if (finalScore <= 59) return RarityTier.rare;
    if (finalScore < 90) return RarityTier.epic;
    return RarityTier.legendary;
  }

  static RarityTier? rarityTierFromOverride(String? value) {
    switch (value) {
      case 'common':
        return RarityTier.common;
      case 'uncommon':
        return RarityTier.uncommon;
      case 'rare':
        return RarityTier.rare;
      case 'epic':
        return RarityTier.epic;
      case 'legendary':
        return RarityTier.legendary;
      default:
        return null;
    }
  }

  // ==========================================
  // 2. CALCOLO ICONA (Il fuoco 🔥)
  // ==========================================
  static bool checkIfIcon({
    required int brandHeritage,
    required int popCultureScore,
    required int technicalInnovation,
    required int launchYear,
    bool? isIconOverride,
  }) {
    // Un giudizio editoriale esplicito prevale sempre sul calcolo. Serve per
    // modelli recenti o per casi storici che una formula non può descrivere
    // completamente (es. hypercar e versioni particolarmente rappresentative).
    if (isIconOverride != null) return isIconOverride;

    int currentYear = DateTime.now().year;
    int legacyYears = currentYear - launchYear;
    if (legacyYears < 0) legacyYears = 0;

    // L'anzianità è soltanto un piccolo bonus: essere vecchia non rende un
    // modello iconico. Il massimo si raggiunge dopo 40 anni.
    double legacyScore = (min(legacyYears, 40) / 40 * 100);

    // I pesi sommano al 100%. Cultura e importanza tecnica sono del modello;
    // lo storico del marchio non può, da solo, promuovere tutta la sua gamma.
    double iconScore =
        (popCultureScore * 0.50) +
        (technicalInnovation * 0.25) +
        (legacyScore * 0.15) +
        (brandHeritage * 0.10);

    // Servono un impatto culturale molto alto e una prova forte, tecnica o
    // storica. Evita falsi positivi come una berlina moderna di un marchio
    // prestigioso o una sportiva semplicemente longeva.
    final hasStrongCulturalImpact = popCultureScore >= 85;
    final hasDefiningEvidence =
        technicalInnovation >= 90 || legacyYears >= 30;

    return iconScore >= 85 && hasStrongCulturalImpact && hasDefiningEvidence;
  }
}
