import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'system_navigation_bar.dart';

class TopographicScaffold extends StatelessWidget {
  const TopographicScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar = const SystemNavigationBar(),
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget bottomNavigationBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TopographicBackground.paper,
    appBar: appBar,
    body: TopographicBackground(child: body),
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation,
    bottomNavigationBar: bottomNavigationBar,
  );
}

class TopographicBackground extends StatelessWidget {
  const TopographicBackground({super.key, required this.child});

  static const paper = Color(0xFFF2F0E6);
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const RepaintBoundary(child: CustomPaint(painter: _Contours())),
      child,
    ],
  );
}

class _Contours extends CustomPainter {
  const _Contours();

  // Sample a continuous height field once. Each triangle contributes a line
  // segment wherever a contour crosses two of its edges.
  static final Path _lines = _buildContours();

  static Path _buildContours() {
    const columns = 72;
    const rows = 108;
    final path = Path();
    final heights = List.generate(rows + 1, (row) {
      final y = row / rows;
      return List.generate(columns + 1, (column) {
        final x = column / columns;
        return math.sin(17 * x + 1.7 * math.sin(14 * y)) +
            0.82 * math.cos(19 * y - 2.1 * math.sin(7 * x)) +
            0.48 * math.sin(13 * x + 26 * y);
      });
    });

    void trace(List<Offset> points, List<double> values) {
      const interval = 0.27;
      final low = values.reduce(math.min);
      final high = values.reduce(math.max);
      for (
        var index = (low / interval).floor() + 1;
        index * interval <= high;
        index++
      ) {
        final level = index * interval;
        Offset? start;
        for (var edge = 0; edge < 3; edge++) {
          final next = (edge + 1) % 3;
          final a = values[edge];
          final b = values[next];
          if ((a < level) == (b < level)) continue;
          final point = Offset.lerp(
            points[edge],
            points[next],
            (level - a) / (b - a),
          )!;
          if (start == null) {
            start = point;
          } else {
            path.moveTo(start.dx, start.dy);
            path.lineTo(point.dx, point.dy);
          }
        }
      }
    }

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final a = Offset(column / columns, row / rows);
        final b = Offset((column + 1) / columns, row / rows);
        final c = Offset(column / columns, (row + 1) / rows);
        final d = Offset((column + 1) / columns, (row + 1) / rows);
        final top = heights[row];
        final bottom = heights[row + 1];
        trace([a, b, c], [top[column], top[column + 1], bottom[column]]);
        trace([b, d, c], [top[column + 1], bottom[column + 1], bottom[column]]);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = TopographicBackground.paper);
    if (size.isEmpty) return;
    final lines = _lines.transform(
      (Matrix4.diagonal3Values(size.width, size.height, 1)).storage,
    );
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00988167),
          Color(0x65988167),
          Color(0x65988167),
          Color(0x20988167),
        ],
        stops: [0, 0.13, 0.88, 1],
      ).createShader(bounds);
    canvas.drawPath(lines, ink);
  }

  @override
  bool shouldRepaint(_Contours oldDelegate) => false;
}
