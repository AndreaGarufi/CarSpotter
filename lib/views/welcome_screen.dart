import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart'; //file della home
import '../controllers/backup_service.dart';
import '../controllers/db_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _exitController;
  late Animation<double> _exitLeftCarAnimation;
  late Animation<double> _exitRightCarAnimation;
  late Animation<double> _fadeElementsAnimation;

  // Controller e Timer per la lucentezza del pulsante
  late AnimationController _shineController;
  late Animation<double> _shineAnimation;
  Timer? _shineTimer;

  bool _isExiting = false;
  String? _username;

  @override
  void initState() {
    super.initState();

    // Carica il nome utente salvato in SharedPreferences
    _loadUsername();

    // Animazione idle continua per le forme geometriche di sfondo
    // Usiamo repeat semplice senza reverse per un ciclo orbitale/fluido infinito
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Animazione di uscita rapida al clic su "Inizia a spottare"
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _exitLeftCarAnimation = Tween<double>(begin: 0.0, end: -2.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOutCubic),
    );

    _exitRightCarAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOutCubic),
    );

    _fadeElementsAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Animazione del singolo passaggio di luce (durata: 1 secondo)
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _shineAnimation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );

    // =========================================================================
    // 👇 QUI IMPOSTI OGNI QUANTI SECONDI PARTE LA LUCENTEZZA DEL PULSANTE 👇
    // =========================================================================
    _shineTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && !_isExiting) {
        _shineController.forward(from: 0.0);
      }
    });
    // =========================================================================
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
    });
  }

  Future<void> _saveUsername(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      await prefs.remove('username');
      setState(() {
        _username = null;
      });
    } else {
      await prefs.setString('username', cleanName);
      setState(() {
        _username = cleanName;
      });
    }
  }

  void _showProfileDialog() {
    final textController = TextEditingController(text: _username ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Il tuo Nickname da Spotter",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            fontSize: 20,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          cursorColor: const Color(0xFF10B981),
          decoration: InputDecoration(
            hintText: "Es. Andrea",
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: const Color(0xFFEEEEE4).withValues(alpha: 0.4),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Annulla",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _saveUsername(textController.text);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "Salva",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      // Usiamo 'dialogContext' per non confonderlo con il context principale
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text("⚠️", style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              "Attenzione!",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          "Così eliminerai tutte le auto spottate dal database. Sei sicuro di voler continuare?",
          style: TextStyle(fontSize: 15, color: Color(0xFF555555)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              "Annulla",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // 1. Catturiamo il messaggero sicuro prima di chiudere il popup
              final messenger = ScaffoldMessenger.of(context);

              // 2. Chiudiamo il popup di conferma
              Navigator.of(dialogContext).pop();

              // 3. Mostriamo l'avviso di caricamento
              messenger.showSnackBar(
                const SnackBar(
                  content: Text("Pulizia del Garage in corso... 🧹"),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              // 4. Eseguiamo il RESET TOTALE!
              await DbService.resetDatabase();

              // 5. Avvisiamo l'utente del successo
              if (mounted) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      "✅ Database resettato con successo!",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "Conferma Reset",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // 👇 1. Rinominiamo il context in "sheetContext" per non confonderlo 👇
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12, bottom: 12),
                child: Text(
                  "Impostazioni",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.archive_outlined,
                    color: Color(0xFF10B981),
                  ),
                ),
                title: const Text(
                  "Esporta Backup Dati",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text("Salva il database e le foto in uno ZIP"),
                onTap: () async {
                  // 👇 2. Catturiamo il "Messaggero" della pagina principale PRIMA di chiudere il menù
                  final messenger = ScaffoldMessenger.of(context);

                  // 👇 3. Chiudiamo il menù usando il suo context specifico (sheetContext)
                  Navigator.pop(sheetContext);

                  // 4. Mostriamo l'avviso usando il messaggero sicuro salvato al punto 2
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            "Creazione backup in corso... 📦",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      duration: Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  // 5. Avvia la compressione ZIP in background
                  final success = await BackupService.exportBackup();

                  if (mounted) {
                    messenger.hideCurrentSnackBar(); // Rimuove il caricamento

                    if (success) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            "✅ Salvato nei Download e pronto da condividere!",
                          ),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            "❌ Si è verificato un errore durante il backup.",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),

              // 👇 [2] NUOVO BOTTONE: SINCRONIZZA CATALOGO 👇
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sync_rounded, color: Colors.blue),
                ),
                title: const Text(
                  "Sincronizza Catalogo",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "Cerca e aggiungi nuove auto dal file JSON",
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheetContext); // Chiude il menù

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            "Sincronizzazione in corso... 🔄",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      duration: Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  // Fa partire il motore e aspetta il conteggio delle auto inserite
                  final addedCount = await DbService.syncCatalogWithJson();

                  if (mounted) {
                    messenger.hideCurrentSnackBar();

                    if (addedCount >= 0) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            addedCount > 0
                                ? "✅ Catalogo aggiornato! Aggiunte $addedCount nuove auto."
                                : "✅ Il catalogo era già aggiornato. Nessuna novità.",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            "❌ Si è verificato un errore di lettura del JSON.",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
              // 👆 FINE NUOVO BOTTONE 👆
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: const Text(
                  "Reset Database",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text("Cancella tutte le auto salvate"),
                onTap: () {
                  Navigator.pop(context);
                  _showResetConfirmationDialog();
                },
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
              const SizedBox(height: 16),

              // Spazio informativo separato: info sulla natura local-first dell'app
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEE4).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "App local-first",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Database auto salvato in locale",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shineTimer?.cancel();
    _shineController.dispose();
    _idleController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _onStartPressed() async {
    if (_isExiting) return;
    setState(() {
      _isExiting = true;
    });

    _shineTimer?.cancel(); // Interrompe il timer del riflesso

    // Sfrecciata animata delle due auto verso i lati opposti
    await _exitController.forward();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determina il sottotitolo in base alla presenza del nome utente
    final subtitleText = (_username != null && _username!.isNotEmpty)
        ? "Pronto a spottare, $_username?"
        : "Snap, tag, and organize cars quickly.";

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEE4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header con icone Profilo e Impostazioni
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildHeaderIcon(
                              icon: Icons.person,
                              onTap: _showProfileDialog,
                            ),
                            const SizedBox(width: 12),
                            _buildHeaderIcon(
                              icon: Icons.settings,
                              onTap: _showSettingsBottomSheet,
                            ),
                          ],
                        ),
                      ),

                      // Titolo e sottotitolo dinamico
                      FadeTransition(
                        opacity: _fadeElementsAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "CarSpotter",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1A1A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitleText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF666666),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Area Centrale Grafica
                      Expanded(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _idleController,
                            _exitController,
                          ]),
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Sfondo geometrico origami continuo a ciclo infinito
                                FadeTransition(
                                  opacity: _fadeElementsAnimation,
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: _GeometricOrigamiPainter(
                                      animationValue: _idleController.value,
                                    ),
                                  ),
                                ),

                                // Auto Sinistra - ferma finché non si clicca
                                FractionalTranslation(
                                  translation: Offset(
                                    _exitLeftCarAnimation.value,
                                    0,
                                  ),
                                  child: Align(
                                    alignment: const Alignment(-0.80, 0.22),
                                    child: SizedBox(
                                      width: 145,
                                      child: Image.asset(
                                        'assets/images/car_left.png',
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _buildFallbackCarBox(
                                                  "car_left",
                                                ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Auto Destra - ferma finché non si clicca
                                FractionalTranslation(
                                  translation: Offset(
                                    _exitRightCarAnimation.value,
                                    0,
                                  ),
                                  child: Align(
                                    alignment: const Alignment(0.80, 0.26),
                                    child: SizedBox(
                                      width: 145,
                                      child: Image.asset(
                                        'assets/images/car_right.png',
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _buildFallbackCarBox(
                                                  "car_right",
                                                ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Call to Action con Lucentezza
                      FadeTransition(
                        opacity: _fadeElementsAnimation,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          child: ElevatedButton(
                            onPressed: _isExiting ? null : _onStartPressed,
                            clipBehavior: Clip.antiAlias,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              disabledBackgroundColor: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.8),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.4),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Contenuto del pulsante (Testo e Icona)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 24,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Inizia a spottare",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 22,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),

                                // Effetto Shimmer / Fascio di luce diagonale
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _shineAnimation,
                                    builder: (context, child) {
                                      return FractionalTranslation(
                                        translation: Offset(
                                          _shineAnimation.value,
                                          0,
                                        ),
                                        child: Transform.rotate(
                                          angle: 0.35,
                                          child: Container(
                                            width: 60,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFE8E6DF),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, size: 22, color: const Color(0xFF555555)),
        ),
      ),
    );
  }

  Widget _buildFallbackCarBox(String label) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

// Pittore "montagna di poligoni astratti", versione raffinata: stessa
// composizione a picco/montagna dell'originale (per restare fedeli allo
// stile che ti piace), ma con riempimenti sfumati invece che piatti,
// qualche sfaccettatura in più per dare più profondità, e piccoli
// riflessi luminosi sui bordi superiori in stile "vetro/cristallo".
class _GeometricOrigamiPainter extends CustomPainter {
  final double animationValue;

  _GeometricOrigamiPainter({required this.animationValue});

  // Riempimento sfumato invece che a tinta piatta: dà profondità e un
  // aspetto più "vetroso" ad ogni faccetta senza cambiarne il colore base.
  Paint _facetPaint(
    Path path, {
    required Color from,
    required Color to,
    double alphaFrom = 1.0,
    double alphaTo = 1.0,
  }) {
    final gradient = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        from.withValues(alpha: alphaFrom),
        to.withValues(alpha: alphaTo),
      ],
    );
    return Paint()
      ..style = PaintingStyle.fill
      ..shader = gradient.createShader(path.getBounds());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Convertiamo il valore dell'animazione da 0..1 ad angoli da 0 a 2*PI radianti
    final angle = animationValue * math.pi * 2;

    // Movimenti orbitali fluidi e continui basati su seni e coseni sfasati
    // (identici nello spirito all'originale, così il loop resta perfetto)
    final dx1 = math.sin(angle) * 7;
    final dy1 = math.cos(angle) * 5;

    final dx2 = math.cos(angle + 1) * 8;
    final dy2 = math.sin(angle + 1) * 6;

    final dx3 = math.sin(angle + 2) * 6;
    final dy3 = math.cos(angle + 2) * 7;

    final dx4 = math.cos(angle + 3.4) * 5;
    final dy4 = math.sin(angle + 3.4) * 4;

    // 1. Grande Base Scalena di Sfondo (ombra profonda della montagna)
    final path1 = Path()
      ..moveTo(center.dx - 180, center.dy + 160)
      ..lineTo(center.dx + 20 + dx1, center.dy - 190 + dy1)
      ..lineTo(center.dx + 160, center.dy + 10)
      ..close();
    canvas.drawPath(
      path1,
      _facetPaint(
        path1,
        from: const Color(0xFF011E17),
        to: const Color(0xFF043F2E),
        alphaFrom: 0.95,
        alphaTo: 0.85,
      ),
    );

    // 2. Cuneo Superiore Sinistro
    final path2 = Path()
      ..moveTo(center.dx - 150, center.dy + 20)
      ..lineTo(center.dx - 60 + dx2, center.dy - 160 + dy2)
      ..lineTo(center.dx + 40, center.dy - 40)
      ..lineTo(center.dx - 20, center.dy + 60)
      ..close();
    canvas.drawPath(
      path2,
      _facetPaint(
        path2,
        from: const Color(0xFF065F46),
        to: const Color(0xFF059669),
        alphaFrom: 0.9,
        alphaTo: 0.78,
      ),
    );

    // 3. Spigolo Estremo Sinistro (verde menta)
    final path3 = Path()
      ..moveTo(center.dx - 170, center.dy + 90)
      ..lineTo(center.dx - 80 + dx3, center.dy - 70 + dy3)
      ..lineTo(center.dx - 30, center.dy + 10)
      ..close();
    canvas.drawPath(
      path3,
      _facetPaint(
        path3,
        from: const Color(0xFF059669),
        to: const Color(0xFF6EE7B7),
        alphaFrom: 0.68,
        alphaTo: 0.55,
      ),
    );

    // 4. Prisma Centrale Scuro (ombra netta e dinamica)
    final path4 = Path()
      ..moveTo(center.dx - 70, center.dy + 40)
      ..lineTo(center.dx + 10 - dx1, center.dy - 80 - dy1)
      ..lineTo(center.dx + 140, center.dy + 120)
      ..lineTo(center.dx - 10, center.dy + 180)
      ..close();
    canvas.drawPath(
      path4,
      _facetPaint(
        path4,
        from: const Color(0xFF011E17),
        to: const Color(0xFF0F766E),
        alphaFrom: 0.97,
        alphaTo: 0.55,
      ),
    );

    // 5. Scheggia Destra Alta (verde giada brillante)
    final path5 = Path()
      ..moveTo(center.dx + dx2, center.dy - 140 + dy2)
      ..lineTo(center.dx + 160, center.dy - 50)
      ..lineTo(center.dx + 80, center.dy + 40)
      ..close();
    canvas.drawPath(
      path5,
      _facetPaint(
        path5,
        from: const Color(0xFF059669),
        to: const Color(0xFF10B981),
        alphaFrom: 0.85,
        alphaTo: 0.7,
      ),
    );

    // 6. Triangolo Inferiore Destro (teal trasparente)
    final path6 = Path()
      ..moveTo(center.dx - 130, center.dy + 120)
      ..lineTo(center.dx + 60 + dx3, center.dy + 30 + dy3)
      ..lineTo(center.dx + 110, center.dy + 170)
      ..close();
    canvas.drawPath(
      path6,
      _facetPaint(
        path6,
        from: const Color(0xFF115E59),
        to: const Color(0xFF0F766E),
        alphaFrom: 0.75,
        alphaTo: 0.6,
      ),
    );

    // 7. Frammento Affilato Superiore (acquamarina chiaro)
    final path7 = Path()
      ..moveTo(center.dx - 40, center.dy - 110)
      ..lineTo(center.dx + 70 - dx1, center.dy - 160 - dy1)
      ..lineTo(center.dx + 90, center.dy - 80)
      ..close();
    canvas.drawPath(
      path7,
      _facetPaint(
        path7,
        from: const Color(0xFF34D399),
        to: const Color(0xFF6EE7B7),
        alphaFrom: 0.68,
        alphaTo: 0.5,
      ),
    );

    // 8. Lama Geometrica Inferiore Sinistra (smeraldo scuro)
    final path8 = Path()
      ..moveTo(center.dx - 140, center.dy - 30)
      ..lineTo(center.dx - 10 + dx2, center.dy + 130 + dy2)
      ..lineTo(center.dx - 160, center.dy + 180)
      ..close();
    canvas.drawPath(
      path8,
      _facetPaint(
        path8,
        from: const Color(0xFF043F2E),
        to: const Color(0xFF065F46),
        alphaFrom: 0.9,
        alphaTo: 0.78,
      ),
    );

    // 9. Scheggia di Accento Centrale (verde chiaro intenso)
    final path9 = Path()
      ..moveTo(center.dx - 20 - dx3, center.dy - 20 - dy3)
      ..lineTo(center.dx + 50, center.dy - 90)
      ..lineTo(center.dx + 30, center.dy + 20)
      ..close();
    canvas.drawPath(
      path9,
      _facetPaint(
        path9,
        from: const Color(0xFF6EE7B7),
        to: const Color(0xFFA7F3D0),
        alphaFrom: 0.6,
        alphaTo: 0.45,
      ),
    );

    // 10. Triangolo Asimmetrico Estremo Destro (blu ottanio)
    final path10 = Path()
      ..moveTo(center.dx + 50, center.dy + 70)
      ..lineTo(center.dx + 170 + dx1, center.dy + 30 + dy1)
      ..lineTo(center.dx + 120, center.dy + 150)
      ..close();
    canvas.drawPath(
      path10,
      _facetPaint(
        path10,
        from: const Color(0xFF115E59),
        to: const Color(0xFF0F766E),
        alphaFrom: 0.85,
        alphaTo: 0.65,
      ),
    );

    // 11. Cuneo di Chiusura Inferiore (verde foresta)
    final path11 = Path()
      ..moveTo(center.dx - 50, center.dy + 150)
      ..lineTo(center.dx + 40 - dx2, center.dy + 90 - dy2)
      ..lineTo(center.dx + 70, center.dy + 190)
      ..close();
    canvas.drawPath(
      path11,
      _facetPaint(
        path11,
        from: const Color(0xFF043F2E),
        to: const Color(0xFF064E3B),
        alphaFrom: 0.93,
        alphaTo: 0.8,
      ),
    );

    // -------------------------------------------------------------------
    // Faccette aggiuntive: due tasselli in più per dare più profondità e
    // "riempire" meglio la composizione, senza alterarne la sagoma.
    // -------------------------------------------------------------------
    // 12. Cuneo Superiore Destro (nuovo, tra la scheggia 5 e il triangolo 10)
    final path12 = Path()
      ..moveTo(center.dx + 60, center.dy - 10 + dy4)
      ..lineTo(center.dx + 130 + dx4, center.dy - 60)
      ..lineTo(center.dx + 150, center.dy + 60)
      ..close();
    canvas.drawPath(
      path12,
      _facetPaint(
        path12,
        from: const Color(0xFF0F766E),
        to: const Color(0xFF34D399),
        alphaFrom: 0.55,
        alphaTo: 0.4,
      ),
    );

    // 13. Piccolo Cuneo Inferiore Centrale (nuovo, dà più texture alla base)
    final path13 = Path()
      ..moveTo(center.dx - 100 + dx4, center.dy + 130)
      ..lineTo(center.dx - 20, center.dy + 100 - dy4)
      ..lineTo(center.dx - 40, center.dy + 175)
      ..close();
    canvas.drawPath(
      path13,
      _facetPaint(
        path13,
        from: const Color(0xFF064E3B),
        to: const Color(0xFF10B981),
        alphaFrom: 0.7,
        alphaTo: 0.5,
      ),
    );

    // -------------------------------------------------------------------
    // Piccoli bagliori "a cristallo" sulle punte: 3 schegge di luce che
    // pulsano dolcemente, come riflessi di luce su spigoli di vetro.
    // -------------------------------------------------------------------
    final sparklePaint = Paint()..style = PaintingStyle.fill;

    void drawSparkle(Offset tip, double size, double twinklePhase) {
      final twinkle = 0.35 + math.sin(angle * 2 + twinklePhase) * 0.18;
      final sparklePath = Path()
        ..moveTo(tip.dx, tip.dy - size)
        ..lineTo(tip.dx + size * 0.4, tip.dy)
        ..lineTo(tip.dx, tip.dy + size)
        ..lineTo(tip.dx - size * 0.4, tip.dy)
        ..close();
      sparklePaint.color = Colors.white.withValues(alpha: twinkle);
      canvas.drawPath(sparklePath, sparklePaint);
    }

    drawSparkle(Offset(center.dx + 20 + dx1, center.dy - 190 + dy1), 10, 0);
    drawSparkle(Offset(center.dx - 80 + dx3, center.dy - 70 + dy3), 7, 2.1);
    drawSparkle(Offset(center.dx + 160, center.dy - 50), 8, 4.2);

    // -------------------------------------------------------------------
    // Sottili riflessi lungo i due spigoli più alti: una linea di luce
    // molto tenue in stile vetro/cristallo, senza appesantire il disegno.
    // -------------------------------------------------------------------
    final edgeHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.18);

    canvas.drawLine(
      Offset(center.dx - 180, center.dy + 160),
      Offset(center.dx + 20 + dx1, center.dy - 190 + dy1),
      edgeHighlight,
    );
    canvas.drawLine(
      Offset(center.dx - 60 + dx2, center.dy - 160 + dy2),
      Offset(center.dx + 40, center.dy - 40),
      edgeHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant _GeometricOrigamiPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
