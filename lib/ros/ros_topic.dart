import 'ros_message.dart';

class RosTopic<Message extends RosMessage> {
   String name;
   Message msg;
  RosTopic(String tname, this.msg): name=tname.replaceAll("//","/");

  @override
  String toString(){
    return "#ROS#topic:$name#ROS#msgType:${msg.toString()}";
  }

   String toStringMetaInfo(){
     return "#ROS#topic:$name#ROS#msgType:${msg.toStringMetaInfo()}";
   }
}
