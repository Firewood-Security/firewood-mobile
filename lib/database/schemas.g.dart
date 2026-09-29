// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schemas.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetVaultCollection on Isar {
  IsarCollection<Vault> get vaults => this.collection();
}

const VaultSchema = CollectionSchema(
  name: r'Vault',
  id: -4342956630933593564,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'isDefault': PropertySchema(
      id: 1,
      name: r'isDefault',
      type: IsarType.bool,
    ),
    r'name': PropertySchema(
      id: 2,
      name: r'name',
      type: IsarType.string,
    ),
    r'salt': PropertySchema(
      id: 3,
      name: r'salt',
      type: IsarType.longList,
    ),
    r'vaultId': PropertySchema(
      id: 4,
      name: r'vaultId',
      type: IsarType.string,
    ),
    r'verifierNonce': PropertySchema(
      id: 5,
      name: r'verifierNonce',
      type: IsarType.longList,
    ),
    r'verifierToken': PropertySchema(
      id: 6,
      name: r'verifierToken',
      type: IsarType.longList,
    ),
    r'version': PropertySchema(
      id: 7,
      name: r'version',
      type: IsarType.long,
    ),
    r'wrappedMekNonce': PropertySchema(
      id: 8,
      name: r'wrappedMekNonce',
      type: IsarType.longList,
    ),
    r'wrappedMekToken': PropertySchema(
      id: 9,
      name: r'wrappedMekToken',
      type: IsarType.longList,
    )
  },
  estimateSize: _vaultEstimateSize,
  serialize: _vaultSerialize,
  deserialize: _vaultDeserialize,
  deserializeProp: _vaultDeserializeProp,
  idName: r'id',
  indexes: {
    r'vaultId': IndexSchema(
      id: -1162152712452118160,
      name: r'vaultId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'vaultId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _vaultGetId,
  getLinks: _vaultGetLinks,
  attach: _vaultAttach,
  version: '3.1.0+1',
);

int _vaultEstimateSize(
  Vault object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.salt.length * 8;
  bytesCount += 3 + object.vaultId.length * 3;
  {
    final value = object.verifierNonce;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  {
    final value = object.verifierToken;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  {
    final value = object.wrappedMekNonce;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  {
    final value = object.wrappedMekToken;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  return bytesCount;
}

void _vaultSerialize(
  Vault object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeBool(offsets[1], object.isDefault);
  writer.writeString(offsets[2], object.name);
  writer.writeLongList(offsets[3], object.salt);
  writer.writeString(offsets[4], object.vaultId);
  writer.writeLongList(offsets[5], object.verifierNonce);
  writer.writeLongList(offsets[6], object.verifierToken);
  writer.writeLong(offsets[7], object.version);
  writer.writeLongList(offsets[8], object.wrappedMekNonce);
  writer.writeLongList(offsets[9], object.wrappedMekToken);
}

Vault _vaultDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Vault();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.isDefault = reader.readBool(offsets[1]);
  object.name = reader.readString(offsets[2]);
  object.salt = reader.readLongList(offsets[3]) ?? [];
  object.vaultId = reader.readString(offsets[4]);
  object.verifierNonce = reader.readLongList(offsets[5]);
  object.verifierToken = reader.readLongList(offsets[6]);
  object.version = reader.readLong(offsets[7]);
  object.wrappedMekNonce = reader.readLongList(offsets[8]);
  object.wrappedMekToken = reader.readLongList(offsets[9]);
  return object;
}

P _vaultDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLongList(offset) ?? []) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLongList(offset)) as P;
    case 6:
      return (reader.readLongList(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readLongList(offset)) as P;
    case 9:
      return (reader.readLongList(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _vaultGetId(Vault object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _vaultGetLinks(Vault object) {
  return [];
}

void _vaultAttach(IsarCollection<dynamic> col, Id id, Vault object) {
  object.id = id;
}

extension VaultByIndex on IsarCollection<Vault> {
  Future<Vault?> getByVaultId(String vaultId) {
    return getByIndex(r'vaultId', [vaultId]);
  }

  Vault? getByVaultIdSync(String vaultId) {
    return getByIndexSync(r'vaultId', [vaultId]);
  }

  Future<bool> deleteByVaultId(String vaultId) {
    return deleteByIndex(r'vaultId', [vaultId]);
  }

  bool deleteByVaultIdSync(String vaultId) {
    return deleteByIndexSync(r'vaultId', [vaultId]);
  }

  Future<List<Vault?>> getAllByVaultId(List<String> vaultIdValues) {
    final values = vaultIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'vaultId', values);
  }

  List<Vault?> getAllByVaultIdSync(List<String> vaultIdValues) {
    final values = vaultIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'vaultId', values);
  }

  Future<int> deleteAllByVaultId(List<String> vaultIdValues) {
    final values = vaultIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'vaultId', values);
  }

  int deleteAllByVaultIdSync(List<String> vaultIdValues) {
    final values = vaultIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'vaultId', values);
  }

  Future<Id> putByVaultId(Vault object) {
    return putByIndex(r'vaultId', object);
  }

  Id putByVaultIdSync(Vault object, {bool saveLinks = true}) {
    return putByIndexSync(r'vaultId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByVaultId(List<Vault> objects) {
    return putAllByIndex(r'vaultId', objects);
  }

  List<Id> putAllByVaultIdSync(List<Vault> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'vaultId', objects, saveLinks: saveLinks);
  }
}

extension VaultQueryWhereSort on QueryBuilder<Vault, Vault, QWhere> {
  QueryBuilder<Vault, Vault, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension VaultQueryWhere on QueryBuilder<Vault, Vault, QWhereClause> {
  QueryBuilder<Vault, Vault, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Vault, Vault, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterWhereClause> vaultIdEqualTo(String vaultId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'vaultId',
        value: [vaultId],
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterWhereClause> vaultIdNotEqualTo(
      String vaultId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'vaultId',
              lower: [],
              upper: [vaultId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'vaultId',
              lower: [vaultId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'vaultId',
              lower: [vaultId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'vaultId',
              lower: [],
              upper: [vaultId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension VaultQueryFilter on QueryBuilder<Vault, Vault, QFilterCondition> {
  QueryBuilder<Vault, Vault, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> isDefaultEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDefault',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltElementEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'salt',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'salt',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'salt',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'salt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> saltLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'vaultId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'vaultId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'vaultId',
        value: '',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> vaultIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'vaultId',
        value: '',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'verifierNonce',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'verifierNonce',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceElementEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'verifierNonce',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      verifierNonceElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'verifierNonce',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      verifierNonceElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'verifierNonce',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'verifierNonce',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierNonce',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierNonce',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierNonce',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierNonce',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      verifierNonceLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierNonce',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierNonceLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierNonce',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'verifierToken',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'verifierToken',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenElementEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'verifierToken',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      verifierTokenElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'verifierToken',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      verifierTokenElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'verifierToken',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'verifierToken',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierToken',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierToken',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierToken',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierToken',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      verifierTokenLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierToken',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> verifierTokenLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'verifierToken',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> versionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> versionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> versionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'version',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> wrappedMekNonceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'wrappedMekNonce',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> wrappedMekNonceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'wrappedMekNonce',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wrappedMekNonce',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'wrappedMekNonce',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'wrappedMekNonce',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'wrappedMekNonce',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekNonce',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> wrappedMekNonceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekNonce',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekNonce',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekNonce',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekNonce',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekNonceLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekNonce',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> wrappedMekTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'wrappedMekToken',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> wrappedMekTokenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'wrappedMekToken',
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wrappedMekToken',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'wrappedMekToken',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'wrappedMekToken',
        value: value,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'wrappedMekToken',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekToken',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition> wrappedMekTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekToken',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekToken',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekToken',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekToken',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Vault, Vault, QAfterFilterCondition>
      wrappedMekTokenLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wrappedMekToken',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension VaultQueryObject on QueryBuilder<Vault, Vault, QFilterCondition> {}

extension VaultQueryLinks on QueryBuilder<Vault, Vault, QFilterCondition> {}

extension VaultQuerySortBy on QueryBuilder<Vault, Vault, QSortBy> {
  QueryBuilder<Vault, Vault, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDefault', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByIsDefaultDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDefault', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByVaultId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByVaultIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension VaultQuerySortThenBy on QueryBuilder<Vault, Vault, QSortThenBy> {
  QueryBuilder<Vault, Vault, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDefault', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByIsDefaultDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDefault', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByVaultId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByVaultIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.desc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<Vault, Vault, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension VaultQueryWhereDistinct on QueryBuilder<Vault, Vault, QDistinct> {
  QueryBuilder<Vault, Vault, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctByIsDefault() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDefault');
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctBySalt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'salt');
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctByVaultId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'vaultId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctByVerifierNonce() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'verifierNonce');
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctByVerifierToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'verifierToken');
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctByWrappedMekNonce() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'wrappedMekNonce');
    });
  }

  QueryBuilder<Vault, Vault, QDistinct> distinctByWrappedMekToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'wrappedMekToken');
    });
  }
}

extension VaultQueryProperty on QueryBuilder<Vault, Vault, QQueryProperty> {
  QueryBuilder<Vault, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Vault, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Vault, bool, QQueryOperations> isDefaultProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDefault');
    });
  }

  QueryBuilder<Vault, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Vault, List<int>, QQueryOperations> saltProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'salt');
    });
  }

  QueryBuilder<Vault, String, QQueryOperations> vaultIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'vaultId');
    });
  }

  QueryBuilder<Vault, List<int>?, QQueryOperations> verifierNonceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'verifierNonce');
    });
  }

  QueryBuilder<Vault, List<int>?, QQueryOperations> verifierTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'verifierToken');
    });
  }

  QueryBuilder<Vault, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<Vault, List<int>?, QQueryOperations> wrappedMekNonceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'wrappedMekNonce');
    });
  }

  QueryBuilder<Vault, List<int>?, QQueryOperations> wrappedMekTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'wrappedMekToken');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSecureItemCollection on Isar {
  IsarCollection<SecureItem> get secureItems => this.collection();
}

