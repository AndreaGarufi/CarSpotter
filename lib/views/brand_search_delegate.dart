import 'package:flutter/material.dart';

import '../models/brand.dart';

List<Brand> brandsInAlphabeticalOrder(List<Brand> brands) =>
    [...brands]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

List<Brand> matchingBrands(List<Brand> brands, String query) {
  final search = query.trim().toLowerCase();
  return brands
      .where((brand) => brand.name.toLowerCase().contains(search))
      .toList();
}

class BrandSearchDelegate extends SearchDelegate<Brand?> {
  BrandSearchDelegate(List<Brand> brands, this.selectedBrand)
    : brands = brandsInAlphabeticalOrder(brands),
      super(searchFieldLabel: 'Cerca marca');

  final List<Brand> brands;
  final Brand? selectedBrand;

  @override
  Widget buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Cancella ricerca',
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
  ];

  @override
  Widget buildSuggestions(BuildContext context) => _buildBrandList();

  @override
  Widget buildResults(BuildContext context) => _buildBrandList();

  Widget _buildBrandList() {
    final search = query.trim().toLowerCase();
    final matches = matchingBrands(brands, search);
    if (matches.isEmpty) {
      return const Center(child: Text('Nessuna marca trovata'));
    }
    return ListView.builder(
      key: ValueKey(search),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final brand = matches[index];
        final selected = brand.id == selectedBrand?.id;
        return ListTile(
          title: Text(brand.name),
          selected: selected,
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: () => close(context, brand),
        );
      },
    );
  }
}
