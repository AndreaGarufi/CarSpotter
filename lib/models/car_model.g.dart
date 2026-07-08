// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCarModelCollection on Isar {
  IsarCollection<CarModel> get carModels => this.collection();
}

const CarModelSchema = CollectionSchema(
  name: r'CarModel',
  id: -7339873665292748562,
  properties: {
    r'baseRarityScore': PropertySchema(
      id: 0,
      name: r'baseRarityScore',
      type: IsarType.long,
    ),
    r'engineHp': PropertySchema(id: 1, name: r'engineHp', type: IsarType.long),
    r'iconScore': PropertySchema(
      id: 2,
      name: r'iconScore',
      type: IsarType.long,
    ),
    r'isIcon': PropertySchema(id: 3, name: r'isIcon', type: IsarType.bool),
    r'launchYear': PropertySchema(
      id: 4,
      name: r'launchYear',
      type: IsarType.long,
    ),
    r'name': PropertySchema(id: 5, name: r'name', type: IsarType.string),
    r'productionRun': PropertySchema(
      id: 6,
      name: r'productionRun',
      type: IsarType.long,
    ),
    r'rarityTier': PropertySchema(
      id: 7,
      name: r'rarityTier',
      type: IsarType.byte,
      enumMap: _CarModelrarityTierEnumValueMap,
    ),
  },

  estimateSize: _carModelEstimateSize,
  serialize: _carModelSerialize,
  deserialize: _carModelDeserialize,
  deserializeProp: _carModelDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {
    r'brand': LinkSchema(
      id: -4558842857206029810,
      name: r'brand',
      target: r'Brand',
      single: true,
    ),
  },
  embeddedSchemas: {},

  getId: _carModelGetId,
  getLinks: _carModelGetLinks,
  attach: _carModelAttach,
  version: '3.3.2',
);

int _carModelEstimateSize(
  CarModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _carModelSerialize(
  CarModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.baseRarityScore);
  writer.writeLong(offsets[1], object.engineHp);
  writer.writeLong(offsets[2], object.iconScore);
  writer.writeBool(offsets[3], object.isIcon);
  writer.writeLong(offsets[4], object.launchYear);
  writer.writeString(offsets[5], object.name);
  writer.writeLong(offsets[6], object.productionRun);
  writer.writeByte(offsets[7], object.rarityTier.index);
}

CarModel _carModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CarModel();
  object.baseRarityScore = reader.readLong(offsets[0]);
  object.engineHp = reader.readLongOrNull(offsets[1]);
  object.iconScore = reader.readLong(offsets[2]);
  object.id = id;
  object.isIcon = reader.readBool(offsets[3]);
  object.launchYear = reader.readLongOrNull(offsets[4]);
  object.name = reader.readString(offsets[5]);
  object.productionRun = reader.readLongOrNull(offsets[6]);
  object.rarityTier =
      _CarModelrarityTierValueEnumMap[reader.readByteOrNull(offsets[7])] ??
      RarityTier.common;
  return object;
}

P _carModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    case 7:
      return (_CarModelrarityTierValueEnumMap[reader.readByteOrNull(offset)] ??
              RarityTier.common)
          as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _CarModelrarityTierEnumValueMap = {
  'common': 0,
  'uncommon': 1,
  'rare': 2,
  'epic': 3,
  'legendary': 4,
};
const _CarModelrarityTierValueEnumMap = {
  0: RarityTier.common,
  1: RarityTier.uncommon,
  2: RarityTier.rare,
  3: RarityTier.epic,
  4: RarityTier.legendary,
};

