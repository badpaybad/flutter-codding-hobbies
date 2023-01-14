import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../MessageBus.dart';
import 'messages/geometry_msgs/Twist.dart';
import 'messages/nav_msgs/OccupancyGrid.dart';
import 'messages/sensor_msgs/CompressedImage.dart';
import 'messages/sensor_msgs/LaserScan.dart';
import 'ros_client.dart';
import 'ros_config.dart';
import 'ros_nodes.dart';
import 'messages/std_msgs/String.dart';
import 'ros_publisher.dart';
import 'ros_topic.dart';

//https://github.com/Sashiri/ros_nodes
//http://wiki.ros.org/rostopic
class RosAppContext extends ChangeNotifier {
  RosAppContext._() {}

  static final RosAppContext instance = RosAppContext._();

  final StreamController<List<int>> _streamToRedis =
      StreamController<List<int>>.broadcast();

  ui.Image? _mapImage;

  ui.Image? get mapImage => _mapImage;

  Uint8List? _visionImage;

  Uint8List? get visionImage => _visionImage;

  GeometryMsgsTwist? _veliocity;

  GeometryMsgsTwist? get veliocity => _veliocity;

  bool _visionAvailable = false;

  bool get visionAvailable => _visionAvailable;

  bool _veliocityAvailable = false;

  bool get veliocityAvailable => _veliocityAvailable;

  bool _mapAvailable = false;

  bool get mapAvailable => _mapAvailable;

  // RosNotifier(RosConfig config):_rosClient = RosClient(config) {
  //      // init();
  // }
  bool _isInited = false;

  Future<void> init(RosConfig config) async {
    if (_isInited) return;
    _isInited = true;
    try {
      print('RosNotifier START initializing ros subscribers');

      _rosClient = RosClient(config);

      await _rosClient!.init();

      await Future.wait([
        //_registerTopic_duflutter_test(),
        //_subscribeTopic_duflutter_test(),
        _subscribeToCamera(),
        //_subscribeToMap(),
        //_subscribeToVeliocity(),
        //_subscribeTopicScan()
      ]);

      print('RosNotifier DONE initializing ros subscribers');

      //await _registerTopic_duflutter_test_topicTestFloat32();
      // await _subscribeTopic_duflutter_test_topicTestFloat32();
      //   Timer.periodic(Duration(seconds: 5), (timer) async {
      //     await publishToTopic_topicTestFloat32();
      //   });
    } catch (ex) {
      print("RosNotifier.init: ERR: $ex");

      _isInited = false;
      await Future.delayed(const Duration(seconds: 2));
      try {
        _rosClient!.close();
      } catch (ex1) {}
      await Future.delayed(const Duration(seconds: 2));
      await init(config);
    }

    await MessageBus.instance.ensureRedisCommandInit;

    _streamToRedis.stream.listen((event) async {

      await MessageBus.instance
          .RedisEnqueue("coddinghobbies:livestream:image:localstream", {"data":event});


    });
  }

  final _topicScan = RosTopic('/scan', SensorMsgsLaserScan());

  Future<void> _subscribeTopicScan() async {
    var subscriber = await _rosClient!.subscribe(_topicScan);
    subscriber.onValueUpdate!.listen((msg) {
      // print("_topicScan");
      // print(msg.ranges);

      // notifyListeners();
    });
  }

  final _topicTestFloat32 =
      RosTopic('/duflutter/test_SensorMsgsLaserScan', SensorMsgsLaserScan());
  RosPublisher? _cmd_topicTestFloat32;

  Future<void> _registerTopic_duflutter_test_topicTestFloat32() async {
    //await _rosClient!.unregister(_topicTestFloat32);
    _cmd_topicTestFloat32 = await _rosClient!.register(_topicTestFloat32);

    //_cmdTestTopicString?.startPublishing();
  }

  Future<void> _subscribeTopic_duflutter_test_topicTestFloat32() async {
    //await _rosClient!.unsubscribe(_topicTestFloat32);

    var subscriber = await _rosClient!.subscribe(_topicTestFloat32);
    subscriber.onValueUpdate!.listen((msg) {
      print("duflutter_test----#callback#begin");
      print(msg.ranges);
      print("duflutter_test----#callback#end");
      notifyListeners();
    });
  }

  Future<void> publishToTopic_topicTestFloat32() async {
    var msg = SensorMsgsLaserScan();
    msg.ranges = Float32List.fromList([
      DateTime.now().millisecondsSinceEpoch.toDouble(),
      DateTime.now().millisecondsSinceEpoch.toDouble()
    ]);
    _cmd_topicTestFloat32?.topic.msg = msg;
    _cmd_topicTestFloat32?.publishData();
    // Timer.periodic(Duration(seconds: 2), (timer) async {
    //   print("publishTestCmdVel: start");
    //
    //   var msg=StdMsgsString();
    //   msg.data="${DateTime.now().toIso8601String()}";
    //
    //   _cmdTestTopicString?.topic?.msg=msg;
    //   await _cmdTestTopicString?.publishData();
    //
    //   print("publishTestCmdVel: end");
    // });
  }

