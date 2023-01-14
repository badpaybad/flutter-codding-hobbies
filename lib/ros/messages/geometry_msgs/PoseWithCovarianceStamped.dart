import '../../ros_message.dart';
import '../geometry_msgs/PoseWithCovariance.dart';
import '../std_msgs/Header.dart';


class PoseWithCovarianceStamped extends RosMessage {
  var header = StdMsgsHeader();
  var pose = PoseWithCovariance();

  PoseWithCovarianceStamped()
      : super(
      'pose with covariance and stamped',
      'geometry_msgs/PoseWithCovarianceStamped',
      '953b798c0f514ff060a53a3498ce6246') {
    params.add(header);
    params.add(pose);
  }
}
