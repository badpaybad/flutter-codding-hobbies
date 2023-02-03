import 'messages/geometry_msgs/Pose.dart';
import 'messages/geometry_msgs/PoseStamped.dart';
import 'messages/geometry_msgs/Transform.dart';
import 'messages/geometry_msgs/TransformStamped.dart';
import 'messages/geometry_msgs/Twist.dart';
import 'messages/nav_msgs/OccupancyGrid.dart';
import 'messages/nav_msgs/Odometry.dart';
import 'messages/sensor_msgs/CompressedImage.dart';
import 'messages/sensor_msgs/LaserScan.dart';
import 'messages/std_msgs/String.dart';
import 'messages/tf/tfMessage.dart';
import 'ros_message.dart';

class RosTopic<T extends RosMessage> {
  static RosMessage createInstanceByType<T extends RosMessage>({Type? type}) {
    ///how to do similar return new T() ; or return T();

    if (type is SensorMsgsLaserScan || T == SensorMsgsLaserScan) {
      return SensorMsgsLaserScan();
    }
    if (type is NavMsgsOdometry || T == NavMsgsOdometry) {
      return NavMsgsOdometry();
    }
    if (type is NavMsgsOccupancyGrid || T == NavMsgsOccupancyGrid) {
      return NavMsgsOccupancyGrid();
    }
    if (type is GeometryMsgsTwist || T == GeometryMsgsTwist) {
      return GeometryMsgsTwist();
    }
    if (type is GeometryMsgsTransform || T == GeometryMsgsTransform) {
      return GeometryMsgsTransform();
    }
    if (type is GeometryMsgsPose || T == GeometryMsgsPose) {
      return GeometryMsgsPose();
    }
    if (type is GeometryMsgsTransformStamped ||
        T == GeometryMsgsTransformStamped) {
      return GeometryMsgsTransformStamped();
    }
    if (type is SensorMsgsCompressedImage || T == SensorMsgsCompressedImage) {
      return SensorMsgsCompressedImage();
    }
    if (type is TfTfMessage || T == TfTfMessage) {
      return TfTfMessage();
    }
    if (T is StdMsgsString || T == StdMsgsString) {
      return StdMsgsString();
    }

    if (type is PoseStamped || T == PoseStamped) {
      return PoseStamped();
    }
    throw Exception("_createInstanceByType.ERR Not found definition of $T");
  }

  String name;
  late T msg;

  RosTopic(String topicname, {T? exitedMsg})
      : name = topicname.replaceAll("//", "/") {
    if (exitedMsg == null) {
      msg = createInstanceByType<T>() as T;
    } else {
      msg = createInstanceByType<T>(type: exitedMsg.runtimeType) as T;
    }
  }

  @override
  String toString() {
    return "#ROS#topic:$name#ROS#msgType:${msg.toString()}";
  }

  String toStringMetaInfo() {
    return "#ROS#topic:$name#ROS#msgType:${msg.toStringMetaInfo()}";
  }
}
