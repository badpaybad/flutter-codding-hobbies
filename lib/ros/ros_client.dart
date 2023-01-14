import 'dart:async';
import 'xmlrpc/client.dart' as xml_rpc;
import 'package:xml/xml.dart';
import 'xmlrpc/converter.dart';
import 'xmlrpc/xmlrpc_server.dart';
import 'ros_config.dart';
import 'ros_topic.dart';
import 'ros_message.dart';
import 'ros_publisher.dart';
import 'ros_subscriber.dart';
import 'protocol_info.dart';
//https://github.com/Sashiri/ros_nodes
//http://wiki.ros.org/rostopic
//http://library.isr.ist.utl.pt/docs/roswiki/ROS(2f)Slave_API.html
class RosClient {
  final RosConfig config;
  late final XmlRpcServer _server;

  final Map<String, RosPublisher> _topicPublishers = {};
  final Map<String, RosSubscriber> _topicSubscribers = {};

  RosClient(this.config) {
    _server = SimpleXmlRpcServer(
      host: config.host,
      port: config.port,
      handler: XmlRpcHandler(
        methods: {
          'getBusStats': onGetBusStats,
          'getBusInfo': onGetBusInfo,
          'getMasterUri': onGetMasterUri,
          'shutdown': onShutdown,
          'getPid': onGetPid,
          'getSubscriptions': onGetSubscriptions,
          'getPublications': onGetPublications,
          'paramUpdate': onParamUpdate,
          'publisherUpdate': onPublisherUpdate,
          'requestTopic': onRequestTopic,
        },
        codecs: List<Codec>.unmodifiable(<Codec>[
          ...standardCodecs,
          i8Codec,
          nilCodec,
        ]),
      ),
    );
  }

  Future<void> init() async {
    await _server.start();
    print(
        "#ROSClient# ROS_MASTER_URI:${config.masterUri} HOSTNAME: ${_server.HttpHost}:${_server.HttpPort}");
  }

  Future<void> close() async {
    var subcribtionsToClose = _topicSubscribers.values.map((subscriber) =>
        unsubscribe(subscriber.topic)
            .timeout(Duration(seconds: 3), onTimeout: subscriber.forceStop));

    var publishersToClose = _topicPublishers.values.map((publisher) =>
        unregister(publisher.topic)
            .timeout(Duration(seconds: 3), onTimeout: () => publisher.close()));

    await Future.wait([...subcribtionsToClose, ...publishersToClose]);
    return _server.stop();
  }

  dynamic onGetBusStats(String callerId) {
    final publishStats = _topicPublishers.entries.map<List<dynamic>>(
      (e) {
        return [e.key, 0, []];
      },
    );
    final subscribeStats = [];
    final serviceStats = [0, 0, 0];

    return [
      1,
      'Not implemented',
      [
        publishStats,
        subscribeStats,
        serviceStats,
      ],
    ];
  }

  dynamic onGetBusInfo(String callerId) {
    return [
      1,
      'Not implemented',
      [],
    ];
  }

  dynamic onGetMasterUri(String callerId) {
    return [
      1,
      'Node is connected to ${config.masterUri}',
      config.masterUri,
    ];
  }

  void onShutdown(String callerId, [String msg = '']) {
    throw UnimplementedError();
  }

  void onGetPid(String callerId) {
    throw UnimplementedError();
  }

  void onGetSubscriptions(String callerId) {
    throw UnimplementedError();
  }

  void onGetPublications(String callerId) {
    throw UnimplementedError();
  }

  void onParamUpdate(
      String callerId, String parameterKey, dynamic parameterValue) {
    throw UnimplementedError();
  }

  Future<dynamic> onPublisherUpdate(
      String callerId, String topic, List<dynamic> publishers) async {
    print("onPublisherUpdate: $topic");
    var listPublisherToUpdate =
        publishers.map<String>((e) => e.toString()).toList();

    for (var p in listPublisherToUpdate) {
      print(p);
    }
    if (!_topicSubscribers.containsKey(topic)) {
      return [
        -1,
        'No subscribers for this topic',
        1,
      ];
    }

    var sub = _topicSubscribers[topic]!;
    var ignored = await sub.updatePublisherList(listPublisherToUpdate);

    return [
      1,
      'Updated subscribers',
      ignored,
    ];
  }

