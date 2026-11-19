import 'package:car_spotter/models/car_model.dart';
import 'package:car_spotter/models/user_spot.dart';
import 'package:car_spotter/views/offline_spot_basemap.dart';
import 'package:car_spotter/views/spot_detail_screen.dart';
import 'package:car_spotter/views/spot_map_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

UserSpot _spot(int id, String name, {double? latitude = 37.0755}) {
  return UserSpot()
    ..id = id
    ..latitude = latitude
    ..longitude = 15.2866
    ..dateCaptured = DateTime(2026, 1, 1)
    ..imagePath = 'assets/images/home_your_spot.png'
    ..carModel.value = (CarModel()
      ..name = name
      ..rarityTier = RarityTier.common
      ..isIcon = false);
}

Future<void> _showMap(WidgetTester tester, List<UserSpot> spots) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SpotMapSection(spots: spots, onSpotChanged: () async {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MapController _mapController(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;

Future<void> _showLoadedMap(WidgetTester tester) async {
  await tester.runAsync(() async {
    await _showMap(tester, [_spot(1, 'Audi R8', latitude: null)]);
    final loader = tester.widget<FutureBuilder<Object>>(
      find.descendant(
        of: find.byType(OfflineSpotBasemap),
        matching: find.byWidgetPredicate((w) => w is FutureBuilder<Object>),
      ),
    );
    await loader.future;
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Mostra la mappa anche prima del primo spot geolocalizzato', (
    tester,
  ) async {
    await _showLoadedMap(tester);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Nessuno spot con posizione'), findsOneWidget);
    expect(find.text('Audi R8'), findsNothing);
    expect(find.text('Roma'), findsOneWidget);

    _mapController(tester).move(const LatLng(41.9, 12.49), 8);
    await tester.pumpAndSettle();
    expect(find.text('Roma'), findsOneWidget);

    await _showMap(tester, [_spot(1, 'Audi R8')]);
    expect(find.text('Nessuno spot con posizione'), findsNothing);
    expect(find.text('Audi R8'), findsOneWidget);
    expect(_mapController(tester).camera.center.latitude, 37.0755);
  });

  testWidgets(
    'Mostra comuni e frazioni italiane ai rispettivi livelli di zoom',
    (tester) async {
      await _showLoadedMap(tester);
      final controller = _mapController(tester);

      controller.move(const LatLng(37.17, 15.2), 9);
      await tester.pumpAndSettle();
      expect(find.text('Augusta'), findsNothing);

      controller.move(const LatLng(37.17, 15.2), 10);
      await tester.pumpAndSettle();
      expect(find.text('Augusta'), findsOneWidget);
      expect(find.text('Città Giardino'), findsNothing);

      controller.move(const LatLng(37.125, 15.2), 11);
      await tester.pumpAndSettle();
      expect(find.text('Priolo Gargallo'), findsOneWidget);

      controller.move(const LatLng(37.104, 15.21), 12);
      await tester.pumpAndSettle();
      for (final place in ['Belvedere', 'Città Giardino']) {
        expect(find.text(place), findsOneWidget);
      }

      controller.move(const LatLng(37.283, 15.004), 13);
      await tester.pumpAndSettle();
      for (final place in ['Lentini', 'Carlentini']) {
        expect(find.text(place), findsOneWidget);
      }
    },
  );

  testWidgets('Il pin singolo segue le coordinate durante zoom e spostamento', (
    tester,
  ) async {
    const location = LatLng(37.0755, 15.2866);
    await _showMap(tester, [_spot(1, 'Audi R8')]);
    final map = find.byType(FlutterMap);
    final pin = find.byIcon(Icons.location_on);
    final controller = _mapController(tester);

    void expectPinAtLocation() {
      expect(pin, findsOneWidget);
      expect(tester.widget<Icon>(pin).shadows, isNull);
      final expected =
          tester.getTopLeft(map) +
          controller.camera.latLngToScreenOffset(location);
      final actual = tester.getRect(pin).bottomCenter;
      expect(actual.dx, closeTo(expected.dx, 0.01));
      expect(actual.dy, closeTo(expected.dy, 0.01));
    }

    expectPinAtLocation();
    controller.move(const LatLng(37.080, 15.289), 12);
    await tester.pumpAndSettle();
    expectPinAtLocation();

    controller.move(const LatLng(37.50, 15.08), 14);
    await tester.pumpAndSettle();
    expect(pin, findsNothing);
  });

  testWidgets('Raggruppa e separa spot con coordinate identiche', (
    tester,
  ) async {
    final first = _spot(1, 'Audi R8');
    final second = _spot(2, 'Ferrari F40');
    await _showMap(tester, [
      first,
      second,
      _spot(3, 'Senza posizione', latitude: null),
    ]);

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Audi R8'), findsNothing);
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    final audi = find.text('Audi R8');
    final ferrari = find.text('Ferrari F40');
    expect(audi, findsOneWidget);
    expect(ferrari, findsOneWidget);
    expect(tester.getRect(audi).overlaps(tester.getRect(ferrari)), isFalse);
    expect(find.text('Senza posizione'), findsNothing);

    for (final spot in [first, second]) {
      await tester.tap(find.text(spot.carModel.value!.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apri spot'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SpotDetailScreen>(find.byType(SpotDetailScreen)).spot,
        same(spot),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Mantiene centro e zoom tra riquadro e schermo intero', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPadding);
    await _showMap(tester, [
      _spot(1, 'Audi R8'),
      _spot(2, 'Ferrari F40', latitude: 37.0768),
    ]);
    final inline = _mapController(tester);
    final center = inline.camera.center;
    final zoom = inline.camera.zoom;

    await tester.tap(find.byTooltip('Apri a schermo intero'));
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('Mappa degli spot'));
    expect(title.style?.fontWeight, FontWeight.bold);
    expect(
      SystemChrome.latestStyle?.systemNavigationBarContrastEnforced,
      isFalse,
    );
    final expanded = _mapController(tester);
    expect(expanded.camera.center, center);
    expect(expanded.camera.zoom, zoom);
    await tester.tap(find.byTooltip('Aumenta zoom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumenta zoom'));
    await tester.pumpAndSettle();
    expect(find.text('Audi R8'), findsOneWidget);
    expect(find.text('Ferrari F40'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(inline.camera.center, center);
    expect(inline.camera.zoom, zoom + 2);
  });

  testWidgets('La mappa può essere trascinata in una Home scorrevole', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                SpotMapSection(
                  spots: [_spot(1, 'Audi R8')],
                  onSpotChanged: () async {},
                ),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller = _mapController(tester);
    final originalCenter = controller.camera.center;
    final map = tester.getRect(find.byType(FlutterMap));
    await tester.dragFrom(
      map.center + const Offset(120, 0),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(controller.camera.center.latitude, isNot(originalCenter.latitude));
    expect(scroll.offset, 0);

    await tester.dragFrom(
      Offset(map.left - 4, map.center.dy),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
  });
}
