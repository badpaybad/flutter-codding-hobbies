import '../geometry_msgs/Point.dart';
import '../geometry_msgs/Quaternion.dart';
import '../../ros_message.dart';
import '../Float64.dart';


class GeometryMsgsPose extends RosMessage {
  var position = GeometryMsgsPoint();
  var orientation = GeometryMsgsQuaternion();

  GeometryMsgsPose()
      : super('pose data', 'geometry_msgs/Pose',
      'e45d45a5a1ce597b249e23fb30fc871f') {
    params.add(position);
    params.add(orientation);
  }
}