  dynamic onRequestTopic(
      String callerId, String topic, List<dynamic> protocols) {
    print("onRequestTopic: $topic");
    for (var p in protocols) {
      print(p);
    }
    final parsedProtocols = protocols.map<ProtocolInfo>((x) => ProtocolInfo(
          x[0],
          x.sublist(1), //ip , port
        ));

    if (!_topicPublishers.containsKey(topic)) {
      return [1, 'No active publishers for topic $topic', []];
    }

    final publisher = _topicPublishers[topic]!;

    final validProtocols = [];
    for (final protocol in parsedProtocols) {
      if (publisher.validateProtocolSettings(protocol)) {
        validProtocols.add([protocol.name, publisher.address, publisher.port]);
      }
    }

    var selectedProtocol =
        validProtocols.firstWhere((element) => true, orElse: () => null);

    return [
      1,
      'ready on ${selectedProtocol[1]}:${selectedProtocol[2]}',
      selectedProtocol ?? []
    ];
  }

  Future<RosPublisher> register(RosTopic topic,
      {int? port, Duration? publishInterval}) async {
    var publisher = RosPublisher(
      topic,
      config.host,
      port: port ?? 0,
      publishInterval: publishInterval ?? const Duration(milliseconds: 500),
    );

    final result = await xml_rpc.call(
      Uri.parse(config.masterUri),
      'registerPublisher',
      [
        '/${config.name}'.replaceAll("//", "/"),
        '/${topic.name}'.replaceAll("//", "/"),
        '${topic.msg.message_type}',
        //'http://${_server.host}:${_server.port}/',
        'http://${_server.HttpHost}:${_server.HttpPort}/',
      ],
    ).catchError((err) async {
      await publisher.close();
      throw err;
    });

    _logInfo("ResgiterTopic", topic, result);

    final code = result[0] as int;
    final statusMessage = result[1] as String;
    final subscriberApis = List<String>.from(result[2]);

    if (code != 1) {
      await publisher.close();
      throw statusMessage;
    }

    _topicPublishers.putIfAbsent(
        '/${topic.name}'.replaceAll("//", "/"), () => publisher);
    return publisher;
  }

  Future<void> unregister(RosTopic topic) async {
    final result =
        await xml_rpc.call(Uri.parse(config.masterUri), 'unregisterPublisher', [
      '/${config.name}'.replaceAll("//", "/"),
      '/${topic.name}'.replaceAll("//", "/"),
      //'http://${_server.host}:${_server.port}/'
      'http://${_server.HttpHost}:${_server.HttpPort}/',
    ]);

    final int code = result[0];
    final String statusMessage = result[1];

    if (code == -1) {
      throw statusMessage;
    }

    final int numUnregistered = result[2];
    if (numUnregistered == 0) {
      return;
    }

    if (_topicPublishers.containsKey('/${topic.name}'.replaceAll("//", "/"))) {
      await _topicPublishers['/${topic.name}'.replaceAll("//", "/")]!.close();
      _topicPublishers.remove('/${topic.name}'.replaceAll("//", "/"));
    }
  }

  void _logInfo(String source, RosTopic topic, dynamic msg) {
    var nodename = '/${config.name}'.replaceAll("//", "/");
    var httpserver = 'http://${_server.HttpHost}:${_server.HttpPort}/';
    print("-----#$source#BEGIN#$nodename#${topic.toStringMetaInfo()}#$httpserver");
    print(msg);
    print("-----#$source#END#");
  }

  Future<RosSubscriber<Message>> subscribe<Message extends RosMessage>(
      RosTopic<Message> topic) async {
    var topicname = '/${topic.name}'.replaceAll("//", "/");

    if (_topicSubscribers.containsKey(topicname)) {
      return _topicSubscribers[topicname] as RosSubscriber<Message>;
    }

    var sub = RosSubscriber<Message>(topic, config);

    final result =
        await xml_rpc.call(Uri.parse(config.masterUri), 'registerSubscriber', [
      '/${config.name}'.replaceAll("//", "/"),
      topicname,
      '${topic.msg.message_type}'.trim(),
      //'http://${_server.host}:${_server.port}/'
      'http://${_server.HttpHost}:${_server.HttpPort}/'
    ]);

    _logInfo("RosSubscriber", topic, result);

    var code = result[0] as int;
    var status = result[1] as String;

    if (code == -1) {
      throw status;
    }

    sub = _topicSubscribers.putIfAbsent(topicname, () => sub)
        as RosSubscriber<Message>;
    var publishers = List<String>.from(result[2]);

    await sub.updatePublisherList(publishers);
    return sub;
  }

