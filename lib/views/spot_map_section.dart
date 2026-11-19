import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/user_spot.dart';
import 'offline_spot_basemap.dart';
import 'spot_detail_screen.dart';
import 'system_navigation_bar.dart';

const _title = 'Mappa degli spot';
const _spotGreen = Color(0xFF10B981);
const _darkGreen = Color(0xFF067A58);
const _closeZoom = 17.0;
const _maximumZoom = 20.0;

class SpotMapSection extends StatelessWidget {
  const SpotMapSection({
    super.key,
    required this.spots,
    required this.onSpotChanged,
  });

  final List<UserSpot> spots;
  final Future<void> Function() onSpotChanged;

  @override
  Widget build(BuildContext context) {
    final hasLocations = spots.any(
      (spot) => _LocatedSpot.positionOf(spot) != null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              _title,
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Container(
            height: 254,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x100F172A),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _SpotsMap(
              key: ValueKey(hasLocations),
              spots: spots,
              onSpotChanged: onSpotChanged,
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Viewport = ({LatLng center, double zoom});

class _LocatedSpot {
  const _LocatedSpot(this.spot, this.position);

  final UserSpot spot;
  final LatLng position;

  String get name => spot.carModel.value?.name ?? 'Auto avvistata';

  static LatLng? positionOf(UserSpot spot) {
    final lat = spot.latitude;
    final lon = spot.longitude;
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      return null;
    }
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return LatLng(lat, lon == 180 ? -180 : lon);
  }

  static List<_LocatedSpot> fromSpots(List<UserSpot> spots) {
    final located = <_LocatedSpot>[];
    for (final spot in spots) {
      final position = positionOf(spot);
      if (position != null) located.add(_LocatedSpot(spot, position));
    }
    return located;
  }
}

class _SpotsMap extends StatefulWidget {
  const _SpotsMap({
    super.key,
    required this.spots,
    required this.onSpotChanged,
    this.embedded = false,
    this.initialViewport,
    this.onViewportChanged,
  });

  final List<UserSpot> spots;
  final Future<void> Function() onSpotChanged;
  final bool embedded;
  final _Viewport? initialViewport;
  final ValueChanged<_Viewport>? onViewportChanged;

  @override
  State<_SpotsMap> createState() => _SpotsMapState();
}

class _SpotsMapState extends State<_SpotsMap> {
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _expand() async {
    final camera = _controller.camera;
    final initial = (center: camera.center, zoom: camera.zoom);
    var viewport = initial;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          extendBody: true,
          backgroundColor: spotMapWater,
          bottomNavigationBar: const SystemNavigationBar(),
          appBar: AppBar(
            title: const Text(
              _title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
          ),
          body: _SpotsMap(
            spots: widget.spots,
            onSpotChanged: widget.onSpotChanged,
            initialViewport: initial,
            onViewportChanged: (next) => viewport = next,
          ),
        ),
      ),
    );
    if (mounted) {
      _controller.move(viewport.center, viewport.zoom);
    }
  }

  Future<void> _openSpot(_LocatedSpot located) async {
    final spot = located.spot;
    final openDetail = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 56,
                child: spot.imagePath.isEmpty
                    ? const _PhotoFallback()
                    : Image.file(
                        File(spot.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _PhotoFallback(),
                      ),
              ),
            ),
            title: Text(
              located.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Apri spot'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );
    if (openDetail != true || !mounted) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => SpotDetailScreen(spot: spot)),
    );
    if (updated == true && mounted) {
      // The detail screen updates the local spot itself. Refresh the full-screen
      // map and let the Home reload its stats and favorite cards from Isar.
      setState(() {});
      await widget.onSpotChanged();
    }
  }

  void _zoom(double delta) {
    final camera = _controller.camera;
    _controller.move(
      camera.center,
      (camera.zoom + delta).clamp(0.0, _maximumZoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spots = _LocatedSpot.fromSpots(widget.spots);
    final initial = widget.initialViewport;
    final first = spots.firstOrNull?.position;
    final fit = initial == null && spots.any((spot) => spot.position != first)
        ? CameraFit.coordinates(
            coordinates: [for (final spot in spots) spot.position],
            padding: const EdgeInsets.fromLTRB(66, 70, 66, 54),
            maxZoom: 14.5,
          )
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: initial?.center ?? first ?? const LatLng(42.5, 12.5),
            initialZoom: initial?.zoom ?? (spots.isEmpty ? 4.7 : 14.5),
            initialCameraFit: fit,
            minZoom: 0,
            maxZoom: _maximumZoom,
            backgroundColor: spotMapWater,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (camera, _) => widget.onViewportChanged?.call((
              center: camera.center,
              zoom: camera.zoom,
            )),
          ),
          children: [
            const OfflineSpotBasemap(),
            _SpotMarkers(spots: spots, onOpenSpot: _openSpot),
          ],
        ),
        const Positioned(
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.only(right: 10, bottom: 3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xE5FCFBF6),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: Text(
                    'GeoNames · CC BY 4.0',
                    style: TextStyle(color: Color(0xFF526465), fontSize: 9),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (spots.isEmpty)
          const Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: IgnorePointer(
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Material(
                    color: Color(0xFFFCFBF6),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    elevation: 1,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text('Nessuno spot con posizione'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (widget.embedded)
          Positioned(
            top: 10,
            right: 10,
            child: _MapButton(
              icon: Icons.fullscreen,
              label: 'Apri a schermo intero',
              onPressed: _expand,
            ),
          )
        else
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.add,
                  label: 'Aumenta zoom',
                  onPressed: () => _zoom(1),
                ),
                const SizedBox(height: 6),
                _MapButton(
                  icon: Icons.remove,
                  label: 'Riduci zoom',
                  onPressed: () => _zoom(-1),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE5F5EF),
      child: Icon(Icons.directions_car_filled_outlined, color: _darkGreen),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        icon: Icon(icon, color: _darkGreen),
        tooltip: label,
        onPressed: onPressed,
      ),
    );
  }
}

// The rectangles account for the name as well as the pin. Anchors that would
// overlap join a group at low zoom and get their own tap areas at close range.
const _markerWidth = 112.0;
const _markerHeight = 63.0;
const _markerClearance = Offset(_markerWidth + 2, _markerHeight + 2);
const _markerSpacing = Offset(_markerWidth + 4, _markerHeight + 4);
const _pinTipFromTop = 31.0;

class _PlacedMarker {
  _PlacedMarker(this.anchor, this.origin, this.spots);

  final Offset anchor;
  final Offset origin;
  final List<_LocatedSpot> spots;

  Rect get bounds => Rect.fromLTWH(
    anchor.dx - _markerWidth / 2,
    anchor.dy - _pinTipFromTop,
    _markerWidth,
    _markerHeight,
  );
}

class _MarkerPositions {
  final _cells = <(int, int), _PlacedMarker>{};

  Iterable<_PlacedMarker> get markers => _cells.values;

  (int, int) _cell(Offset point) => (
    (point.dx / _markerClearance.dx).floor(),
    (point.dy / _markerClearance.dy).floor(),
  );

  _PlacedMarker? overlapping(Offset point) {
    final (x, y) = _cell(point);
    for (var row = y - 1; row <= y + 1; row++) {
      for (var column = x - 1; column <= x + 1; column++) {
        final other = _cells[(column, row)];
        if (other == null) continue;
        final delta = point - other.anchor;
        if (delta.dx.abs() < _markerClearance.dx &&
            delta.dy.abs() < _markerClearance.dy) {
          return other;
        }
      }
    }
    return null;
  }

  void add(_PlacedMarker marker) => _cells[_cell(marker.anchor)] = marker;
}

Iterable<Offset> _surroundingPositions(Offset origin) sync* {
  // Walk wider rectangles so even a large stack of identical coordinates can
  // be opened into individually reachable pins by panning around the origin.
  for (var ring = 1; ; ring++) {
    for (var x = 0; x <= ring; x++) {
      for (final column in x == 0 ? [0] : [-x, x]) {
        yield origin +
            Offset(column * _markerSpacing.dx, -ring * _markerSpacing.dy);
        yield origin +
            Offset(column * _markerSpacing.dx, ring * _markerSpacing.dy);
      }
    }
    for (var y = 1 - ring; y < ring; y++) {
      yield origin + Offset(-ring * _markerSpacing.dx, y * _markerSpacing.dy);
      yield origin + Offset(ring * _markerSpacing.dx, y * _markerSpacing.dy);
    }
  }
}

class _SpotMarkers extends StatelessWidget {
  const _SpotMarkers({required this.spots, required this.onOpenSpot});

  final List<_LocatedSpot> spots;
  final ValueChanged<_LocatedSpot> onOpenSpot;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final viewport = Offset.zero & camera.nonRotatedSize;
    if (viewport.isEmpty) return const SizedBox.shrink();

    final positions = _MarkerPositions();
    final nextPositions = <Offset, Iterator<Offset>>{};
    final groupNearby = camera.zoom < _closeZoom;
    final worldWidth = camera.getWorldWidthAtZoom();
    for (final spot in spots) {
      final point = camera.latLngToScreenOffset(spot.position);
      final origin = point.translate(
        ((viewport.center.dx - point.dx) / worldWidth).round() * worldWidth,
        0,
      );
      final overlap = positions.overlapping(origin);
      if (overlap == null) {
        positions.add(_PlacedMarker(origin, origin, [spot]));
      } else if (groupNearby) {
        overlap.spots.add(spot);
      } else {
        final candidates = nextPositions.putIfAbsent(
          origin,
          () => _surroundingPositions(origin).iterator,
        );
        while (candidates.moveNext()) {
          final anchor = candidates.current;
          if (positions.overlapping(anchor) != null) continue;
          positions.add(_PlacedMarker(anchor, origin, [spot]));
          break;
        }
      }
    }

    final visible = positions.markers
        .where((marker) => viewport.overlaps(marker.bounds))
        .toList();
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: CustomPaint(painter: _PinConnectors(visible))),
        for (final marker in visible)
          if (marker.spots.length > 1)
            Positioned.fromRect(
              rect: Rect.fromCenter(
                center: marker.anchor,
                width: 48,
                height: 48,
              ),
              child: _SpotCluster(
                count: marker.spots.length,
                onTap: () {
                  final samePoint = marker.spots.every(
                    (spot) => spot.position == marker.spots.first.position,
                  );
                  final zoom = samePoint
                      ? _closeZoom
                      : math.min(_closeZoom, camera.zoom + 1.5);
                  MapController.of(
                    context,
                  ).move(camera.screenOffsetToLatLng(marker.anchor), zoom);
                },
              ),
            )
          else
            Positioned.fromRect(
              key: ValueKey(marker.spots.single.spot.id),
              rect: marker.bounds,
              child: _SpotPin(
                spot: marker.spots.single,
                onTap: () => onOpenSpot(marker.spots.single),
              ),
            ),
      ],
    );
  }
}

class _SpotCluster extends StatelessWidget {
  const _SpotCluster({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count spot vicini',
      button: true,
      child: Material(
        elevation: 2,
        color: _darkGreen,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotPin extends StatelessWidget {
  const _SpotPin({required this.spot, required this.onTap});

  final _LocatedSpot spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            const Icon(
              Icons.location_on,
              size: _pinTipFromTop,
              color: _spotGreen,
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFBF6),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFD5DFD6)),
                ),
                child: Text(
                  spot.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF173A32),
                    fontSize: 11,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
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

class _PinConnectors extends CustomPainter {
  const _PinConnectors(this.markers);

  final List<_PlacedMarker> markers;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _darkGreen.withValues(alpha: 0.65)
      ..strokeWidth = 1.25;
    for (final marker in markers) {
      if (marker.anchor == marker.origin) continue;
      canvas.drawLine(marker.origin, marker.anchor, paint);
      canvas.drawCircle(marker.origin, 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(_PinConnectors oldDelegate) =>
      oldDelegate.markers != markers;
}
