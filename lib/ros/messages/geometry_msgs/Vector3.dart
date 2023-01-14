import '../../ros_message.dart';
import '../Float64.dart';

class GeometryMsgsVector3 extends RosMessage {
  final RosFloat64 _x = RosFloat64();
  final RosFloat64 _y = RosFloat64();
  final RosFloat64 _z = RosFloat64();

  double get x => _x.val;
  set x(double value) {
    _x.val = value;
  }

  double get y => _y.val;
  set y(double value) {
    _y.val = value;
  }

  double get z => _z.val;
  set z(double value) {
    _z.val = value;
  }

  GeometryMsgsVector3()
      : super('vector3 data', 'geometry_msgs/Vector3',
      '4a842b65f413084dc2b10fb484ea7f17') {
    params.add(_x);
    params.add(_y);
    params.add(_z);
  }
}
