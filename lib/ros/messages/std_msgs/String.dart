import 'dart:typed_data';

import '/ros/messages/Float32.dart';

import '../Float32List.dart';
import '../String.dart';
import '../../ros_message.dart';
import '../UInt32.dart';

class StdMsgsString extends RosMessage {
  final RosString _data = RosString();

  String get data => _data.val;

  set data(value) {
    _data.val = value;
  }

  StdMsgsString()
      : super('string data', 'std_msgs/String',
            '992ce8a1687cec8c8bd883ec73ca41d1') {
    params.add(_data);
  }
}

class StdMsgsFloat32 extends RosMessage {
  final RosFloat32 _data = RosFloat32();

  double get data => _data.val;

  set data(double value) {
    _data.val = value;
  }

  StdMsgsFloat32()
      : super('float32 data', 'std_msgs/Float32',
            '73fcbf46b49191e672908e50842a83d4') {
    params.add(_data);
  }
}

class StdMsgsMultiArrayDimension extends RosMessage {
  final RosString _label = RosString();
  final RosUint32 _size = RosUint32();
  final RosUint32 _stride = RosUint32();

  String get label => _label.val;

  set label(String value) {
    _label.val = value;
  }

  int get size => _size.val;

  set size(int value) {
    _size.val = value;
  }

  int get stride => _stride.val;

  set stride(int value) {
    _stride.val = value;
  }

  StdMsgsMultiArrayDimension()
      : super('MultiArrayDimension data', 'std_msgs/MultiArrayDimension',
            '4cd0c83a8683deae40ecdac60e53bfa8') {
    params.add(_label);
    params.add(_size);
    params.add(_stride);
  }
}

class StdMsgsMultiArrayLayout extends RosMessage {
  final StdMsgsMultiArrayDimension dim = StdMsgsMultiArrayDimension();
  final RosUint32 _data_offset = RosUint32();

  int get data_offset => _data_offset.val;

  set data_offset(int value) {
    _data_offset.val = value;
  }

  StdMsgsMultiArrayLayout()
      : super('MultiArrayLayout data', 'std_msgs/MultiArrayLayout',
            '0fed2a11c13e11c5571b4e2a995a91a3') {
    params.add(dim);
    params.add(_data_offset);
  }
}

class StdMsgsFloat32MultiArray extends RosMessage {
  StdMsgsMultiArrayLayout layout = StdMsgsMultiArrayLayout();

  final RosFloat32List _data = RosFloat32List();

  Float32List get data => _data.list;

  set data(Float32List value) {
    _data.list = value;
  }

  StdMsgsFloat32MultiArray()
      : super('Float32MultiArray data', 'std_msgs/Float32MultiArray',
            '6a40e0ffa6a17a503ac3f8616991b1f6') {
    params.add(layout);
    params.add(_data);
  }
}
