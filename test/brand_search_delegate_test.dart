import 'package:car_spotter/models/brand.dart';
import 'package:car_spotter/views/brand_search_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Ordina le marche, filtra la lista e restituisce la scelta', (
    tester,
  ) async {
    final brands = [
      Brand()..name = 'Ferrari',
      Brand()..name = 'Alfa Romeo',
      Brand()..name = 'BMW',
    ];
    for (var index = 0; index < brands.length; index++) {
      brands[index].id = index + 1;
    }
    Brand? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSearch<Brand?>(
                  context: context,
                  delegate: BrandSearchDelegate(brands, result),
                );
              },
              child: const Text('Scegli marca'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Scegli marca'));
    await tester.pumpAndSettle();
    List<String?> visibleBrands() => tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text).data)
        .toList();
    expect(visibleBrands(), ['Alfa Romeo', 'BMW', 'Ferrari']);

    final field = find.byType(TextField);
    await tester.enterText(field, 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Nessuna marca trovata'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancella ricerca'));
    await tester.pumpAndSettle();
    expect(visibleBrands(), ['Alfa Romeo', 'BMW', 'Ferrari']);

    await tester.enterText(field, '  rOm  ');
    await tester.pumpAndSettle();
    expect(visibleBrands(), ['Alfa Romeo']);
    await tester.tap(find.text('Alfa Romeo'));
    await tester.pumpAndSettle();
    expect(result, same(brands[1]));

    await tester.tap(find.text('Scegli marca'));
    await tester.pumpAndSettle();
    expect(visibleBrands(), ['Alfa Romeo', 'BMW', 'Ferrari']);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Alfa Romeo'))
          .selected,
      isTrue,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