  final _topicTestString = RosTopic('/duflutter/test', StdMsgsString());
  RosPublisher? _cmdTestTopicString;

  Future<void> _registerTopic_duflutter_test() async {
    //await _rosClient!.unregister(_topicTestString);
    _cmdTestTopicString = await _rosClient!.register(_topicTestString);

    //_cmdTestTopicString?.startPublishing();
  }

  Future<void> _subscribeTopic_duflutter_test() async {
    //await _rosClient!.unsubscribe(_topicTestString);

    var subscriber = await _rosClient!.subscribe(_topicTestString);
    subscriber.onValueUpdate!.listen((msg) {
      print("duflutter_test----#callback#begin");
      print(msg.data);
      print("duflutter_test----#callback#end");
      notifyListeners();
    });
  }

  Future<void> publishToTopicTest() async {
    var strMsg = StdMsgsString();
    var temp = "";
    for (var i = 0; i < 1000; i++) {
      temp += " $i";
    }
    var len = "$temp".length;
    strMsg.data = "${DateTime.now().toIso8601String()} : $len";
    _cmdTestTopicString?.topic.msg = strMsg;
    _cmdTestTopicString?.publishData();
    // Timer.periodic(Duration(seconds: 2), (timer) async {
    //   print("publishTestCmdVel: start");
    //
    //   var msg=StdMsgsString();
    //   msg.data="${DateTime.now().toIso8601String()}";
    //
    //   _cmdTestTopicString?.topic?.msg=msg;
    //   await _cmdTestTopicString?.publishData();
    //
    //   print("publishTestCmdVel: end");
    // });
  }

  @override
  void dispose() {
    _closeSubscribtions();
    super.dispose();
  }

  RosClient? _rosClient;

  final _visionTopic =
      RosTopic('/coddinghobbies/cameraimagecompressed', SensorMsgsCompressedImage());

  final _mapTopic = RosTopic('map', NavMsgsOccupancyGrid());

  final _veliocityTopic = RosTopic('cmd_vel', GeometryMsgsTwist());

  void _mapUpdate(ui.Image val) {
    _mapImage = val;

    _mapAvailable = true;
    notifyListeners();
  }

  Future<void> _notifyToListener() async {}

  Future<void> _subscribeToMap() async {
    var subscriber = await _rosClient!.subscribe(_mapTopic);
    subscriber.onValueUpdate!.listen((msgRos) {
      //print("_subscribeToMap");
      //print(msgRos.toString());
      var msg = msgRos as GridImageConverter;
      ui.decodeImageFromPixels(
        msg.toRGBA(),
        msg.info.width,
        msg.info.width,
        ui.PixelFormat.rgba8888,
        _mapUpdate,
      );
    });

    notifyListeners();
  }

  Future<void> _subscribeToCamera() async {
    var subscriber = await _rosClient!.subscribe(_visionTopic);
    subscriber.onValueUpdate!.listen((msg) {
      //print("_subscribeToCamera");
      //print(msg.format);
      _visionImage = msg.data;

      _streamToRedis.add(msg.data);

      notifyListeners();
    });

    _visionAvailable = true;
    notifyListeners();
  }

  Future<void> _subscribeToVeliocity() async {
    var subscriber = await _rosClient!.subscribe(_veliocityTopic);
    subscriber.onValueUpdate!.listen((msg) {
      //var msg= msgRos as GeometryMsgsTwist;
      _veliocity = msg;
      //print("_veliocity ---------------");
      //print(_veliocity);
      notifyListeners();
    });

    _veliocityAvailable = true;
    notifyListeners();
  }

  Future<void> _closeSubscribtions() async {
    if (visionAvailable) {
      await _rosClient!.unsubscribe(_visionTopic);
      _visionAvailable = false;
    }
    if (mapAvailable) {
      await _rosClient!.unsubscribe(_mapTopic);
      _mapAvailable = false;
    }
    if (veliocityAvailable) {
      await _rosClient!.unsubscribe(_veliocityTopic);
      _veliocityAvailable = false;
    }
    notifyListeners();
    await _rosClient!.close();
  }

  Future<String> findIpLan() async {
    String _ipLan = "0.0.0.0";
    for (var interface in await NetworkInterface.list()) {
      print('----- Interface: ${interface.name}');
      for (var addr in interface.addresses) {
        print(
            '${addr.address} _ ${addr.host} _ ${addr.isLoopback} ${addr.rawAddress} ${addr.type.name}');

        if (addr.address.contains("192.168")) {
          _ipLan = addr.address;
          break;
        }
      }
    }
    return _ipLan;
  }
}
//
// class GridImageConverter extends NavMsgsOccupancyGrid {
//   Uint8List toRGBA() {
//     var buffor = BytesBuilder();
//     for (var value in data) {
//       switch (value) {
//         case -1:
//           buffor.add([77, 77, 77, 255]);
//           break;
//         default:
//           var grayscale = (((100 - value) / 100.0) * 255).round().toUnsigned(8);
//           var r = grayscale;
//           var b = grayscale;
//           var g = grayscale;
//           const a = 255;
//           buffor.add([r, g, b, a]);
//       }
//     }
//     return buffor.takeBytes();
//   }
// }
