import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' show Uint32List;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class GlobeCountry {
  const GlobeCountry({
    required this.code,
    required this.name,
    required this.longitude,
    required this.latitude,
  });

  final String code;
  final String name;
  final double longitude;
  final double latitude;
}

class GlobeGeometry {
  const GlobeGeometry._(
    this.countries,
    this._tileSize,
    this._countryIds,
    this._borders,
  );

  final List<GlobeCountry> countries;
  final int _tileSize;
  final Uint8List _countryIds;
  final Uint8List _borders;

  static final Future<GlobeGeometry> loaded = _load();

  static Future<GlobeGeometry> _load() async {
    final asset = await rootBundle.load(
      'assets/maps/natural_earth_globe.bin.gz',
    );
    return compute(_decodeGlobe, Uint8List.sublistView(asset));
  }

  Future<ui.Image> _createTexture(Set<String> unlocked) async {
    // Each country has a fill and a border color. Ocean pixels use index zero.
    final palette = Uint32List((countries.length + 1) * 2);
    palette[0] = palette[1] = 0xFFD9E8F8;
    for (var i = 0; i < countries.length; i++) {
      final active = unlocked.contains(countries[i].code);
      final index = 2 * (i + 1);
      // rgba8888 bytes in little-endian order.
      palette[index] = active ? 0xFF3D6730 : 0xFFD0D2D8;
      palette[index + 1] = active ? 0xFF34502B : 0xFF8E99A4;
    }
    final pixels = await compute(_paintAtlas, (
      ids: _countryIds,
      borders: _borders,
      palette: palette,
    ));
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    try {
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: _tileSize * 3,
        height: _tileSize * 2,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      try {
        final codec = await descriptor.instantiateCodec();
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  GlobeCountry? _countryAt(double x, double y, double z) {
    final absX = x.abs();
    final absY = y.abs();
    final absZ = z.abs();
    // Keep face order and orientation in sync with spot_globe.frag.
    final (int face, double u, double v) = switch ((x, y, z)) {
      _ when absX >= absY && absX >= absZ =>
        x > 0 ? (0, -z / absX, -y / absX) : (1, z / absX, -y / absX),
      _ when absY >= absZ =>
        y > 0 ? (2, x / absY, z / absY) : (3, x / absY, -z / absY),
      _ => z > 0 ? (4, x / absZ, -y / absZ) : (5, -x / absZ, -y / absZ),
    };
    final faceSize = _tileSize - 2;
    final column = face % 3 * _tileSize + 1 + ((u + 1) * faceSize / 2).floor();
    final row = face ~/ 3 * _tileSize + 1 + ((v + 1) * faceSize / 2).floor();
    final id = _countryIds[row * (_tileSize * 3) + column];
    return id == 0 ? null : countries[id - 1];
  }
}

GlobeGeometry _decodeGlobe(Uint8List compressed) {
  final decoded = gzip.decode(compressed);
  final bytes = decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
  if (ascii.decode(bytes.sublist(0, 4)) != 'CSG2') {
    throw const FormatException('Unsupported globe atlas format');
  }
  final data = ByteData.sublistView(bytes);
  int uint16(int offset) => data.getUint16(offset, Endian.little);
  int int16(int offset) => data.getInt16(offset, Endian.little);

  final countryCount = uint16(4);
  final tileSize = uint16(6);
  var offset = 8;
  final countries = <GlobeCountry>[];
  for (var i = 0; i < countryCount; i++) {
    final length = uint16(offset + 4);
    countries.add(
      GlobeCountry(
        code: ascii
            .decode(bytes.sublist(offset, offset + 3))
            .split('\u0000')
            .first,
        name: utf8.decode(bytes.sublist(offset + 10, offset + 10 + length)),
        longitude: int16(offset + 6) * math.pi / 18000,
        latitude: int16(offset + 8) * math.pi / 18000,
      ),
    );
    offset += 10 + length;
  }

  final layerSize = 6 * tileSize * tileSize;
  return GlobeGeometry._(
    countries,
    tileSize,
    Uint8List.sublistView(bytes, offset, offset + layerSize),
    Uint8List.sublistView(bytes, offset + layerSize, offset + 2 * layerSize),
  );
}

Uint8List _paintAtlas(
  ({Uint8List ids, Uint8List borders, Uint32List palette}) atlas,
) {
  final pixels = Uint32List(atlas.ids.length);
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = atlas.palette[2 * atlas.ids[i] + atlas.borders[i]];
  }
  return Uint8List.sublistView(pixels);
}

class SpotGlobe extends StatefulWidget {
  const SpotGlobe({
    super.key,
    required this.geometry,
    required this.unlockedCountries,
    required this.onCountrySelected,
    this.initialCountry,
    this.countryPanelOpen = false,
  });

  static const viewportInset = 12.0;
  static const maximumDiameter = 560.0;
  static const panelTransitionDuration = Duration(milliseconds: 300);

  final GlobeGeometry geometry;
  final Set<String> unlockedCountries;
  final GlobeCountry? initialCountry;
  final ValueChanged<GlobeCountry> onCountrySelected;
  final bool countryPanelOpen;

  @override
  State<SpotGlobe> createState() => _SpotGlobeState();
}

class _SpotGlobeState extends State<SpotGlobe> with TickerProviderStateMixin {
  static final _program = ui.FragmentProgram.fromAsset(
    'shaders/spot_globe.frag',
  );
  late final _GlobeCamera _camera;
  late final Ticker _intro;
  late final AnimationController _panelZoom;
  late Future<void> _textureWork;
  ui.FragmentShader? _shader;
  ui.Image? _texture;
  int _textureRevision = 0;
  bool _introStopped = false;
  int _introFrame = 0;
  double _zoomAtGestureStart = _GlobeCamera.initialZoom;
  double _zoomBeforePanel = _GlobeCamera.overviewZoom;

  @override
  void initState() {
    super.initState();
    final country = widget.initialCountry;
    _camera = _GlobeCamera(
      longitude: country?.longitude ?? 0.26,
      latitude: country?.latitude ?? 0.54,
    );
    final startLongitude = _camera.longitude;
    _intro = createTicker((elapsed) {
      if (elapsed >= const Duration(seconds: 25)) {
        _stopIntro();
        return;
      }
      final frame =
          elapsed.inMicroseconds * 30 ~/ Duration.microsecondsPerSecond;
      if (frame == _introFrame) return;
      _introFrame = frame;
      _camera.update(longitude: startLongitude + frame * math.pi / 1200);
    });
    _panelZoom =
        AnimationController(
          vsync: this,
          duration: SpotGlobe.panelTransitionDuration,
        )..addListener(() {
          _camera.update(
            zoom: ui.lerpDouble(
              _zoomBeforePanel,
              _GlobeCamera.overviewZoom,
              Curves.easeInOutCubic.transform(_panelZoom.value),
            ),
          );
        });
    _textureWork = _loadTexture();
  }

  @override
  void didUpdateWidget(SpotGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.countryPanelOpen &&
        !oldWidget.countryPanelOpen &&
        _camera.zoom > _GlobeCamera.overviewZoom) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _camera.update(zoom: _GlobeCamera.overviewZoom);
      } else {
        _zoomBeforePanel = _camera.zoom;
        _panelZoom.forward(from: 0);
      }
    }
    if (oldWidget.geometry != widget.geometry ||
        !setEquals(oldWidget.unlockedCountries, widget.unlockedCountries)) {
      _textureWork = _loadTexture();
    }
  }

  Future<void> _loadTexture() async {
    final revision = ++_textureRevision;
    final geometry = widget.geometry;
    final unlocked = widget.unlockedCountries;
    final program = await _program;
    if (!mounted || revision != _textureRevision) return;
    final texture = await geometry._createTexture(unlocked);
    if (!mounted || revision != _textureRevision) {
      texture.dispose();
      return;
    }
    final shader = _shader ??= program.fragmentShader();
    shader.setImageSampler(0, texture, filterQuality: ui.FilterQuality.low);
    final previous = _texture;
    _texture = texture;
    previous?.dispose();
    _camera.notifyTextureChanged();
    if (previous == null &&
        !_introStopped &&
        !MediaQuery.disableAnimationsOf(context)) {
      _intro.start();
    }
  }

  void _stopIntro() {
    _introStopped = true;
    _intro.stop();
  }

  @override
  void dispose() {
    _intro.dispose();
    _panelZoom.dispose();
    _camera.dispose();
    _shader?.dispose();
    _texture?.dispose();
    super.dispose();
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    final radius = _camera.radius(size);
    if (radius <= 0) return;
    final zoom = (_zoomAtGestureStart * details.scale).clamp(
      _GlobeCamera.minZoom,
      _GlobeCamera.maxZoom,
    );
    final movement = details.focalPointDelta;
    // For a pinch over the surface, keep the same geographic point under
    // the fingers while the radius changes. At the horizon, use normal drag.
    if (details.pointerCount > 1 && zoom != _camera.zoom) {
      final distance = details.localFocalPoint - size.center(Offset.zero);
      final previous = (distance - movement) / radius;
      final current = distance / _camera.radius(size, atZoom: zoom);
      if (previous.distanceSquared < 0.98 && current.distanceSquared < 0.98) {
        _camera.zoomAround(previous, current, zoom);
        return;
      }
    }
    final delta = movement / radius;
    _camera.update(
      longitude: (_camera.longitude - delta.dx) % (2 * math.pi),
      latitude: (_camera.latitude + delta.dy).clamp(-math.pi / 2, math.pi / 2),
      zoom: zoom,
    );
  }

  void _selectAt(Offset localPosition, Size size) {
    final radius = _camera.radius(size);
    if (_texture == null || radius <= 0) return;
    final point = (localPosition - size.center(Offset.zero)) / radius;
    if (point.distanceSquared > 1) return;

    final (x, y, z) = _camera.worldAt(point);
    final country = widget.geometry._countryAt(x, y, z);
    if (country != null && widget.unlockedCountries.contains(country.code)) {
      widget.onCountrySelected(country);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Globo interattivo',
      hint: 'Trascina per ruotare. Usa due dita per ingrandire.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Listener(
            onPointerDown: (_) {
              _stopIntro();
              _panelZoom.stop();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) => _zoomAtGestureStart = _camera.zoom,
              onScaleUpdate: (details) => _onScaleUpdate(details, size),
              onTapUp: (details) => _selectAt(details.localPosition, size),
              child: FutureBuilder<void>(
                future: _textureWork,
                builder: (context, snapshot) {
                  final shader = _shader;
                  if (shader == null) {
                    return Center(
                      child: snapshot.hasError
                          ? const Text('Impossibile caricare il globo.')
                          : const CircularProgressIndicator(),
                    );
                  }
                  return RepaintBoundary(
                    child: CustomPaint(
                      painter: _GlobePainter(
                        _camera,
                        shader,
                        widget.geometry._tileSize,
                      ),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlobeCamera extends ChangeNotifier {
  _GlobeCamera({required this.longitude, required this.latitude});

  static const initialZoom = 0.80;
  static const minZoom = 0.55;
  static const overviewZoom = 1.0;
  static const maxZoom = 1.75 * overviewZoom;
  double longitude;
  double latitude;
  double zoom = initialZoom;

  double radius(Size size, {double? atZoom}) {
    final diameter = math.min(
      SpotGlobe.maximumDiameter,
      size.shortestSide - 2 * SpotGlobe.viewportInset,
    );
    // Leave room for the shadow and silhouette at overview zoom.
    return math.max(0.0, (diameter / 2 - 2) / 1.06) * (atZoom ?? zoom);
  }

  (double, double, double) worldAt(Offset point) {
    final depth = math.sqrt(1 - point.distanceSquared);
    final sinLon = math.sin(longitude);
    final cosLon = math.cos(longitude);
    final sinLat = math.sin(latitude);
    final cosLat = math.cos(latitude);
    final rotatedZ = depth * cosLat + point.dy * sinLat;
    return (
      point.dx * cosLon + rotatedZ * sinLon,
      depth * sinLat - point.dy * cosLat,
      rotatedZ * cosLon - point.dx * sinLon,
    );
  }

  void zoomAround(Offset previous, Offset next, double newZoom) {
    final (x, y, z) = worldAt(previous);
    final depth = math.sqrt(1 - next.distanceSquared);
    final phase = math.atan2(-next.dy, depth);
    final vertical = math.sqrt(1 - next.dx * next.dx);
    final angle = math.asin((y / vertical).clamp(-1.0, 1.0));
    // Both solutions have the same projected latitude. Pick the one nearest
    // to the current camera tilt so pinching near a pole won't flip the globe.
    const fullTurn = 2 * math.pi;
    const pole = math.pi / 2;
    final first = (angle - phase).clamp(-pole, pole);
    final second = ((fullTurn - angle - phase) % fullTurn - math.pi).clamp(
      -pole,
      pole,
    );
    final nextLatitude = (first - latitude).abs() <= (second - latitude).abs()
        ? first
        : second;
    final rotatedZ =
        depth * math.cos(nextLatitude) + next.dy * math.sin(nextLatitude);
    update(
      longitude: (math.atan2(x, z) - math.atan2(next.dx, rotatedZ)) % fullTurn,
      latitude: nextLatitude,
      zoom: newZoom,
    );
  }

  void update({double? longitude, double? latitude, double? zoom}) {
    longitude ??= this.longitude;
    latitude ??= this.latitude;
    zoom ??= this.zoom;
    if (longitude == this.longitude &&
        latitude == this.latitude &&
        zoom == this.zoom) {
      return;
    }
    this.longitude = longitude;
    this.latitude = latitude;
    this.zoom = zoom;
    notifyListeners();
  }

  void notifyTextureChanged() => notifyListeners();
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this.camera, this.shader, this.tileSize)
    : super(repaint: camera);

  final _GlobeCamera camera;
  final ui.FragmentShader shader;
  final int tileSize;
  late final Paint _surface = Paint()..shader = shader;
  static final _shadow = Paint()
    ..shader = ui.Gradient.radial(Offset.zero, 1, const [
      Color(0x380C2018),
      Color(0x000C2018),
    ]);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = camera.radius(size);
    if (radius <= 0 || !radius.isFinite) return;
    final center = size.center(Offset.zero);
    canvas.save();
    if (camera.zoom <= _GlobeCamera.overviewZoom) {
      canvas.save();
      canvas.translate(center.dx + 0.04 * radius, center.dy + 0.98 * radius);
      canvas.scale(0.76 * radius, 0.08 * radius);
      canvas.drawCircle(Offset.zero, 1, _shadow);
      canvas.restore();
    } else {
      canvas.clipRect(Offset.zero & size);
    }

    shader
      ..setFloat(0, center.dx)
      ..setFloat(1, center.dy)
      ..setFloat(2, radius)
      ..setFloat(3, tileSize.toDouble())
      ..setFloat(4, math.cos(camera.longitude))
      ..setFloat(5, math.sin(camera.longitude))
      ..setFloat(6, math.cos(camera.latitude))
      ..setFloat(7, math.sin(camera.latitude));
    canvas.drawCircle(center, radius, _surface);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) =>
      camera != oldDelegate.camera ||
      shader != oldDelegate.shader ||
      tileSize != oldDelegate.tileSize;
}
