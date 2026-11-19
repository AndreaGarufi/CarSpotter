import 'dart:math' as math;

import 'package:car_spotter/models/brand.dart';
import 'package:car_spotter/models/car_model.dart';
import 'package:car_spotter/models/user_spot.dart';
import 'package:car_spotter/views/spot_globe.dart';
import 'package:car_spotter/views/spot_origins_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserSpot _spot(Brand brand) {
  final model = CarModel()..brand.value = brand;
  return UserSpot()..carModel.value = model;
}

Future<void> _showOrigins(WidgetTester tester, List<UserSpot> spots) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(home: SpotOriginsScreen(spots: spots)));
    final loader = tester.widget<FutureBuilder<Object>>(
      find.byWidgetPredicate((widget) => widget is FutureBuilder<Object>),
    );
    await loader.future;
    await tester.pump();
    final texture = tester.widget<FutureBuilder<void>>(
      find.descendant(
        of: find.byType(SpotGlobe),
        matching: find.byType(FutureBuilder<void>),
      ),
    );
    await texture.future;
  });
  await tester.pump();
}

void main() {
  testWidgets('L’Italia apre il pannello con i marchi e tutti i loro spot', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.reset);

    final ferrari = Brand()
      ..id = 1
      ..name = 'Ferrari';
    final fiat = Brand()
      ..id = 2
      ..name = 'Fiat';
    final audi = Brand()
      ..id = 3
      ..name = 'Audi';
    await _showOrigins(tester, [
      _spot(ferrari),
      _spot(fiat),
      _spot(ferrari),
      _spot(audi),
    ]);

    final globe = find.byType(SpotGlobe);
    final start = tester.getRect(globe);
    expect(find.text('Italia'), findsNothing);
    await tester.tapAt(start.center);
    await tester.pump();
    final panelTitle = find.text('Italia');
    expect(tester.getTopLeft(panelTitle).dx, greaterThan(390));
    await tester.pumpAndSettle();

    expect(tester.getCenter(globe).dx, start.center.dx);
    expect(tester.getCenter(globe).dy, lessThan(start.center.dy));
    expect(
      tester.getRect(globe).bottom,
      lessThan(tester.getTopLeft(panelTitle).dy),
    );
    expect(panelTitle.hitTestable(), findsOneWidget);
    expect(find.text('Ferrari').hitTestable(), findsOneWidget);
    expect(find.text('Fiat').hitTestable(), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Audi'), findsNothing);

    await tester.tap(find.byTooltip('Chiudi paese'));
    await tester.pumpAndSettle();
    expect(panelTitle.hitTestable(), findsNothing);
    expect(tester.getRect(globe), start);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Su uno schermo largo il pannello affianca il globo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(850, 520);
    addTearDown(tester.view.reset);

    final ferrari = Brand()
      ..id = 1
      ..name = 'Ferrari';
    await _showOrigins(tester, [_spot(ferrari)]);

    final globe = find.byType(SpotGlobe);
    final start = tester.getRect(globe);
    await tester.tapAt(start.center);
    await tester.pumpAndSettle();

    final end = tester.getRect(globe);
    expect(end.center.dx, lessThan(start.center.dx));
    expect(end.center.dy, start.center.dy);
    expect(end.right, lessThan(tester.getTopLeft(find.text('Italia')).dx));
  });

  testWidgets('Lo zoom di dettaglio mantiene tappabile il paese inquadrato', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.reset);

    final fiat = Brand()
      ..id = 1
      ..name = 'Fiat';
    final audi = Brand()
      ..id = 2
      ..name = 'Audi';
    await _showOrigins(tester, [_spot(fiat), _spot(audi)]);
    final globe = find.byType(SpotGlobe);
    final surface = find.descendant(
      of: globe,
      matching: find.byType(CustomPaint),
    );

    double fitRadius(Size size) =>
        (size.shortestSide / 2 - SpotGlobe.viewportInset - 2) / 1.06;

    void expectZoom(double zoom) {
      final size = tester.getSize(surface);
      final painter = tester.widget<CustomPaint>(surface).painter!;
      final pattern = paints;
      if (zoom <= 1) pattern.circle(radius: 1);
      expect(
        (Canvas canvas) => painter.paint(canvas, size),
        pattern..circle(
          x: size.width / 2,
          y: size.height / 2,
          radius: fitRadius(size) * zoom,
        ),
      );
    }

    final widget = tester.widget<SpotGlobe>(globe);
    final italy = widget.initialCountry!;
    final germany = widget.geometry.countries.firstWhere((c) => c.code == 'DE');
    final longitude = germany.longitude - italy.longitude;
    final focal =
        tester.getCenter(globe) +
        Offset(
              math.cos(germany.latitude) * math.sin(longitude),
              math.cos(germany.latitude) *
                      math.cos(longitude) *
                      math.sin(italy.latitude) -
                  math.sin(germany.latitude) * math.cos(italy.latitude),
            ) *
            (fitRadius(tester.getSize(surface)) * 0.80);
    final left = await tester.startGesture(focal - const Offset(16, 0));
    final right = await tester.startGesture(focal + const Offset(16, 0));
    for (var i = 0; i < 20; i++) {
      await left.moveBy(const Offset(-4, 0));
      await right.moveBy(const Offset(4, 0));
    }
    await left.up();
    await right.up();
    await tester.pump();
    expectZoom(1.75);

    await tester.tapAt(focal);
    await tester.pumpAndSettle();
    expect(find.text('Germania').hitTestable(), findsOneWidget);
    expectZoom(1);
  });

  testWidgets('Il primo tocco ferma la rotazione automatica', (tester) async {
    await _showOrigins(tester, []);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);

    final globe = find.byType(SpotGlobe);
    await tester.tapAt(tester.getTopLeft(globe) + const Offset(4, 4));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('La rotazione iniziale termina anche senza interazione', (
    tester,
  ) async {
    await _showOrigins(tester, []);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(seconds: 23));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
