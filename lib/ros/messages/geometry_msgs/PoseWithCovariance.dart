import '../../ros_message.dart';
import '../geometry_msgs/Pose.dart';
import '../Float64List.dart';


class PoseWithCovariance extends RosMessage {
  var pose = GeometryMsgsPose();
  var covariance = RosFloat64List(fixedLength: 36);

  PoseWithCovariance()
      : super(
      'pose in free space with uncertainty',
      'geometry_msgs/PoseWithCovariance',
      'c23e848cf1b7533a8d7c259073a97e6f') {
    params.add(pose);
    params.add(covariance);
  }
}
