import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

const spotMapWater = Color(0xFFD6E8EA);
const _landColor = Color(0xFFF3F0E5);
const _tileExtent = 65535.0;
const _minimumLocalZoom = 10.0;

class OfflineSpotBasemap extends StatelessWidget {
  const OfflineSpotBasemap({super.key});

  static final _data = _loadData();

  static Future<_BasemapData> _loadData() async {
    final bytes = await rootBundle.load(
      'assets/maps/natural_earth_tiles.bin.gz',
    );
    return compute(_decodeBasemap, Uint8List.sublistView(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BasemapData>(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();

        final camera = MapCamera.of(context);
        final viewport = Offset.zero & camera.nonRotatedSize;
        if (viewport.isEmpty) return const SizedBox.shrink();

        final grid = camera.zoom < 6 ? data.overview : data.details;
        final tileSize = camera.getWorldWidthAtZoom() / grid.dimension;
        final unitsToPixels = tileSize / _tileExtent;
        final origin = camera.projectAtZoom(camera.center) - viewport.center;
        final tiles = grid.visibleTiles(origin, viewport.size, tileSize);
        final candidates = <_VisibleCity>[];
        for (final entry in tiles) {
          _collectLabels(
            candidates,
            entry.tile.cities,
            entry.position,
            viewport,
            camera.zoom,
            unitsToPixels,
          );
        }
        if (camera.zoom >= _minimumLocalZoom) {
          final localTileSize =
              camera.getWorldWidthAtZoom() / data.places.dimension;
          for (final entry in data.places.visibleTiles(
            origin,
            viewport.size,
            localTileSize,
          )) {
            _collectLabels(
              candidates,
              entry.tile,
              entry.position,
              viewport,
              camera.zoom,
              localTileSize / _tileExtent,
            );
          }
        }
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _BasemapPainter(
                  tiles: tiles,
                  data: data,
                  unitsToPixels: unitsToPixels,
                  showRoads: camera.zoom >= 7,
                ),
              ),
              ..._cityLabels(candidates),
            ],
          ),
        );
      },
    );
  }
}

typedef _City = ({Offset position, int priority, double minZoom, String name});
typedef _VisibleTile<T> = ({T tile, Offset position});
typedef _VisibleCity = ({_City city, Offset position});

class _BasemapTile {
  const _BasemapTile({
    required this.solidLand,
    required this.land,
    required this.lakes,
    required this.borders,
    required this.roads,
    required this.cities,
  });

  final bool solidLand;
  final Uint16List land;
  final Uint16List lakes;
  final Uint16List borders;
  final Uint16List roads;
  final List<_City> cities;
}

class _TileGrid<T> {
  const _TileGrid(this.dimension, this.tiles);

  final int dimension;
  final Map<int, T> tiles;

  List<_VisibleTile<T>> visibleTiles(
    Offset origin,
    Size size,
    double tileSize,
  ) {
    final firstColumn = (origin.dx / tileSize).floor();
    final endColumn = ((origin.dx + size.width) / tileSize).ceil();
    final firstRow = math.max(0, (origin.dy / tileSize).floor());
    final endRow = math.min(
      dimension,
      ((origin.dy + size.height) / tileSize).ceil(),
    );

    final visible = <_VisibleTile<T>>[];
    for (var row = firstRow; row < endRow; row++) {
      for (var column = firstColumn; column < endColumn; column++) {
        final tile = tiles[row * dimension + column % dimension];
        if (tile == null) continue;
        visible.add((
          tile: tile,
          position: Offset(
            column * tileSize - origin.dx,
            row * tileSize - origin.dy,
          ),
        ));
      }
    }
    return visible;
  }
}

class _BasemapData {
  _BasemapData(this.overview, this.details, this.places);

  final _TileGrid<_BasemapTile> overview;
  final _TileGrid<_BasemapTile> details;
  final _TileGrid<List<_City>> places;
  final _meshCache = <_BasemapTile, _TileMesh>{};

  _TileMesh meshFor(_BasemapTile tile) {
    final mesh = _meshCache.remove(tile) ?? _TileMesh(tile);
    _meshCache[tile] = mesh;
    if (_meshCache.length > 96) {
      _meshCache.remove(_meshCache.keys.first)?.dispose();
    }
    return mesh;
  }
}

class _TileMesh {
  _TileMesh(_BasemapTile tile)
    : land = _vertices(tile.land),
      lakes = _vertices(tile.lakes),
      borders = _points(tile.borders),
      roads = _points(tile.roads);

  final ui.Vertices? land;
  final ui.Vertices? lakes;
  final Float32List borders;
  final Float32List roads;

  static ui.Vertices? _vertices(Uint16List coordinates) => coordinates.isEmpty
      ? null
      : ui.Vertices.raw(ui.VertexMode.triangles, _points(coordinates));

  static Float32List _points(Uint16List coordinates) {
    final points = Float32List(coordinates.length);
    for (var i = 0; i < coordinates.length; i++) {
      points[i] = coordinates[i].toDouble();
    }
    return points;
  }

  void dispose() {
    land?.dispose();
    lakes?.dispose();
  }
}

