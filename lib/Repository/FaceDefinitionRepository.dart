import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../extensions/list.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FaceDefinitionRepository {
  late Box<FaceDefinitionEntity> _box;
  static bool _isInit = false;

  FaceDefinitionRepository._() {
    _init();
  }

  static final FaceDefinitionRepository _instance =
      FaceDefinitionRepository._();

  factory FaceDefinitionRepository() {
    return _instance;
  }

  Future<void> _init() async {
    if (_isInit) return;
    try {
      Hive.registerAdapter(FaceDefinitionEntityAdaptor());
      //
    } catch (ex) {}
    //_box = Hive.box<FaceDefinitionEntity>('FaceDefinition ');
    _box = await Hive.openBox<FaceDefinitionEntity>('FaceDefinition');
    _isInit = true;
  }

  Future<FaceDefinitionEntity> AddOrUpdate(FaceDefinitionEntity obj) async {
    await _init();
    var id = "";
    if (obj.id == null || obj.id == '') {
      id = UniqueKey().toString();
      obj.id = id;
    }
    await _box.put(obj.id, obj);
    return obj;
  }

  Future<FaceDefinitionEntity> AddOrUpdateWithCondition(
      FaceDefinitionEntity obj,
      bool Function(FaceDefinitionEntity) predicate) async {
    await _init();

    FaceDefinitionEntity? oldObj = _box.values.where(predicate).firstOrNull();
    if (oldObj != null) {
      obj.id = oldObj.id;
    }

    await _box.put(obj.id, obj);
    return obj;
  }

  Future<bool> Delete(String id) async {
    await _init();
    await _box.delete(id);
    return true;
  }

  Future<FaceDefinitionEntity?> Get(String id) async {
    await _init();
    return _box.get(id);
  }

  Future<List<FaceDefinitionEntity>> GetAll() async {
    await _init();

    return _box.values.toList();
  }

  Future<List<FaceDefinitionEntity>> GetByName(String name) async {
    await _init();
    return _box.values.where((e) => e.fullname.contains(name)).toList();
  }

  Future<List<FaceDefinitionEntity>> Filter(
      bool Function(FaceDefinitionEntity) predicate,
      {int? skip,
      int? take}) async {
    await _init();

    var temp = _box.values.where(predicate);

    if (skip != null) temp = temp.skip(skip);

    if (take != null) temp = temp.take(take);

    return temp.toList();
  }
}

@HiveType(typeId: 0)
class FaceDefinitionEntity {
  //u may want to: extends HiveObject
  @HiveField(0)
  String id = UniqueKey().toString();
  @HiveField(1)
  String fullname = "";
  @HiveField(2)
  List<double> vector = [];
  @HiveField(3)
  List<int> image = [];

  FaceDefinitionEntity(
      {required this.fullname,
      required this.vector,
      required this.image,
      String? id}) {
    if (id == null) {
      this.id = UniqueKey().toString();
    } else {
      this.id = id!;
    }
  }

  String toString() {
    return "$id $fullname $vector";
  }
}

class FaceDefinitionEntityAdaptor extends TypeAdapter<FaceDefinitionEntity> {
  // check your FaceDefinitionEntity annotation
  @override
  final int typeId = 0; //@HiveType(typeId: 0)

  @override
  FaceDefinitionEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    //  ..writeByte(4)
    final fields = <int, dynamic>{
      //..writeByte(0) : ..write(obj.id)
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FaceDefinitionEntity(
        id: fields[0],
        fullname: fields[1],
        vector: fields[2],
        image: fields[3]);
  }

  @override
  void write(BinaryWriter writer, FaceDefinitionEntity obj) {
    writer
      ..writeByte(4) //number of property's obj
      ..writeByte(0)  //@HiveField(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullname)
      ..writeByte(2)
      ..write(obj.vector)
      ..writeByte(3)
      ..write(obj.image);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceDefinitionEntityAdaptor &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
