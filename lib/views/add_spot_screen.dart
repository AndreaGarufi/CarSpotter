import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/db_service.dart';
import '../models/brand.dart';
import '../models/car_model.dart';

class AddSpotScreen extends StatefulWidget {
  final String imagePath;

  const AddSpotScreen({super.key, required this.imagePath});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> {
  // Liste dati dal Database Isar
  List<Brand> _availableBrands = [];
  List<CarModel> _allModels = [];
  List<CarModel> _filteredModels = [];

  // Selezioni obbligatorie
  Brand? _selectedBrand;
  CarModel? _selectedCarModel;

  // Controller per i campi di testo opzionali
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Posizione GPS / Mappa
  double? _latitude;
  double? _longitude;
  String _locationDisplay = "Nessuna posizione selezionata";
  bool _isLocating = false;

  // Stato interruttori e caricamento
  bool _isFavorite = false;
  bool _isRacing = false;
  bool _isLoading = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final brands = await DbService.getAllBrands();
    final models = await DbService.getAllCarModels();
    if (mounted) {
      setState(() {
        _availableBrands = brands;
        _allModels = models;
      });
    }
  }

  // Filtra i modelli a catalogo quando si sceglie una Marca (Filtro a cascata)
  void _onBrandSelected(Brand? brand) {
    setState(() {
      _selectedBrand = brand;
      _selectedCarModel = null; // Resetta il modello se cambi marca
      if (brand != null) {
        _filteredModels = _allModels
            .where((m) => m.brand.value?.id == brand.id)
            .toList();
      } else {
        _filteredModels = [];
      }
    });
  }

  // 1. OTTIENI POSIZIONE DA ANTENNA GPS DEL TELEFONO
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("⚠️ Permessi di posizione negati.", Colors.orange);
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
          _locationDisplay =
              "GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}";
          _isLocating = false;
        });
        _showSnackBar(
          "📍 Posizione GPS acquisita con successo!",
          const Color(0xFF10B981),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        _showSnackBar(
          "❌ Errore GPS: assicurati che la posizione sia attiva.",
          Colors.red,
        );
      }
    }
  }

  // 2. APRI MAPPA INTERATTIVA OPENSTREETMAP
  void _openInteractiveMap() {
    // Centro iniziale (Default: Siracusa / Sicilia sud-orientale o coordinate già acquisite)
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
                          userAgentPackageName: 'com.carspotter.app',
                        ),
                      ],
                    ),
                    // Mirino fisso al centro dello schermo
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
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              color: Colors.black.withValues(alpha: 0.15),
                            ),
                          ],
                        ),
                        child: const Text(
                          "Muovi la mappa per posizionare il mirino",
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
                child: const Text(
                  "Annulla",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
                onPressed: () {
                  setState(() {
                    _latitude = center.latitude;
                    _longitude = center.longitude;
                    _locationDisplay =
                        "Mappa: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}";
                  });
                  Navigator.pop(mapContext);
                },
                child: const Text(
                  "Conferma Posizione 📍",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveSpot() async {
    // Validazione campi obbligatori
    if (_selectedBrand == null || _selectedCarModel == null) {
      setState(() => _showError = true);
      _showSnackBar(
        "⚠️ Seleziona sia la Marca che il Modello prima di salvare!",
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    int? parsedYear = int.tryParse(_yearController.text.trim());

    await DbService.saveNewSpot(
      originalImagePath: widget.imagePath,
      selectedModel: _selectedCarModel!,
      color: _colorController.text.isNotEmpty ? _colorController.text : null,
      year: parsedYear,
      latitude: _latitude,
      longitude: _longitude,
      locationName: _locationDisplay != "Nessuna posizione selezionata"
          ? _locationDisplay
          : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      isFavorite: _isFavorite,
      isRacing: _isRacing,
    );

    if (mounted) {
      _showSnackBar(
        "🚀 ${_selectedCarModel!.name} salvata nel Garage!",
        const Color(0xFF10B981),
      );
      Navigator.of(context).pop(true);
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
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Nuovo Spot Pro 🏎️",
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ANTEPRIMA FOTO
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),

            // 1. SELEZIONE MARCA OBBLIGATORIA
            const Text(
              "Marca Auto * (Obbligatorio)",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Brand>(
              initialValue: _selectedBrand,
              decoration: InputDecoration(
                hintText: "Scegli la casa automobilistica...",
                prefixIcon: const Icon(
                  Icons.branding_watermark,
                  color: Color(0xFF10B981),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _showError && _selectedBrand == null
                        ? Colors.red
                        : Colors.grey.shade300,
                  ),
                ),
              ),
              items: _availableBrands.map((b) {
                return DropdownMenuItem(
                  value: b,
                  child: Text(
                    b.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
              onChanged: _onBrandSelected,
            ),
            const SizedBox(height: 18),

            // 2. SELEZIONE MODELLO (FILTRATO DALLA MARCA)
            const Text(
              "Modello Auto * (Obbligatorio)",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: _selectedBrand == null,
              child: Opacity(
                opacity: _selectedBrand == null ? 0.5 : 1.0,
                child: Autocomplete<CarModel>(
                  displayStringForOption: (CarModel option) => option.name,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) return _filteredModels;
                    return _filteredModels.where(
                      (option) => option.name.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
                  },
                  onSelected: (selection) => setState(() {
                    _selectedCarModel = selection;
                    _showError = false;
                  }),
                  fieldViewBuilder: (context, controller, focusNode, _) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: _selectedBrand == null
                            ? "Prima seleziona una Marca sopra ☝️"
                            : "Cerca tra le ${_selectedBrand!.name}...",
                        prefixIcon: const Icon(
                          Icons.directions_car,
                          color: Color(0xFF10B981),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _showError && _selectedCarModel == null
                                ? Colors.red
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 3. COLORE E ANNO (AFFIANCATI IN RIGA)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Colore (Opz.)",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _colorController,
                        decoration: InputDecoration(
                          hintText: "Es. Rosso Corsa",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Anno (Opz.)",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: "Es. 1991",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4. POSIZIONE E GEOLOCALIZZAZIONE
            const Text(
              "Luogo Avvistamento (Opzionale)",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locationDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _latitude != null
                                ? const Color(0xFF1A1A1A)
                                : Colors.grey,
                          ),
                        ),
                      ),
                      if (_isLocating)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF10B981),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLocating ? null : _getCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text(
                            "GPS Attuale",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
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
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text(
                            "Apri Mappa",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
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
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 5. NOTE OPZIONALI
            const Text(
              "Note o Dettagli (Opzionale)",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Es. Avvistata sul lungomare, scarico sportivo...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 6. PREFERITI & RACING
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
                      "Aggiungi ai Preferiti ⭐",
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

            // TASTO SALVA
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSpot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Salva nel Garage ✨",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