Id _carModelGetId(CarModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _carModelGetLinks(CarModel object) {
  return [object.brand];
}

void _carModelAttach(IsarCollection<dynamic> col, Id id, CarModel object) {
  object.id = id;
  object.brand.attach(col, col.isar.collection<Brand>(), r'brand', id);
}

extension CarModelQueryWhereSort on QueryBuilder<CarModel, CarModel, QWhere> {
  QueryBuilder<CarModel, CarModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CarModelQueryWhere on QueryBuilder<CarModel, CarModel, QWhereClause> {
  QueryBuilder<CarModel, CarModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension CarModelQueryFilter
    on QueryBuilder<CarModel, CarModel, QFilterCondition> {
  QueryBuilder<CarModel, CarModel, QAfterFilterCondition>
  baseRarityScoreEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'baseRarityScore', value: value),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition>
  baseRarityScoreGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseRarityScore',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition>
  baseRarityScoreLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseRarityScore',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition>
  baseRarityScoreBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseRarityScore',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> engineHpIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'engineHp'),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> engineHpIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'engineHp'),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> engineHpEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'engineHp', value: value),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> engineHpGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'engineHp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> engineHpLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'engineHp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> engineHpBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'engineHp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> iconScoreEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'iconScore', value: value),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> iconScoreGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'iconScore',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> iconScoreLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'iconScore',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> iconScoreBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'iconScore',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> isIconEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isIcon', value: value),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> launchYearIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'launchYear'),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition>
  launchYearIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'launchYear'),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> launchYearEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'launchYear', value: value),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> launchYearGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'launchYear',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> launchYearLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'launchYear',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> launchYearBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'launchYear',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition>
  productionRunIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'productionRun'),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition>
  productionRunIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'productionRun'),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> productionRunEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'productionRun', value: value),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition>
  productionRunGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'productionRun',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> productionRunLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'productionRun',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> productionRunBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'productionRun',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> rarityTierEqualTo(
    RarityTier value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rarityTier', value: value),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> rarityTierGreaterThan(
    RarityTier value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'rarityTier',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> rarityTierLessThan(
    RarityTier value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'rarityTier',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> rarityTierBetween(
    RarityTier lower,
    RarityTier upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'rarityTier',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension CarModelQueryObject
    on QueryBuilder<CarModel, CarModel, QFilterCondition> {}

extension CarModelQueryLinks
    on QueryBuilder<CarModel, CarModel, QFilterCondition> {
  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> brand(
    FilterQuery<Brand> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'brand');
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterFilterCondition> brandIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'brand', 0, true, 0, true);
    });
  }
}

extension CarModelQuerySortBy on QueryBuilder<CarModel, CarModel, QSortBy> {
  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByBaseRarityScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseRarityScore', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByBaseRarityScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseRarityScore', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByEngineHp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'engineHp', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByEngineHpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'engineHp', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByIconScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconScore', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByIconScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconScore', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByIsIcon() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isIcon', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByIsIconDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isIcon', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByLaunchYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'launchYear', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByLaunchYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'launchYear', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByProductionRun() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productionRun', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByProductionRunDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productionRun', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByRarityTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rarityTier', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> sortByRarityTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rarityTier', Sort.desc);
    });
  }
}

extension CarModelQuerySortThenBy
    on QueryBuilder<CarModel, CarModel, QSortThenBy> {
  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByBaseRarityScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseRarityScore', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByBaseRarityScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseRarityScore', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByEngineHp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'engineHp', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByEngineHpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'engineHp', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByIconScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconScore', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByIconScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconScore', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByIsIcon() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isIcon', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByIsIconDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isIcon', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByLaunchYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'launchYear', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByLaunchYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'launchYear', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByProductionRun() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productionRun', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByProductionRunDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productionRun', Sort.desc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByRarityTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rarityTier', Sort.asc);
    });
  }

  QueryBuilder<CarModel, CarModel, QAfterSortBy> thenByRarityTierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rarityTier', Sort.desc);
    });
  }
}

extension CarModelQueryWhereDistinct
    on QueryBuilder<CarModel, CarModel, QDistinct> {
  QueryBuilder<CarModel, CarModel, QDistinct> distinctByBaseRarityScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseRarityScore');
    });
  }

  QueryBuilder<CarModel, CarModel, QDistinct> distinctByEngineHp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'engineHp');
    });
  }

  QueryBuilder<CarModel, CarModel, QDistinct> distinctByIconScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'iconScore');
    });
  }

  QueryBuilder<CarModel, CarModel, QDistinct> distinctByIsIcon() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isIcon');
    });
  }

  QueryBuilder<CarModel, CarModel, QDistinct> distinctByLaunchYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'launchYear');
    });
  }

  QueryBuilder<CarModel, CarModel, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CarModel, CarModel, QDistinct> distinctByProductionRun() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productionRun');
    });
  }

  QueryBuilder<CarModel, CarModel, QDistinct> distinctByRarityTier() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rarityTier');
    });
  }
}

extension CarModelQueryProperty
    on QueryBuilder<CarModel, CarModel, QQueryProperty> {
  QueryBuilder<CarModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CarModel, int, QQueryOperations> baseRarityScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseRarityScore');
    });
  }

  QueryBuilder<CarModel, int?, QQueryOperations> engineHpProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'engineHp');
    });
  }

  QueryBuilder<CarModel, int, QQueryOperations> iconScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'iconScore');
    });
  }

  QueryBuilder<CarModel, bool, QQueryOperations> isIconProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isIcon');
    });
  }

  QueryBuilder<CarModel, int?, QQueryOperations> launchYearProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'launchYear');
    });
  }

  QueryBuilder<CarModel, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<CarModel, int?, QQueryOperations> productionRunProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productionRun');
    });
  }

  QueryBuilder<CarModel, RarityTier, QQueryOperations> rarityTierProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rarityTier');
    });
  }
}
