import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/db_service.dart';
import '../models/brand.dart';
import '../models/car_model.dart';

typedef _CatalogGroup = ({Brand brand, List<CarModel> models});

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<_CatalogGroup> _catalog = [];
  Set<int> _spottedModelIds = {};

  // Immagine header casuale
  late String _headerImage;

  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Seleziona un'immagine casuale da journal_catalog1 a journal_catalog8
    int randomImg = math.Random().nextInt(8) + 1;
    _headerImage = 'assets/images/journal_catalog$randomImg.jpg';

    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final brands = await DbService.getAllBrands();
    final models = await DbService.getAllCarModels();
    final spottedIds = await DbService.getSpottedModelIds();

    if (!mounted) return;
    final modelsByBrand = <int, List<CarModel>>{};
    for (final model in models) {
      final brandId = model.brand.value?.id;
      if (brandId != null) (modelsByBrand[brandId] ??= []).add(model);
    }
    brands.sort((a, b) => a.name.compareTo(b.name));
    for (final group in modelsByBrand.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }
    setState(() {
      _catalog = [
        for (final brand in brands)
          (brand: brand, models: modelsByBrand[brand.id] ?? const <CarModel>[]),
      ];
      _spottedModelIds = spottedIds;
      _isLoading = false;
    });
  }

  List<_CatalogGroup> get _filteredCatalog {
    if (_searchQuery.isEmpty) return _catalog;
    final query = _searchQuery.toLowerCase();
    final matches = <_CatalogGroup>[];
    for (final group in _catalog) {
      if (group.brand.name.toLowerCase().contains(query)) {
        matches.add(group);
      } else {
        final models = group.models
            .where((m) => m.name.toLowerCase().contains(query))
            .toList();
        if (models.isNotEmpty) {
          matches.add((brand: group.brand, models: models));
        }
      }
    }
    return matches;
  }

  Widget _buildModelTile(CarModel model) {
    final isSpotted = _spottedModelIds.contains(model.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(
        model.name,
        style: TextStyle(
          fontWeight: isSpotted ? FontWeight.bold : FontWeight.normal,
          color: isSpotted ? const Color(0xFF1A1A1A) : Colors.grey.shade700,
        ),
      ),
      subtitle: model.isIcon
          ? const Text(
              "🔥 Modello Iconico",
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            )
          : null,
      trailing: isSpotted
          ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _filteredCatalog;
    // Calcoliamo l'altezza esatta per far prendere alla foto il 50% dello schermo
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEE4),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. L'HEADER FOTOGRAFICO A SCORRIMENTO (SLIVER APP BAR)
                SliverAppBar(
                  expandedHeight:
                      screenHeight * 0.50, // 50% dello schermo all'avvio!
                  pinned: true,
                  stretch: true,
                  backgroundColor: const Color(0xFF1A1A1A),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.fadeTitle,
                    ],
                    centerTitle: false,
                    // 👇 ALZATO A 34 per fare spazio al sottotitolo sotto 👇
                    titlePadding: const EdgeInsets.only(left: 56, bottom: 34),
                    title: const Text(
                      "Catalogo Completo",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Immagine di sfondo
                        Image.asset(
                          _headerImage,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: const Color(0xFF1E293B)),
                        ),
                        // Sfumatura scura rinforzata per il testo
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.9),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        // 👇 ABBASSATO A 14 per posizionarsi sotto il titolo 👇
                        const Positioned(
                          bottom: 14,
                          left: 56,
                          child: Text(
                            "Scopri tutti i modelli e le icone",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. LA BARRA DI RICERCA
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: "Cerca marca o modello (es. Ferrari, F40...)",
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF10B981),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. LA LISTA DELLE MARCHE (ESPANDIBILE)
                if (groups.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        "Nessun veicolo trovato 🏎️",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final brand = groups[index].brand;
                        final brandModels = groups[index].models;

                        final spottedCount = brandModels
                            .where((m) => _spottedModelIds.contains(m.id))
                            .length;
                        final isBrandComplete =
                            spottedCount == brandModels.length &&
                            brandModels.isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: _searchQuery.isNotEmpty,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1A1A1A,
                                  ).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.directions_car,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              title: Text(
                                brand.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Text(
                                "$spottedCount / ${brandModels.length} spottate",
                                style: TextStyle(
                                  color: isBrandComplete
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isBrandComplete
                                  ? const Icon(
                                      Icons.workspace_premium,
                                      color: Color(0xFF10B981),
                                    )
                                  : const Icon(Icons.expand_more),
                              children: [
                                Builder(
                                  builder: (_) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final model in brandModels)
                                        _buildModelTile(model),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: groups.length),
                    ),
                  ),

                // Margine finale per staccare dal fondo
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }
}
