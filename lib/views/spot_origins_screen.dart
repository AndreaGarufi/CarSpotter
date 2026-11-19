import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/db_service.dart';
import '../models/brand.dart';
import '../models/user_spot.dart';
import 'garage_screen.dart';
import 'spot_globe.dart';
import 'system_navigation_bar.dart';

typedef _Origins = ({
  GlobeGeometry geometry,
  Map<String, String> countryByBrand,
});
typedef _BrandSpots = ({Brand brand, int count});

class SpotOriginsScreen extends StatelessWidget {
  const SpotOriginsScreen({super.key, required this.spots});

  final List<UserSpot> spots;
  static final _assets = _loadAssets();

  static Future<_Origins> _loadAssets() async {
    final geometry = GlobeGeometry.loaded;
    final source = await rootBundle.loadString(
      'assets/data/brand_origins.json',
    );
    final countries = jsonDecode(source) as Map<String, dynamic>;
    return (
      geometry: await geometry,
      countryByBrand: {
        for (final country in countries.entries)
          for (final brand in (country.value as List).cast<String>())
            brand.trim().toLowerCase(): country.key,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Origine degli spot')),
      bottomNavigationBar: const SystemNavigationBar(),
      body: FutureBuilder<_Origins>(
        future: _assets,
        builder: (context, snapshot) {
          final assets = snapshot.data;
          if (assets != null) {
            return _GlobeCollection(assets: assets, spots: spots);
          }
          return Center(
            child: snapshot.hasError
                ? const Text('Impossibile caricare il globo.')
                : const CircularProgressIndicator(),
          );
        },
      ),
    );
  }
}

class _GlobeCollection extends StatefulWidget {
  const _GlobeCollection({required this.assets, required this.spots});

  final _Origins assets;
  final List<UserSpot> spots;

  @override
  State<_GlobeCollection> createState() => _GlobeCollectionState();
}

class _GlobeCollectionState extends State<_GlobeCollection> {
  late Map<String, List<_BrandSpots>> _brandsByCountry;
  late final GlobeCountry? _initialCountry;
  GlobeCountry? _selectedCountry;
  bool _panelOpen = false;

  @override
  void initState() {
    super.initState();
    _brandsByCountry = _groupSpots(widget.spots);
    final code = _brandsByCountry.containsKey('IT')
        ? 'IT'
        : _brandsByCountry.keys.firstOrNull;
    _initialCountry = widget.assets.geometry.countries
        .where((country) => country.code == code)
        .firstOrNull;
  }

  Map<String, List<_BrandSpots>> _groupSpots(List<UserSpot> spots) {
    final counts = <String, Map<int, _BrandSpots>>{};
    for (final spot in spots) {
      final brand = spot.carModel.value?.brand.value;
      if (brand == null) continue;
      final code =
          widget.assets.countryByBrand[brand.name.trim().toLowerCase()];
      if (code == null) continue;
      final brands = counts.putIfAbsent(code, () => {});
      brands[brand.id] = (
        brand: brand,
        count: (brands[brand.id]?.count ?? 0) + 1,
      );
    }
    return {
      for (final entry in counts.entries)
        entry.key: entry.value.values.toList()
          ..sort(
            (a, b) => a.brand.name.toLowerCase().compareTo(
              b.brand.name.toLowerCase(),
            ),
          ),
    };
  }

  Future<void> _openBrand(Brand brand) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => GarageScreen(initialBrand: brand)),
    );
    if (!mounted) return;

    try {
      final spots = await DbService.getAllSpots();
      if (!mounted) return;
      setState(() {
        _brandsByCountry = _groupSpots(spots);
        if (!_brandsByCountry.containsKey(_selectedCountry?.code)) {
          _panelOpen = false;
        }
      });
    } catch (error) {
      debugPrint('Aggiornamento delle origini degli spot: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SpotGlobe.panelTransitionDuration;
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const margin = SpotGlobe.viewportInset;
          const gap = 12.0;
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final usableWidth = math.max(0.0, width - 2 * margin);
          final usableHeight = math.max(0.0, height - 2 * margin);
          final stacked = width < 600 && height > width;
          final panelWidth = stacked
              ? math.min(usableWidth, 440.0)
              : math.min(usableWidth * 0.40, 260.0);
          final closedSize = math.min(
            usableWidth,
            math.min(usableHeight, SpotGlobe.maximumDiameter),
          );
          final openWidth = stacked
              ? usableWidth
              : math.max(0.0, usableWidth - panelWidth - gap);
          final openHeight = stacked ? usableHeight * 0.57 : usableHeight;
          final openSize = math.min(
            openWidth,
            math.min(openHeight, SpotGlobe.maximumDiameter),
          );
          // The overview keeps its margins. In detail the globe can fill
          // the viewport, up to the screen edges and the brands panel.
          final globeWidth = _panelOpen && !stacked
              ? openWidth + 2 * margin
              : width;
          final globeHeight = _panelOpen && stacked
              ? openSize + 2 * margin
              : height;
          final panelTop = stacked
              ? (_panelOpen ? margin + openSize : (height + closedSize) / 2) +
                    gap
              : margin;
          final panelHeight = stacked
              ? math.max(0.0, usableHeight - openSize - gap)
              : usableHeight;
          final country = _selectedCountry;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeInOutCubic,
                left: 0,
                top: 0,
                width: globeWidth,
                height: globeHeight,
                child: SpotGlobe(
                  geometry: widget.assets.geometry,
                  unlockedCountries: _brandsByCountry.keys.toSet(),
                  initialCountry: _initialCountry,
                  countryPanelOpen: _panelOpen,
                  onCountrySelected: (country) => setState(() {
                    _selectedCountry = country;
                    _panelOpen = true;
                  }),
                ),
              ),
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeInOutCubic,
                top: panelTop,
                height: panelHeight,
                right: _panelOpen
                    ? (stacked ? (width - panelWidth) / 2 : margin)
                    : -panelWidth - margin,
                width: panelWidth,
                child: IgnorePointer(
                  ignoring: !_panelOpen,
                  child: ExcludeSemantics(
                    excluding: !_panelOpen,
                    child: Align(
                      alignment: stacked
                          ? Alignment.topCenter
                          : Alignment.center,
                      child: country == null
                          ? const SizedBox.shrink()
                          : _CountryPanel(
                              country: country,
                              brands:
                                  _brandsByCountry[country.code] ?? const [],
                              onClose: () => setState(() => _panelOpen = false),
                              onBrandTap: _openBrand,
                            ),
                    ),
                  ),
                ),
              ),
              if (_brandsByCountry.isEmpty)
                const Positioned(
                  left: 24,
                  right: 24,
                  bottom: 16,
                  child: Text(
                    'I Paesi si colorano con gli spot dei loro marchi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF535F58)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CountryPanel extends StatelessWidget {
  const _CountryPanel({
    required this.country,
    required this.brands,
    required this.onClose,
    required this.onBrandTap,
  });

  final GlobeCountry country;
  final List<_BrandSpots> brands;
  final VoidCallback onClose;
  final ValueChanged<Brand> onBrandTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: const Color(0x400C2018),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 2, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    country.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Chiudi paese',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: brands.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 12, endIndent: 12),
              itemBuilder: (context, index) {
                final item = brands[index];
                return InkWell(
                  onTap: () => onBrandTap(item.brand),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.brand.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.count}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.chevron_right, size: 17),
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