// Geometry and GeoNames labels are indexed by tool/build_spot_basemap.py.
_BasemapData _decodeBasemap(Uint8List compressed) {
  final decoded = gzip.decode(compressed);
  final bytes = decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
  if (ascii.decode(bytes.sublist(0, 4)) != 'CSM2') {
    throw const FormatException('Unsupported offline map format');
  }
  final reader = _TileReader(bytes);
  return _BasemapData(
    reader.readGrid(),
    reader.readGrid(),
    reader.readPlaces(),
  );
}

class _TileReader {
  _TileReader(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int _offset = 4;

  int _uint16() {
    final value = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int _uint32() {
    final value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  Uint16List _coordinates() {
    final length = _uint32();
    final end = _offset + length * 2;
    final values = Uint16List.sublistView(_bytes, _offset, end);
    _offset = end;
    return values;
  }

  _City _city() {
    final x = _uint16();
    final y = _uint16();
    final priority = _uint16();
    final minZoom = _uint16() / 10;
    final length = _uint16();
    final end = _offset + length;
    final name = utf8.decode(Uint8List.sublistView(_bytes, _offset, end));
    _offset = end + length % 2;
    return (
      position: Offset(x.toDouble(), y.toDouble()),
      priority: priority,
      minZoom: minZoom,
      name: name,
    );
  }

  List<_City> _cities() =>
      List.generate(_uint16(), (_) => _city(), growable: false);

  _TileGrid<_BasemapTile> readGrid() {
    final dimension = 1 << _uint16();
    final count = _uint16();
    final tiles = <int, _BasemapTile>{};
    for (var i = 0; i < count; i++) {
      final index = _uint16();
      tiles[index] = _BasemapTile(
        solidLand: _uint16() == 1,
        land: _coordinates(),
        lakes: _coordinates(),
        borders: _coordinates(),
        roads: _coordinates(),
        cities: _cities(),
      );
    }
    return _TileGrid(dimension, tiles);
  }

  _TileGrid<List<_City>> readPlaces() {
    final dimension = 1 << _uint16();
    final count = _uint16();
    return _TileGrid(dimension, {
      for (var i = 0; i < count; i++) _uint32(): _cities(),
    });
  }
}

class _BasemapPainter extends CustomPainter {
  const _BasemapPainter({
    required this.tiles,
    required this.data,
    required this.unitsToPixels,
    required this.showRoads,
  });

  final List<_VisibleTile<_BasemapTile>> tiles;
  final _BasemapData data;
  final double unitsToPixels;
  final bool showRoads;

  @override
  void paint(Canvas canvas, Size size) {
    final landPaint = Paint()
      ..color = _landColor
      ..isAntiAlias = false;
    final lakePaint = Paint()..color = spotMapWater;
    final borderPaint = Paint()
      ..color = const Color(0xFFBAB9AD)
      ..strokeWidth = 0.9 / unitsToPixels;
    final roadPaint = Paint()
      ..color = const Color(0xFFD7C49B)
      ..strokeWidth = 1.4 / unitsToPixels;
    final viewport = Offset.zero & size;
    final tileSize = _tileExtent * unitsToPixels;

    for (final entry in tiles) {
      final tile = entry.tile;
      final mesh = data.meshFor(tile);
      final land = mesh.land;
      final lakes = mesh.lakes;
      if (tile.solidLand) {
        final bounds = entry.position & Size.square(tileSize);
        canvas.drawRect(bounds.intersect(viewport), landPaint);
      }

      canvas.save();
      canvas.translate(entry.position.dx, entry.position.dy);
      canvas.scale(unitsToPixels);
      if (!tile.solidLand && land != null) {
        canvas.drawVertices(land, BlendMode.src, landPaint);
      }
      if (lakes != null) canvas.drawVertices(lakes, BlendMode.src, lakePaint);
      if (mesh.borders.isNotEmpty) {
        canvas.drawRawPoints(ui.PointMode.lines, mesh.borders, borderPaint);
      }
      if (showRoads && mesh.roads.isNotEmpty) {
        canvas.drawRawPoints(ui.PointMode.lines, mesh.roads, roadPaint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BasemapPainter oldDelegate) =>
      tiles != oldDelegate.tiles ||
      unitsToPixels != oldDelegate.unitsToPixels ||
      showRoads != oldDelegate.showRoads;
}

void _collectLabels(
  List<_VisibleCity> candidates,
  List<_City> cities,
  Offset tilePosition,
  Rect viewport,
  double zoom,
  double unitsToPixels,
) {
  for (final city in cities) {
    if (zoom < city.minZoom) continue;
    final position = tilePosition + city.position * unitsToPixels;
    if (viewport.contains(position)) {
      candidates.add((position: position, city: city));
    }
  }
}

Iterable<Widget> _cityLabels(List<_VisibleCity> candidates) sync* {
  candidates.sort((a, b) {
    final zoom = a.city.minZoom.compareTo(b.city.minZoom);
    return zoom == 0 ? a.city.priority.compareTo(b.city.priority) : zoom;
  });

  final occupied = <Rect>[];
  for (final candidate in candidates) {
    final bounds = Rect.fromCenter(
      center: candidate.position,
      width: (candidate.city.name.length * 6.0 + 12).clamp(36.0, 132.0),
      height: 22,
    );
    if (occupied.any(bounds.overlaps)) continue;
    occupied.add(bounds);
    yield Positioned.fromRect(
      rect: bounds,
      child: Center(
        child: Text(
          candidate.city.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF526465),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: _landColor, blurRadius: 3)],
          ),
        ),
      ),
    );
  }
}
