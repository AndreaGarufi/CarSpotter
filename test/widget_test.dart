import 'package:car_spotter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Le immagini delle auto vengono riutilizzate durante l’animazione iniziale',
    (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetPadding);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const CarSpotterApp());
      await tester.pump();
      expect(find.text('Inizia a spottare'), findsOneWidget);
      expect(
        SystemChrome.latestStyle?.systemNavigationBarContrastEnforced,
        isFalse,
      );

      final cars = find.byType(Image);
      final before = tester.widgetList<Image>(cars).toList();
      expect(before, hasLength(2));
      await tester.pump(const Duration(milliseconds: 200));
      final after = tester.widgetList<Image>(cars).toList();
      expect(after, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        expect(after[i], same(before[i]));
      }
    },
  );
}
