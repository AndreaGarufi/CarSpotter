import 'dart:convert';
import 'dart:ui' as ui;

import 'package:car_spotter/views/brand_logo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Catalogo e globo hanno un logo locale per ogni marca inclusa',
    () async {
      final catalogue =
          jsonDecode(
                await rootBundle.loadString('assets/data/cars_database.json'),
              )
              as Map<String, dynamic>;
      final origins =
          jsonDecode(
                await rootBundle.loadString('assets/data/brand_origins.json'),
              )
              as Map<String, dynamic>;
      final assets = {
        ...catalogue.keys.map(BrandLogo.assetPathFor),
        for (final names in origins.values)
          ...(names as List).cast<String>().map(BrandLogo.assetPathFor),
      };

      for (final path in assets) {
        final bytes = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
}
