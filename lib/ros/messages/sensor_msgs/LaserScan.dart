import 'dart:typed_data';

import '../Float32.dart';
import '../Float64List.dart';

import '../Float32List.dart';
import '../Float64.dart';
import '../UInt8List.dart';
import '../../ros_message.dart';
import '../String.dart';
import '../std_msgs/Header.dart';

class SensorMsgsLaserScan extends RosMessage {
  //https://docs.ros.org/en/melodic/api/sensor_msgs/html/msg/LaserScan.html
  final StdMsgsHeader header = StdMsgsHeader();

  // __slots__ = ['header','angle_min','angle_max','angle_increment','time_increment','scan_time','range_min','range_max','ranges','intensities']
  // _slot_types = ['std_msgs/Header','float32','float32','float32','float32','float32','float32','float32','float32[]','float32[]']

  final RosFloat32 _angle_min = RosFloat32();
  final RosFloat32 _angle_max = RosFloat32();

  final RosFloat32 _angle_increment = RosFloat32();

  final RosFloat32 _time_increment = RosFloat32();

  final RosFloat32 _scan_time = RosFloat32();

  final RosFloat32 _range_min = RosFloat32();
  final RosFloat32 _range_max = RosFloat32();

  final RosFloat32List _ranges = RosFloat32List();
  final RosFloat32List _intensities = RosFloat32List();

  double get angle_min => _angle_min.val;

  set angle_min(double value) {
    _angle_min.val = value;
  }

  double get angle_max => _angle_max.val;

  set angle_max(double value) {
    _angle_max.val = value;
  }

  double get angle_increment => _angle_increment.val;

  set angle_increment(double value) {
    _angle_increment.val = value;
  }

  double get time_increment => _time_increment.val;

  set time_increment(double value) {
    _time_increment.val = value;
  }

  double get scan_time => _scan_time.val;

  set scan_time(double value) {
    _scan_time.val = value;
  }

  double get range_min => _range_min.val;

  set range_min(double value) {
    _range_min.val = value;
  }

  double get range_max => _range_max.val;

  set range_max(double value) {
    _range_max.val = value;
  }

  Float32List get ranges => _ranges.list;

  set ranges(Float32List value) {
    _ranges.list = value;
  }

  Float32List get intensities => _intensities.list;

  set intensities(Float32List value) {
    _intensities.list = value;
  }

  SensorMsgsLaserScan()
      : super('Single scan from a planar laser range-finder',
            'sensor_msgs/LaserScan', '90c7ef2dc6895d81024acba2ac42f369') {
    //['header','angle_min','angle_max','angle_increment','time_increment','scan_time','range_min','range_max','ranges','intensities']
    params.add(header);

    params.add(_angle_min);
    params.add(_angle_max);

    params.add(_angle_increment);

    params.add(_time_increment);

    params.add(_scan_time);

    params.add(_range_min);
    params.add(_range_max);

    params.add(_ranges);
    params.add(_intensities);
  }
  //
  // @override
  // List<int> toBytes() {
  //   var bytes = <int>[];
  //   for (var param in params) {
  //     var paramBytes = param.toBytes();
  //     bytes.addAll(paramBytes);
  //   }
  //   return bytes;
  // }
  //
  // @override
  // int fromBytes(Uint8List bytes, {int offset = 0}) {
  //   var size = 0;
  //   for (var param in params) {
  //     size += param.fromBytes(bytes, offset: offset + size);
  //   }
  //   return size;
  // }

}
