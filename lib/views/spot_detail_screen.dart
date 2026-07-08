import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/db_service.dart';
import '../models/user_spot.dart';
import '../models/car_model.dart'; // <-- Aggiunto per usare RarityTier

class SpotDetailScreen extends StatefulWidget {
  final UserSpot spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  late TextEditingController _colorController;
  late TextEditingController _yearController;
  late TextEditingController _notesController;

  late bool _isFavorite;
  late bool _isRacing;
  bool _isSaving = false;

  // Posizione GPS / Mappa
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _colorController = TextEditingController(
      text: widget.spot.customColor ?? '',
    );
    _yearController = TextEditingController(
      text: widget.spot.year?.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.spot.notes ?? '');
    _isFavorite = widget.spot.isFavorite;
    _isRacing = widget.spot.isRacing;

    // Inizializza i dati di posizione se presenti
    _latitude = widget.spot.latitude;
    _longitude = widget.spot.longitude;
    _locationName = widget.spot.locationName;
  }

  // ==========================================
  // 🎨 BADGE DI RARITÀ / ICONICITÀ
  // ==========================================
  Color _getRarityColor(RarityTier tier) {
    switch (tier) {
      case RarityTier.common:
        return const Color(0xFF9CA3AF); // Grigio
      case RarityTier.uncommon:
        return const Color(0xFF10B981); // Verde
      case RarityTier.rare:
        return const Color(0xFF3B82F6); // Azzurro
      case RarityTier.epic:
        return const Color(0xFF8B5CF6); // Viola
      case RarityTier.legendary:
        return const Color(0xFFF59E0B); // Giallo/Oro
    }
  }

  String _getRarityLabel(RarityTier tier) {
    switch (tier) {
      case RarityTier.common:
        return "COMUNE";
      case RarityTier.uncommon:
        return "NON COMUNE";
      case RarityTier.rare:
        return "RARA";
      case RarityTier.epic:
        return "EPICA";
      case RarityTier.legendary:
        return "LEGGENDARIA";
    }
  }

  Widget _buildOvalBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999), // forma ovale/pill
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // 1. OTTIENI POSIZIONE DA ANTENNA GPS
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("⚠️ Permessi negati.", Colors.orange);
          setState(() => _isLocating = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationName =
              "GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}";
          _isLocating = false;
        });
        _showSnackBar("📍 Posizione aggiornata!", const Color(0xFF10B981));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        _showSnackBar("❌ Errore GPS", Colors.red);
      }
    }
  }

  // 2. APRI MAPPA INTERATTIVA
  void _openInteractiveMap() {
    LatLng center = LatLng(_latitude ?? 37.0755, _longitude ?? 15.2866);

    showDialog(
      context: context,
      builder: (mapContext) => StatefulBuilder(
        builder: (context, setMapState) {
          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 420,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 13.0,
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture) {
                            setMapState(() => center = position.center);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.andrea.carspotter',
                        ),
                      ],
                    ),
                    const Icon(Icons.location_pin, size: 48, color: Colors.red),
                    Positioned(
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Muovi la mappa",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(mapContext),
                child: const Text("Annulla"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
                onPressed: () {
                  setState(() {
                    _latitude = center.latitude;
                    _longitude = center.longitude;
                    _locationName =
                        "Mappa: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}";
                  });
                  Navigator.pop(mapContext);
                },
                child: const Text(
                  "Conferma 📍",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    widget.spot.customColor = _colorController.text.isNotEmpty
        ? _colorController.text
        : null;
    widget.spot.year = int.tryParse(_yearController.text.trim());
    widget.spot.notes = _notesController.text.isNotEmpty
        ? _notesController.text
        : null;
    widget.spot.isFavorite = _isFavorite;
    widget.spot.isRacing = _isRacing;
    widget.spot.latitude = _latitude;
    widget.spot.longitude = _longitude;
    widget.spot.locationName = _locationName;

    await DbService.updateSpot(widget.spot);

    if (mounted) {
      _showSnackBar(
        "✅ Modifiche salvate con successo!",
        const Color(0xFF10B981),
      );
      Navigator.pop(context, true);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _colorController.dispose();
    _yearController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.spot.carModel.value;

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEE4),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A1A),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'spot_${widget.spot.id}',
                child: Image.file(
                  File(widget.spot.imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model?.brand.value?.name ?? "Marca Sconosciuta",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    model?.name ?? "Modello Sconosciuto",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -1,
                    ),
                  ),

                  // 🏷️ BADGE RARITÀ + ICONICA (accanto al nome del modello)
                  if (model != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildOvalBadge(
                          _getRarityLabel(model.rarityTier),
                          _getRarityColor(model.rarityTier),
                        ),
                        if (model.isIcon)
                          _buildOvalBadge(
                            "ICONICA ⭐",
                            const Color(0xFFEF4444), // Rosso
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Text(
                    "MODIFICA DETTAGLI",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _colorController,
                          decoration: InputDecoration(
                            labelText: "Colore",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Anno",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Note dell'avvistamento",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          activeThumbColor: const Color(0xFF10B981),
                          title: const Text(
                            "Preferito ❤️",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          value: _isFavorite,
                          onChanged: (val) => setState(() => _isFavorite = val),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          activeThumbColor: const Color(0xFF3B82F6),
                          title: const Text(
                            "Auto da Pista / Racing 🏁",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          value: _isRacing,
                          onChanged: (val) => setState(() => _isRacing = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // SEZIONE MAPPA INLINE
                  const Text(
                    "LUOGO DI AVVISTAMENTO",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _latitude != null && _longitude != null
                        ? FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(_latitude!, _longitude!),
                              initialZoom: 15.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ), // Disabilita lo scroll sulla mini mappa
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.andrea.carspotter',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(_latitude!, _longitude!),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Inserisci luogo di spot",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLocating ? null : _getCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 16),
                          label: const Text(
                            "GPS",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openInteractiveMap,
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text(
                            "Mappa",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Salva Modifiche",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
