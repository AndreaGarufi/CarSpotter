import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/db_service.dart';
import '../models/user_spot.dart';
import 'package:image_picker/image_picker.dart';
import 'add_spot_screen.dart';
import 'garage_screen.dart';
import 'catalog_screen.dart';
import 'spot_map_section.dart';
import 'spot_origins_screen.dart';
import 'system_navigation_bar.dart';
import 'topographic_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _firstFavoritePage = 1024;
  // Lista predefinita degli sfondi estetici per l'Header
  final List<String> _headerImages = [
    'assets/images/photo_header1.jpg',
    'assets/images/photo_header2.jpg',
    'assets/images/photo_header3.jpg',
    'assets/images/photo_header4.jpg',
    'assets/images/photo_header5.jpg',
    'assets/images/photo_header6.jpg',
    'assets/images/photo_header7.jpg',
    'assets/images/photo_header8.jpg',
    'assets/images/photo_header9.jpg',
    'assets/images/photo_header10.jpg',
  ];

  late String _selectedImage;
  String _username = 'Spotter';

  // Stato dati dal database locale Isar
  int _totalModels = 0;
  int _totalSpots = 0;
  int _uniqueSpottedModels = 0;
  int _legendarySpots = 0;
  int _iconSpots = 0;
  List<UserSpot> _favoriteSpots = [];
  List<UserSpot> _spots = [];
  bool _isLoading = true;
  int _loadRevision = 0;

  // Controller per il carosello in rilievo
  late PageController _pageController;

  // Timer per alternare il box in basso a destra e per l'autoscorrimento del carosello
  Timer? _alternateTimer;
  Timer? _carouselTimer;
  bool _showLegendary = true;

  @override
  void initState() {
    super.initState();
    _selectedImage = _headerImages[math.Random().nextInt(_headerImages.length)];
    _pageController = PageController(
      viewportFraction: 0.70,
      initialPage: _firstFavoritePage,
      keepPage: false,
    );
    _loadData();

    // Timer di 8 secondi per alternare la visualizzazione tra Leggendari e Icon
    _alternateTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _showLegendary = !_showLegendary;
        });
      }
    });

    // Timer di 4 secondi per l'autoscorrimento automatico del Carosello Preferiti
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted &&
          _favoriteSpots.length > 1 &&
          _pageController.hasClients &&
          !_pageController.position.isScrollingNotifier.value) {
        final nextPage =
            (_pageController.page?.round() ?? _firstFavoritePage) + 1;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _alternateTimer?.cancel();
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // Restituisce il saluto in base alla fascia oraria attuale
  String _getTimeBasedGreeting() {
    final now = DateTime.now();
    final int timeInMinutes = now.hour * 60 + now.minute;

    if (timeInMinutes >= 0 && timeInMinutes <= 300) {
      return "Sveglio?, $_username ✨";
    } else if (timeInMinutes >= 301 && timeInMinutes <= 780) {
      return "Buongiorno, $_username ☀️";
    } else if (timeInMinutes >= 781 && timeInMinutes <= 1080) {
      return "Buon pomeriggio, $_username 🌤️";
    } else {
      return "Buonasera, $_username 🌙";
    }
  }

  // Caricamento reale e autentico al 100% dal database Isar
  Future<void> _loadData() async {
    final revision = ++_loadRevision;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('username');
      if (savedName != null && savedName.trim().isNotEmpty) {
        _username = savedName.trim();
      }

      // Interroghiamo il database reale
      final stats = await DbService.getHomeStats();

      if (mounted && revision == _loadRevision) {
        final favoritesChanged = !listEquals(
          _favoriteSpots.map((spot) => spot.id).toList(),
          stats.favorites.map((spot) => spot.id).toList(),
        );
        if (favoritesChanged) _resetFavoritePage();
        setState(() {
          _totalModels = stats.totalModels;
          _totalSpots = stats.totalSpots;
          _uniqueSpottedModels = stats.uniqueModels;
          _legendarySpots = stats.legendarySpots;
          _iconSpots = stats.iconicSpots;
          _favoriteSpots = stats.favorites;
          _spots = stats.spots;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && revision == _loadRevision) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetFavoritePage() {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_firstFavoritePage);
    }
  }

  int _favoriteIndex(int page) =>
      (page - _firstFavoritePage) % _favoriteSpots.length;

  bool _recenterFavoritePages(ScrollEndNotification notification) {
    if (notification.depth != 0 || _favoriteSpots.length < 2) return false;
    final page = _pageController.page?.round();
    final upperPage =
        _firstFavoritePage +
        math.max(_firstFavoritePage, _favoriteSpots.length);
    if (page != null && (page < _firstFavoritePage ~/ 2 || page > upperPage)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_pageController.hasClients ||
            _favoriteSpots.length < 2 ||
            _pageController.position.isScrollingNotifier.value ||
            _pageController.page?.round() != page) {
          return;
        }
        _pageController.jumpToPage(_firstFavoritePage + _favoriteIndex(page));
      });
    }
    return false;
  }

  Future<void> _openSpotOrigins() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SpotOriginsScreen(spots: _spots)),
    );
    if (mounted) await _loadData();
  }

  void _onQuickSpotPressed() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Aggiungi uno Spot 🏎️",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),
                ),
                title: const Text(
                  "Scatta una Foto 📸",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final picker = ImagePicker();
                  final XFile? photo = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (photo != null && mounted) {
                    final saved = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddSpotScreen(imagePath: photo.path),
                      ),
                    );
                    if (saved == true) _loadData();
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF0F766E),
                  ),
                ),
                title: const Text(
                  "Scegli dalla Galleria 🖼️",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final picker = ImagePicker();
                  final XFile? photo = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (photo != null && mounted) {
                    final saved = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddSpotScreen(imagePath: photo.path),
                      ),
                    );
                    if (saved == true) _loadData();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcolo percentuale completamento reale basato sui modelli UNICI scoperti
    final double completionRate = _totalModels > 0
        ? (_uniqueSpottedModels / _totalModels * 100).clamp(0.0, 100.0)
        : 0.0;
    final String completionText = "${completionRate.toStringAsFixed(1)}%";

    return TopographicScaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO HEADER
                    _buildHeroHeader(),

                    const SizedBox(height: 20),

                    // 2. CRUSCOTTO STATISTICHE - RIGA 1
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: "I Tuoi Spot",
                              value: _totalSpots.toString(),
                              onTap: _openSpotOrigins,
                              assetPath: 'assets/images/home_your_spot.png',
                              fallbackIcon: Icons.directions_car_filled,
                              gradientColors: [
                                const Color(0xFF10B981),
                                const Color(0xFF059669),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              title: "Modelli presenti nel database",
                              useMarqueeTitle: true,
                              value: _totalModels.toString(),
                              assetPath: 'assets/images/home_database.png',
                              fallbackIcon: Icons.storage,
                              gradientColors: [
                                const Color(0xFF0F766E),
                                const Color(0xFF115E59),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. CRUSCOTTO STATISTICHE - RIGA 2
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: "Completamento Database",
                              useMarqueeTitle: true,
                              value: completionText,
                              icon: Icons.pie_chart_outline,
                              gradientColors: [
                                const Color(0xFF0D9488),
                                const Color(0xFF047857),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: _buildAlternatingStatCard()),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 4. CAROSELLO DELLE AUTO PREFERITE ❤️
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "Carosello delle auto preferite",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: IconButton(
                              tooltip: 'Aggiorna preferiti',
                              color: const Color(0xFF10B981),
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                _resetFavoritePage();
                                _loadData();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildFavoritesSection(),

                    const SizedBox(height: 28),
                    SpotMapSection(spots: _spots, onSpotChanged: _loadData),

                    const SizedBox(height: 100), // Spazio inferiore Bottom Bar
                  ],
                ),
              ),
            ),

      // 5. BOTTOM NAVIGATION BAR
      floatingActionButton: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF34D399), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _onQuickSpotPressed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.camera_alt, size: 28, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  // Costruisce la singola Card Statistica
  Widget _buildStatCard({
    required String title,
    required String value,
    IconData? icon,
    IconData? fallbackIcon,
    String? assetPath,
    bool useMarqueeTitle = false,
    required List<Color> gradientColors,
    VoidCallback? onTap,
  }) {
    const radius = BorderRadius.all(Radius.circular(22));
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: assetPath != null
                ? Image.asset(
                    assetPath,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      fallbackIcon ?? Icons.analytics,
                      color: Colors.white,
                      size: 24,
                    ),
                  )
                : Icon(icon ?? Icons.analytics, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF10B981),
                        size: 17,
                      ),
                  ],
                ),
                useMarqueeTitle
                    ? _MarqueeText(text: title)
                    : Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: content,
              ),
            ),
    );
  }

  // Box 4: Alterna tra Spot Leggendari e Spot Iconici
  Widget _buildAlternatingStatCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 650),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final isLegendary = child.key == const ValueKey<int>(1);
            final isIncoming =
                (isLegendary && _showLegendary) ||
                (!isLegendary && !_showLegendary);

            final beginOffset = isIncoming
                ? const Offset(0.0, -1.2)
                : const Offset(0.0, 1.2);

            return SlideTransition(
              position: Tween<Offset>(begin: beginOffset, end: Offset.zero)
                  .animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: isIncoming
                          ? Curves.bounceOut
                          : Curves.fastOutSlowIn,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _showLegendary
              ? Row(
                  key: const ValueKey<int>(1),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _legendarySpots.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const _MarqueeText(text: "Spot Leggendari 👑"),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey<int>(2),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _iconSpots.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const _MarqueeText(text: "Spot Iconici 🔥"),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // Hero Header pulito
  Widget _buildHeroHeader() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _selectedImage,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF064E3B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.85),
                  const Color(0xFF0F172A).withValues(alpha: 0.30),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTimeBasedGreeting(),
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Esplora, scatta e cataloga le tue supercar.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.80),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper per visualizzare l'icona segnaposto se l'immagine manca o è corrotta
  Widget _buildFallbackCarIcon() {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: const Icon(
        Icons.directions_car,
        size: 70,
        color: Color(0xFF334155),
      ),
    );
  }

  // Carosello Preferiti 3D in rilievo con trasparenza ai lati e foto reali
  Widget _buildFavoritesSection() {
    if (_favoriteSpots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border,
                  size: 36,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Nessun preferito nel Garage",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Aggiungi un cuore ❤️ ai tuoi avvistamenti migliori per mostrarli qui nel carosello.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
      );
    }

    if (_favoriteSpots.length == 1) {
      return SizedBox(
        height: 210,
        child: FractionallySizedBox(
          widthFactor: _pageController.viewportFraction,
          child: _buildFavoriteCard(_buildFavoritePhoto(_favoriteSpots.single)),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _recenterFavoritePages,
        child: PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) => AnimatedBuilder(
            animation: _pageController,
            child: _buildFavoritePhoto(_favoriteSpots[_favoriteIndex(index)]),
            builder: (context, child) {
              final page = _pageController.position.haveDimensions
                  ? _pageController.page
                  : null;
              final value = page == null
                  ? (index == _firstFavoritePage ? 1.0 : 0.70)
                  : (1 - ((page - index).abs() * 0.30)).clamp(0.0, 1.0);
              final opacity = value.clamp(0.40, 1.0);
              return Center(
                child: Transform.scale(
                  scale: Curves.easeOut.transform(value),
                  child: Opacity(
                    opacity: opacity,
                    child: _buildFavoriteCard(child, opacity: opacity),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(Widget? child, {double opacity = 1}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15 * opacity),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _buildFavoritePhoto(UserSpot spot) {
    final carName = spot.carModel.value?.name ?? "Supercar ❤️";
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. FOTO AUTO REALE SALVATA SUL DISPOSITIVO
        spot.imagePath.isNotEmpty
            ? Image.file(
                File(spot.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallbackCarIcon(),
              )
            : _buildFallbackCarIcon(),

        // 2. GRADIENTE SCURO PROTETTIVO PER LEGGIBILITÀ DEL TESTO
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    carName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.favorite, color: Color(0xFF10B981), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAppBar() {
    return SystemNavigationBar(
      child: BottomAppBar(
        color: Colors.white,
        elevation: 16,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomAction(
                icon: Icons.directions_car,
                label: 'Garage',
                destination: const GarageScreen(),
              ),
              const SizedBox(width: 40),
              _buildBottomAction(
                icon: Icons.bar_chart_outlined,
                label: 'Catalogo',
                destination: const CatalogScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required Widget destination,
  }) {
    const color = Color(0xFF10B981);
    return InkWell(
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => destination));
        if (mounted) _loadData();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET MARQUEE TEXT: Scorre avanti, pausa 2s, torna indietro, pausa 2s
// ============================================================================
class _MarqueeText extends StatefulWidget {
  final String text;
  const _MarqueeText({required this.text});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(
            milliseconds: (maxScroll * 40).toInt().clamp(1000, 4000),
          ),
          curve: Curves.easeInOut,
        );

        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          0.0,
          duration: Duration(
            milliseconds: (maxScroll * 40).toInt().clamp(1000, 4000),
          ),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}