  Future<void> unsubscribe(RosTopic topic) async {
    final result = await xml_rpc
        .call(Uri.parse(config.masterUri), 'unregisterSubscriber', [
      '/${config.name}'.replaceAll("//", "/"),
      '/${topic.name}'.replaceAll("//", "/"),
      // 'http://${_server.host}:${_server.port}/',
      'http://${_server.HttpHost}:${_server.HttpPort}/',
    ]);

    var code = result[0] as int;
    var status = result[1] as String;

    if (code == -1) {
      throw status;
    }

    var numUnsubscribed = result[2] as int;
    if (numUnsubscribed > 0) {
      _topicPublishers.removeWhere((key, _) => key == topic.msg.message_type);
    }
  }
}

//
// class RosClient {
//    RosConfig  config ;
//    XmlRpcServer ? _server;
//
//   final Map<String, RosPublisher> _topicPublishers = {};
//   final Map<String, RosSubscriber> _topicSubscribers = {};
//
//   RosClient(this.config) {
//     print("ROS_MASTER_URI: ${config!.masterUri}");
//
//     _server = XmlRpcServer(host: config!.host, port: config!.port);
//
//     print( "ROS Client ----");
//     print(config!.toString());
//
//     _server!.bind('getBusStats', onGetBusStats);
//     _server!.bind('getBusInfo', onGetBusInfo);
//     _server!.bind('getMasterUri', onGetMasterUri);
//     _server!.bind('shutdown', onShutdown);
//     _server!.bind('getPid', onGetPid);
//     _server!.bind('getSubscriptions', onGetSubscriptions);
//     _server!.bind('getPublications', onGetPublications);
//     _server!.bind('paramUpdate', onParamUpdate);
//     _server!.bind('publisherUpdate', onPublisherUpdate);
//     _server!.bind('requestTopic', onRequestTopic);
//   }
//
//   Future<void> init() async {
//     await _server!.startServer();
//   }
//
//   Future<void> close() async {
//     var subcribtionsToClose = _topicSubscribers.values.map((subscriber) =>
//         unsubscribe(subscriber!.topic!)
//             .timeout(Duration(seconds: 5), onTimeout: subscriber.forceStop));
//
//     var publishersToClose = _topicPublishers.values.map((publisher) =>
//         unregister(publisher!.topic!)
//             .timeout(Duration(seconds: 5), onTimeout: () => publisher.close()));
//
//     await Future.wait([...subcribtionsToClose, ...publishersToClose]);
//     return _server!.stopServer();
//   }
//
//   Future<XmlDocument> onGetBusStats(List<dynamic> params) async {
//     final callerId = params[0] as String;
//     final publishStats = _topicPublishers.entries.map<List<dynamic>>(
//       (e) {
//         return [e.key, 0, []];
//       },
//     );
//     final subscribeStats = [];
//     final serviceStats = [0, 0, 0];
//
//     return generateXmlResponse([
//       [
//         1,
//         'Not implemented',
//         [
//           publishStats,
//           subscribeStats,
//           serviceStats,
//         ],
//       ]
//     ]);
//   }
//
//   Future<XmlDocument> onGetBusInfo(List<dynamic> params) async {
//     final callerId = params[0] as String;
//
//     return generateXmlResponse([
//       [
//         1,
//         'Not implemented',
//         [],
//       ]
//     ]);
//   }
//
//   Future<XmlDocument> onPublisherUpdate(List<dynamic> params) async {
//     final callerId = params[0] as String;
//     final topic = params[1] as String;
//     final publishers = List<String>.from(params[2]);
//
//     if (!_topicSubscribers.containsKey(topic)) {
//       return generateXmlResponse([
//         -1,
//         'No subscribers for this topic',
//         1,
//       ]);
//     }
//
//     var sub = _topicSubscribers[topic];
//     var ignored = await sub!.updatePublisherList(publishers);
//
//     return generateXmlResponse([
//       [
//         1,
//         'Updated subscribers',
//         ignored,
//       ]
//     ]);
//   }
//
//   Future<XmlDocument> onParamUpdate(List<dynamic> params) async {
//     final callerId = params[0] as String;
//     final parameter_key = params[1] as String;
//     final parameter_value = params[2];
//
//     throw UnimplementedError("ROS onParamUpdate not implement");
//   }
//
//   Future<XmlDocument> onGetPublications(List<dynamic> params) async {
//     final callerId = params[0] as String;
//
//     throw UnimplementedError("ROS onGetPublications not implement");
//   }
//
//   Future<XmlDocument> onGetSubscriptions(List<dynamic> params) async {
//     final callerId = params[0] as String;
//
//     throw UnimplementedError("ROS onGetSubscriptions not implement");
//   }
//
//   Future<XmlDocument> onGetPid(List<dynamic> params) async {
//     final callerId = params[0] as String;
//
//     throw UnimplementedError("ROS onGetPid not implement");
//   }
//
//   Future<XmlDocument> onShutdown(List<dynamic> params) async {
//     final callerId = params[0] as String;
//     final msg = params[1] as String;
//
//     throw UnimplementedError("ROS onShutdown not implement");
//   }
//
//   Future<XmlDocument> onGetMasterUri(List<dynamic> params) async {
//     final callerId = params[0] as String;
//
//     return generateXmlResponse([
//       [
//         1,
//         'Node is connected to ${config!.masterUri}',
//         config!.masterUri,
//       ]
//     ]);
//   }
//
//   Future<XmlDocument> onRequestTopic(List<dynamic> params) async {
//     final callerId = params[0] as String;
//     final topic = params[1] as String;
//     final protocols = List<List<dynamic>>.from(params[2])
//         .map<ProtocolInfo>((x) => ProtocolInfo(
//               x[0],
//               x.sublist(1),
//             ));
//
//     if (!_topicPublishers.containsKey(topic)) {
//       return generateXmlResponse([
//         [1, 'No active publishers for topic ${topic}', []]
//       ]);
//     }
//
//     final publisher = _topicPublishers[topic];
//
//     final validProtocols = [];
//     for (final protocol in protocols) {
//       if (publisher!.validateProtocolSettings(protocol)) {
//         validProtocols.add([protocol.name, publisher.address, publisher.port]);
//       }
//     }
//
//     var selectedProtocol =
//         validProtocols.firstWhere((element) => true, orElse: () => null);
//
//     return generateXmlResponse([
//       [
//         1,
//         'ready on ${selectedProtocol[1]}:${selectedProtocol[2]}',
//         selectedProtocol ?? []
//       ]
//     ]);
//   }
//
//   Future<RosPublisher> register(
//       RosTopic topic, int port, Duration publishInterval) async {
//     var publisher = RosPublisher(
//       topic,
//       config!.host,
//       port: port,
//       publishInterval: publishInterval,
//     );
//
//     var rosNodeName = '/${config!.name}';
//     var rosTopicName = '/${topic.name}'.replaceAll('//', '/');
//     var rosTopicMsgType = '${topic.msg.message_type}';
//     var rosHostNameForRpcCallback = 'http://${_server?.host}:${_server?.port}/';
//
//     print("----- ROS topic register info:");
//     print("nodeName: $rosNodeName");
//     print("topicName: $rosTopicName");
//     print("hostName: $rosHostNameForRpcCallback");
//
//     final result = await xml_rpc.call(
//       Uri.parse(config!.masterUri),
//       'registerPublisher',
//       [
//         rosNodeName,
//         rosTopicName,
//         rosTopicMsgType,
//         rosHostNameForRpcCallback,
//       ],
//     ).catchError((err) async {
//       await publisher.close();
//       throw err;
//     });
//
//     print("------------------TopicRegister #response#begin");
//     print(result);
//     print("------------------TopicRegister #response#end");
//
//     final code = result[0] as int;
//     final statusMessage = result[1] as String;
//     final subscriberApis = List<String>.from(result[2]);
//
//     print("----------------");
//     print(statusMessage);
//     for(var s in subscriberApis){
//       print(s);
//     }
//
//     if (code != 1) {
//       await publisher.close();
//       throw statusMessage;
//     }
//
//     _topicPublishers.putIfAbsent('/${topic.name}', () => publisher);
//     return publisher;
//   }
//
//   Future<void> unregister(RosTopic topic) async {
//     var rosNodeName = '/${config!.name}';
//     var rosTopicName = '/${topic.name}'.replaceAll('//', '/');
//
//     var rosHostNameForRpcCallback = 'http://${_server?.host}:${_server?.port}/';
//
//     print("----- ROS topic uregister info:");
//     print("nodeName: $rosNodeName");
//     print("topicName: $rosTopicName");
//     print("hostName: $rosHostNameForRpcCallback");
//
//     final result = await xml_rpc
//         .call(Uri.parse(config!.masterUri), 'unregisterPublisher', [
//       rosNodeName,
//       rosTopicName,
//       rosHostNameForRpcCallback,
//     ]);
//
//     final int code = result[0];
//     final String statusMessage = result[1];
//
//     if (code == -1) {
//       throw statusMessage;
//     }
//
//     final int numUnregistered = result[2];
//     if (numUnregistered == 0) {
//       return;
//     }
//
//     if (_topicPublishers.containsKey('/${topic.name}')) {
//       await _topicPublishers['/${topic.name}']?.close();
//       _topicPublishers.remove('/${topic.name}');
//     }
//   }
//
//   //Future<RosSubscriber<T>> subscribe<T extends RosMessage>(
//   Future<RosSubscriber<T>> subscribe<T extends RosMessage>(
//       RosTopic<T> topic) async {
//     if (_topicSubscribers.containsKey(topic.msg.message_type)) {
//       var tempSub = _topicSubscribers[topic.msg.message_type]!;
//       return tempSub as RosSubscriber<T>;
//     }
//
//     var sub = RosSubscriber<T>(topic, config);
//
//     var rosNodeName = '/${config!.name}';
//     var rosTopicName = '/${topic.name}'.replaceAll('//', '/');
//     var rosTopicMsgType = '${topic.msg.message_type}';
//     var rosHostNameForRpcCallback = 'http://${_server?.host}:${_server?.port}/';
//
//     print("-----ROS#subscriberinfo#$rosHostNameForRpcCallback: ${topic.toStringMetaInfo()}");
//
//     final result = await xml_rpc.call(
//         Uri.parse(config!.masterUri), 'registerSubscriber', [
//       rosNodeName,
//       rosTopicName,
//       rosTopicMsgType,
//       rosHostNameForRpcCallback
//     ]);
//     var code = result[0] as int;
//     var status = result[1] as String;
//
//     if (code == -1) {
//       throw status;
//     }
//
//     print("----RosSubscriber#response#begin");
//     print(result);
//     print("----RosSubscriber#response#end");
//
//     var temp = sub as RosSubscriber<RosMessage>;
//
//     temp = _topicSubscribers!.putIfAbsent('/${topic.name}', () {
//       return temp;
//     });
//
//     sub = temp as RosSubscriber<T>;
//
//     var publishers = List<String>.from(result[2]);
//     await sub.updatePublisherList(publishers);
//     return sub;
//   }
//
//   Future<void> unsubscribe(RosTopic topic) async {
//     var rosNodeName = '/${config!.name}';
//     var rosTopicName = '/${topic.name}'.replaceAll('//', '/');
//     var rosHostNameForRpcCallback = 'http://${_server?.host}:${_server?.port}/';
//
//     print("ROS#unsubscriberinfo#$rosHostNameForRpcCallback: ${topic.toString()}");
//
//     final result = await xml_rpc
//         .call(Uri.parse(config!.masterUri), 'unregisterSubscriber', [
//       rosNodeName,
//       rosTopicName,
//       rosHostNameForRpcCallback,
//     ]);
//
//     var code = result[0] as int;
//     var status = result[1] as String;
//
//     if (code == -1) {
//       throw status;
//     }
//
//     var numUnsubscribed = result[2] as int;
//     if (numUnsubscribed > 0) {
//       _topicPublishers.removeWhere((key, _) => key == topic.msg.message_type);
//     }
//   }
// }