const SecureItemSchema = CollectionSchema(
  name: r'SecureItem',
  id: 6250121519312877537,
  properties: {
    r'encryptedData': PropertySchema(
      id: 0,
      name: r'encryptedData',
      type: IsarType.longList,
    ),
    r'itemId': PropertySchema(
      id: 1,
      name: r'itemId',
      type: IsarType.string,
    ),
    r'nonce': PropertySchema(
      id: 2,
      name: r'nonce',
      type: IsarType.longList,
    ),
    r'title': PropertySchema(
      id: 3,
      name: r'title',
      type: IsarType.string,
    ),
    r'type': PropertySchema(
      id: 4,
      name: r'type',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 5,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'vaultId': PropertySchema(
      id: 6,
      name: r'vaultId',
      type: IsarType.string,
    )
  },
  estimateSize: _secureItemEstimateSize,
  serialize: _secureItemSerialize,
  deserialize: _secureItemDeserialize,
  deserializeProp: _secureItemDeserializeProp,
  idName: r'id',
  indexes: {
    r'itemId': IndexSchema(
      id: -5342806140158601489,
      name: r'itemId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'itemId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'vaultId': IndexSchema(
      id: -1162152712452118160,
      name: r'vaultId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'vaultId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _secureItemGetId,
  getLinks: _secureItemGetLinks,
  attach: _secureItemAttach,
  version: '3.1.0+1',
);

int _secureItemEstimateSize(
  SecureItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.encryptedData.length * 8;
  bytesCount += 3 + object.itemId.length * 3;
  bytesCount += 3 + object.nonce.length * 8;
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.type.length * 3;
  bytesCount += 3 + object.vaultId.length * 3;
  return bytesCount;
}

void _secureItemSerialize(
  SecureItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLongList(offsets[0], object.encryptedData);
  writer.writeString(offsets[1], object.itemId);
  writer.writeLongList(offsets[2], object.nonce);
  writer.writeString(offsets[3], object.title);
  writer.writeString(offsets[4], object.type);
  writer.writeDateTime(offsets[5], object.updatedAt);
  writer.writeString(offsets[6], object.vaultId);
}

SecureItem _secureItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SecureItem();
  object.encryptedData = reader.readLongList(offsets[0]) ?? [];
  object.id = id;
  object.itemId = reader.readString(offsets[1]);
  object.nonce = reader.readLongList(offsets[2]) ?? [];
  object.title = reader.readString(offsets[3]);
  object.type = reader.readString(offsets[4]);
  object.updatedAt = reader.readDateTime(offsets[5]);
  object.vaultId = reader.readString(offsets[6]);
  return object;
}

P _secureItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongList(offset) ?? []) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLongList(offset) ?? []) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _secureItemGetId(SecureItem object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _secureItemGetLinks(SecureItem object) {
  return [];
}

void _secureItemAttach(IsarCollection<dynamic> col, Id id, SecureItem object) {
  object.id = id;
}

extension SecureItemByIndex on IsarCollection<SecureItem> {
  Future<SecureItem?> getByItemId(String itemId) {
    return getByIndex(r'itemId', [itemId]);
  }

  SecureItem? getByItemIdSync(String itemId) {
    return getByIndexSync(r'itemId', [itemId]);
  }

  Future<bool> deleteByItemId(String itemId) {
    return deleteByIndex(r'itemId', [itemId]);
  }

  bool deleteByItemIdSync(String itemId) {
    return deleteByIndexSync(r'itemId', [itemId]);
  }

  Future<List<SecureItem?>> getAllByItemId(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'itemId', values);
  }

  List<SecureItem?> getAllByItemIdSync(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'itemId', values);
  }

  Future<int> deleteAllByItemId(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'itemId', values);
  }

  int deleteAllByItemIdSync(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'itemId', values);
  }

  Future<Id> putByItemId(SecureItem object) {
    return putByIndex(r'itemId', object);
  }

  Id putByItemIdSync(SecureItem object, {bool saveLinks = true}) {
    return putByIndexSync(r'itemId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByItemId(List<SecureItem> objects) {
    return putAllByIndex(r'itemId', objects);
  }

  List<Id> putAllByItemIdSync(List<SecureItem> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'itemId', objects, saveLinks: saveLinks);
  }
}

