import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/db_service.dart';
import '../models/user_spot.dart';
import '../models/brand.dart';
import 'spot_detail_screen.dart';

enum RaritySort { none, asc, desc }

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  List<UserSpot> _allSpots = [];
  List<UserSpot> _filteredSpots = [];
  List<Brand> _allBrands = [];

  // Immagine Vintage casuale
  late String _headerImage;

  // Filtri Attivi
  bool _filterIconic = false;
  bool _filterRacing = false;
  Brand? _selectedBrand;
  RaritySort _raritySort = RaritySort.none;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Seleziona un'immagine casuale da vintage1 a vintage6
    int randomImg = math.Random().nextInt(6) + 1;
    _headerImage = 'assets/images/vintage$randomImg.jpg';
    _loadGarage();
  }

  Future<void> _loadGarage() async {
    final spots = await DbService.getAllSpots();
    final brands = await DbService.getAllBrands();
    if (mounted) {
      setState(() {
        _allSpots = spots;
        _allBrands = brands;
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    List<UserSpot> temp = _allSpots.toList();

    if (_filterIconic) {
      temp = temp.where((s) => s.carModel.value?.isIcon == true).toList();
    }
    if (_filterRacing) {
      temp = temp.where((s) => s.isRacing == true).toList();
    }
    if (_selectedBrand != null) {
      temp = temp
          .where((s) => s.carModel.value?.brand.value?.id == _selectedBrand!.id)
          .toList();
    }

    if (_raritySort == RaritySort.desc) {
      temp.sort(
        (a, b) => (b.carModel.value?.baseRarityScore ?? 0).compareTo(
          a.carModel.value?.baseRarityScore ?? 0,
        ),
      );
    } else if (_raritySort == RaritySort.asc) {
      temp.sort(
        (a, b) => (a.carModel.value?.baseRarityScore ?? 0).compareTo(
          b.carModel.value?.baseRarityScore ?? 0,
        ),
      );
    } else {
      temp.sort((a, b) => b.dateCaptured.compareTo(a.dateCaptured));
    }

    setState(() => _filteredSpots = temp);
  }

  void _showBrandPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Filtra per Marca",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text(
                "Tutte le marche",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: _selectedBrand == null
                  ? const Icon(Icons.check, color: Color(0xFF10B981))
                  : null,
              onTap: () {
                setState(() => _selectedBrand = null);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _allBrands.length,
                itemBuilder: (context, index) {
                  final brand = _allBrands[index];
                  return ListTile(
                    title: Text(brand.name),
                    trailing: _selectedBrand?.id == brand.id
                        ? const Icon(Icons.check, color: Color(0xFF10B981))
                        : null,
                    onTap: () {
                      setState(() => _selectedBrand = brand);
                      _applyFilters();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRaritySort() {
    setState(() {
      if (_raritySort == RaritySort.none) {
        _raritySort = RaritySort.desc;
      } else if (_raritySort == RaritySort.desc) {
        _raritySort = RaritySort.asc;
      } else {
        _raritySort = RaritySort.none;
      }
    });
    _applyFilters();
  }

  // Header Fotografico Aesthetic (Corretto e posizionato in basso)
  Widget _buildHeroHeader() {
    return Container(
      height: 228,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
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
          // Sfumatura scura per rendere leggibile il testo
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          // Testo ancorato in basso
          Positioned(
            bottom: 12, // Testo abbassato per non coprire l'immagine
            left: 8,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Il Mio Garage",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 48.0),
                  child: Text(
                    "Filtra e organizza i tuoi avvistamenti",
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEE4),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(),

                const SizedBox(height: 12), // Distanza dai filtri
                // BARRA DEI FILTRI
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      ActionChip(
                        backgroundColor: _raritySort != RaritySort.none
                            ? const Color(0xFF10B981)
                            : Colors.white,
                        label: Text(
                          _raritySort == RaritySort.none
                              ? "Ordina Rarità"
                              : _raritySort == RaritySort.desc
                              ? "Rarità ⬇️"
                              : "Rarità ⬆️",
                          style: TextStyle(
                            color: _raritySort != RaritySort.none
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _toggleRaritySort,
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        backgroundColor: _selectedBrand != null
                            ? const Color(0xFF10B981)
                            : Colors.white,
                        label: Text(
                          _selectedBrand == null
                              ? "Marca 🔽"
                              : "${_selectedBrand!.name} ❌",
                          style: TextStyle(
                            color: _selectedBrand != null
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _selectedBrand == null
                            ? _showBrandPicker
                            : () {
                                setState(() => _selectedBrand = null);
                                _applyFilters();
                              },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selectedColor: const Color(0xFFEF4444),
                        checkmarkColor: Colors.white,
                        label: Text(
                          "Iconic 🔥",
                          style: TextStyle(
                            color: _filterIconic ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: _filterIconic,
                        onSelected: (val) {
                          setState(() => _filterIconic = val);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selectedColor: const Color(0xFF3B82F6),
                        checkmarkColor: Colors.white,
                        label: Text(
                          "Racing 🏁",
                          style: TextStyle(
                            color: _filterRacing ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: _filterRacing,
                        onSelected: (val) {
                          setState(() => _filterRacing = val);
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ),

                // GRIGLIA FOTOGRAFICA A 2 COLONNE
                Expanded(
                  child: _filteredSpots.isEmpty
                      ? const Center(
                          child: Text(
                            "Nessuna auto trovata 😢, esci e spotta qualche auto.",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.80,
                              ),
                          itemCount: _filteredSpots.length,
                          itemBuilder: (context, index) {
                            final spot = _filteredSpots[index];
                            final model = spot.carModel.value;

                            return GestureDetector(
                              onTap: () async {
                                final isUpdated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SpotDetailScreen(spot: spot),
                                  ),
                                );
                                if (isUpdated == true) _loadGarage();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Hero(
                                      tag: 'spot_${spot.id}',
                                      child: Image.file(
                                        File(spot.imagePath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.black.withValues(
                                                alpha: 0.8,
                                              ),
                                              Colors.transparent,
                                            ],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              model?.brand.value?.name
                                                      .toUpperCase() ??
                                                  "",
                                              style: const TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              model?.name ?? "Sconosciuto",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Row(
                                        children: [
                                          if (model?.isIcon == true)
                                            const Icon(
                                              Icons.local_fire_department,
                                              color: Color(0xFFEF4444),
                                              size: 20,
                                            ),
                                          if (spot.isRacing)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Icon(
                                                Icons.flag,
                                                color: Color(0xFF3B82F6),
                                                size: 20,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (spot.isFavorite)
                                      const Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Icon(
                                          Icons.favorite,
                                          color: Color(0xFF10B981),
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
