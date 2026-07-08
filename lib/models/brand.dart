import 'package:isar_community/isar.dart'; // <-- Modificato qui

part 'brand.g.dart';

@collection
class Brand {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  String? logoPath;
}