extension SecureItemQueryWhereSort
    on QueryBuilder<SecureItem, SecureItem, QWhere> {
  QueryBuilder<SecureItem, SecureItem, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SecureItemQueryWhere
    on QueryBuilder<SecureItem, SecureItem, QWhereClause> {
  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> itemIdEqualTo(
      String itemId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'itemId',
        value: [itemId],
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> itemIdNotEqualTo(
      String itemId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'itemId',
              lower: [],
              upper: [itemId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'itemId',
              lower: [itemId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'itemId',
              lower: [itemId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'itemId',
              lower: [],
              upper: [itemId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> vaultIdEqualTo(
      String vaultId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'vaultId',
        value: [vaultId],
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterWhereClause> vaultIdNotEqualTo(
      String vaultId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'vaultId',
              lower: [],
              upper: [vaultId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'vaultId',
              lower: [vaultId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'vaultId',
              lower: [vaultId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'vaultId',
              lower: [],
              upper: [vaultId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SecureItemQueryFilter
    on QueryBuilder<SecureItem, SecureItem, QFilterCondition> {
  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'encryptedData',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'encryptedData',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'encryptedData',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'encryptedData',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'encryptedData',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'encryptedData',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'encryptedData',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'encryptedData',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'encryptedData',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      encryptedDataLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'encryptedData',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'itemId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'itemId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> itemIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemId',
        value: '',
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      itemIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'itemId',
        value: '',
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nonce',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nonce',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nonce',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nonce',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nonce',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> nonceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nonce',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nonce',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nonce',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nonce',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      nonceLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nonce',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'type',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: '',
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'type',
        value: '',
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> updatedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> vaultIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      vaultIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> vaultIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> vaultIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'vaultId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> vaultIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> vaultIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> vaultIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> vaultIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'vaultId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition> vaultIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'vaultId',
        value: '',
      ));
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterFilterCondition>
      vaultIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'vaultId',
        value: '',
      ));
    });
  }
}

extension SecureItemQueryObject
    on QueryBuilder<SecureItem, SecureItem, QFilterCondition> {}

extension SecureItemQueryLinks
    on QueryBuilder<SecureItem, SecureItem, QFilterCondition> {}

extension SecureItemQuerySortBy
    on QueryBuilder<SecureItem, SecureItem, QSortBy> {
  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByVaultId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> sortByVaultIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.desc);
    });
  }
}

extension SecureItemQuerySortThenBy
    on QueryBuilder<SecureItem, SecureItem, QSortThenBy> {
  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByVaultId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.asc);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QAfterSortBy> thenByVaultIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.desc);
    });
  }
}

