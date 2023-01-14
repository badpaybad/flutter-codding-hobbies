import '../geometry_msgs/TransformStamped.dart';
import '../../messages/List.dart';
import '../../ros_message.dart';

class TfTfMessage extends RosMessage {
  final _transforms = RosList(() => GeometryMsgsTransformStamped());

  List<GeometryMsgsTransformStamped> get transforms => _transforms.list??[];

  TfTfMessage()
      : super('transform stamped data', 'tf/tfMessage',
            '94810edda583a504dfda3829e70d7eec') {
    params.add(_transforms);
  }
}
