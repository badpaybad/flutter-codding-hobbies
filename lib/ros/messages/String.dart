import 'dart:convert';
import 'dart:typed_data';
import '../ros_message.dart';

import '../int_apis.dart';

class RosString implements BinaryConvertable {
  String val;

  RosString({String? value}) : val = value ?? '';

  @override
  int fromBytes(Uint8List bytes, {int offset = 0}) {
    var size = ByteData.view(bytes.buffer).getUint32(offset, Endian.little);
    offset += 4;
    val = utf8.decode(bytes.sublist(offset, offset + size));
    return 4 + size;
  }

  @override
  List<int> toBytes() {
    var bytes = <int>[];
    var encoded = utf8.encode(val);
    bytes.addAll(encoded.length.toBytes());
    bytes.addAll(encoded);
    return bytes;
  }

  @override
  String toString() {
    return val;
  }
}