extension SecureItemQueryWhereDistinct
    on QueryBuilder<SecureItem, SecureItem, QDistinct> {
  QueryBuilder<SecureItem, SecureItem, QDistinct> distinctByEncryptedData() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'encryptedData');
    });
  }

  QueryBuilder<SecureItem, SecureItem, QDistinct> distinctByItemId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QDistinct> distinctByNonce() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nonce');
    });
  }

  QueryBuilder<SecureItem, SecureItem, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QDistinct> distinctByType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SecureItem, SecureItem, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<SecureItem, SecureItem, QDistinct> distinctByVaultId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'vaultId', caseSensitive: caseSensitive);
    });
  }
}

extension SecureItemQueryProperty
    on QueryBuilder<SecureItem, SecureItem, QQueryProperty> {
  QueryBuilder<SecureItem, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SecureItem, List<int>, QQueryOperations>
      encryptedDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'encryptedData');
    });
  }

  QueryBuilder<SecureItem, String, QQueryOperations> itemIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemId');
    });
  }

  QueryBuilder<SecureItem, List<int>, QQueryOperations> nonceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nonce');
    });
  }

  QueryBuilder<SecureItem, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<SecureItem, String, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<SecureItem, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<SecureItem, String, QQueryOperations> vaultIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'vaultId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBurnerHashCollection on Isar {
  IsarCollection<BurnerHash> get burnerHashs => this.collection();
}

