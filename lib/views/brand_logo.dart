import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo(this.brandName, {super.key});

  final String brandName;

  static final _separator = RegExp(r'[^a-z0-9]+');

  static String assetPathFor(String brandName) {
    final slug = brandName
        .trim()
        .toLowerCase()
        .replaceAll('ë', 'e')
        .replaceAll('š', 's')
        .split(_separator)
        .where((part) => part.isNotEmpty)
        .join('-');
    return 'assets/images/brand_logos/$slug.webp';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 28,
      child: Image.asset(
        assetPathFor(brandName),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) {
          // The catalogue can gain makes through a database update.
          final initials = brandName
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part.characters.first.toUpperCase())
              .join();
          return ExcludeSemantics(
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }
}