const BurnerHashSchema = CollectionSchema(
  name: r'BurnerHash',
  id: -3570392196410717097,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'label': PropertySchema(
      id: 1,
      name: r'label',
      type: IsarType.string,
    ),
    r'passwordHash': PropertySchema(
      id: 2,
      name: r'passwordHash',
      type: IsarType.string,
    ),
    r'salt': PropertySchema(
      id: 3,
      name: r'salt',
      type: IsarType.longList,
    )
  },
  estimateSize: _burnerHashEstimateSize,
  serialize: _burnerHashSerialize,
  deserialize: _burnerHashDeserialize,
  deserializeProp: _burnerHashDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _burnerHashGetId,
  getLinks: _burnerHashGetLinks,
  attach: _burnerHashAttach,
  version: '3.1.0+1',
);

int _burnerHashEstimateSize(
  BurnerHash object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.label.length * 3;
  bytesCount += 3 + object.passwordHash.length * 3;
  {
    final value = object.salt;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  return bytesCount;
}

void _burnerHashSerialize(
  BurnerHash object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.label);
  writer.writeString(offsets[2], object.passwordHash);
  writer.writeLongList(offsets[3], object.salt);
}

BurnerHash _burnerHashDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BurnerHash();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.label = reader.readString(offsets[1]);
  object.passwordHash = reader.readString(offsets[2]);
  object.salt = reader.readLongList(offsets[3]);
  return object;
}

P _burnerHashDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLongList(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _burnerHashGetId(BurnerHash object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _burnerHashGetLinks(BurnerHash object) {
  return [];
}

void _burnerHashAttach(IsarCollection<dynamic> col, Id id, BurnerHash object) {
  object.id = id;
}

extension BurnerHashQueryWhereSort
    on QueryBuilder<BurnerHash, BurnerHash, QWhere> {
  QueryBuilder<BurnerHash, BurnerHash, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BurnerHashQueryWhere
    on QueryBuilder<BurnerHash, BurnerHash, QWhereClause> {
  QueryBuilder<BurnerHash, BurnerHash, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<BurnerHash, BurnerHash, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BurnerHashQueryFilter
    on QueryBuilder<BurnerHash, BurnerHash, QFilterCondition> {
  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'label',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'label',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> labelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'label',
        value: '',
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      labelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'label',
        value: '',
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'passwordHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'passwordHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'passwordHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'passwordHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'passwordHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'passwordHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'passwordHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'passwordHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'passwordHash',
        value: '',
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      passwordHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'passwordHash',
        value: '',
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> saltIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'salt',
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> saltIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'salt',
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      saltElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'salt',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      saltElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'salt',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      saltElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'salt',
        value: value,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      saltElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'salt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> saltLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> saltIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> saltIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      saltLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition>
      saltLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterFilterCondition> saltLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'salt',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension BurnerHashQueryObject
    on QueryBuilder<BurnerHash, BurnerHash, QFilterCondition> {}

extension BurnerHashQueryLinks
    on QueryBuilder<BurnerHash, BurnerHash, QFilterCondition> {}

extension BurnerHashQuerySortBy
    on QueryBuilder<BurnerHash, BurnerHash, QSortBy> {
  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> sortByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> sortByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> sortByPasswordHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'passwordHash', Sort.asc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> sortByPasswordHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'passwordHash', Sort.desc);
    });
  }
}

extension BurnerHashQuerySortThenBy
    on QueryBuilder<BurnerHash, BurnerHash, QSortThenBy> {
  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> thenByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> thenByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> thenByPasswordHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'passwordHash', Sort.asc);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QAfterSortBy> thenByPasswordHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'passwordHash', Sort.desc);
    });
  }
}

extension BurnerHashQueryWhereDistinct
    on QueryBuilder<BurnerHash, BurnerHash, QDistinct> {
  QueryBuilder<BurnerHash, BurnerHash, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QDistinct> distinctByLabel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'label', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QDistinct> distinctByPasswordHash(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'passwordHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BurnerHash, BurnerHash, QDistinct> distinctBySalt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'salt');
    });
  }
}

extension BurnerHashQueryProperty
    on QueryBuilder<BurnerHash, BurnerHash, QQueryProperty> {
  QueryBuilder<BurnerHash, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BurnerHash, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<BurnerHash, String, QQueryOperations> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'label');
    });
  }

  QueryBuilder<BurnerHash, String, QQueryOperations> passwordHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'passwordHash');
    });
  }

  QueryBuilder<BurnerHash, List<int>?, QQueryOperations> saltProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'salt');
    });
  }
}
