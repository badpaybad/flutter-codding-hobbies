import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'protocol_info.dart';
import 'ros_message.dart';
import 'ros_topic.dart';
import 'xmlrpc/client.dart' as xml_rpc;

import 'int_apis.dart';
import 'ros_config.dart';
//http://wiki.ros.org/rostopic

class TcpHandShake {
  int size;
  List<String> headers;

  TcpHandShake(this.size, this.headers);
}

extension IterableExtension<T> on Iterable<T> {
  T? firstOrNull() {
    if (length > 0) {
      return first;
    }
    return null;
  }
}

class RosSubscriber<Message extends RosMessage> {
  final Map<String, Socket> _connections = {};
  final StreamController<Message> _valueUpdate;
  RosConfig config;

  final RosTopic<Message> topic;
  late final Stream<Message> onValueUpdate;

  RosSubscriber(this.topic, this.config)
      : _valueUpdate = StreamController<Message>() {
    onValueUpdate = _valueUpdate.stream.asBroadcastStream();
  }

  TcpHandShake _decodeHeader(Uint8List header) {
    try {
      var data = ByteData.view(header.buffer);
      var size = data.getUint32(0, Endian.little);
      var index = 4;
      var decodedHeader = <String>[];
      while (index < size) {
        var size = data.getUint32(index, Endian.little);
        index += 4;
        var param = utf8.decode(header.sublist(index, index + size));
        decodedHeader.add(param);
        index += size;
      }
      // for (var h in decodedHeader) {
      //   print("RosSubscriber.decodedHeader: $h");
      // }
      return TcpHandShake(index, decodedHeader);
    } catch (ex) {
      print("RosSubscriber.decodedHeader ERR: $ex");
      rethrow;
    }
  }

  List<int> _tcprosHeader() {
    final callerId = 'callerid=/${config.name}'.replaceAll("//", "/");
    final tcpNoDelay = 'tcp_nodelay=0';
    final topic = 'topic=/${this.topic.name}'.replaceAll("//", "/");

    var messageHeader = this.topic.msg.binaryHeader;
    var fullSize = messageHeader.length +
        4 +
        callerId.length +
        4 +
        topic.length +
        4 +
        tcpNoDelay.length;

    var header = <int>[];
    header.addAll(fullSize.toBytes());
    header.addAll(messageHeader);
    header.addAll(callerId.length.toBytes());
    header.addAll(utf8.encode(callerId));
    header.addAll(tcpNoDelay.length.toBytes());
    header.addAll(utf8.encode(tcpNoDelay));
    header.addAll(topic.length.toBytes());
    header.addAll(utf8.encode(topic));
    return header;
  }

  Future<Socket> establishTCPROSConnection(ProtocolInfo protocolInfo) async {
    var socket =
        await Socket.connect(protocolInfo.params[0], protocolInfo.params[1]);

    socket.add(_tcprosHeader());
    var broadcast = socket.asBroadcastStream();

    // print(
    //     "establishTCPROSConnection: ${socket.address.host}:${socket.port} recheck ${protocolInfo.toString()}");

    // if(socket.port!= int.parse(protocolInfo.params[1].toString())){
    //   print("#ROS#WARNING: establish may wrong port");
    // }

    //Message data
    var buffor = BytesBuilder();
    var recived = 0;
    var size = 0;

    //TCPROS Connection loop
    void loop(Uint8List data) {
      recived += data.length;
      buffor.add(data);

      while (true) {
        if (size == 0 && recived >= 4) {
          size = ByteData.view(buffor.toBytes().buffer, 0, 4)
              .getUint32(0, Endian.little);

          // print("ByteDataView: size: $size buffor: ${buffor.length}");

          size = size + 4;
        }
        if (recived < size || size == 0) {
          //print("ros_subscriber.establishTCPROSConnection.loop: wait next for get full size");
          break;
        }
        //print("ros_subscriber.establishTCPROSConnection.loop: OK take whole bytes");

        //print("size: $size received: $recived ");

        try {
          //print("buffor: ${buffor.length}");
          var msgData = buffor.takeBytes();
          //print("msgData:1: ${msgData.length}");

          buffor.add(msgData.sublist(size));
          //print("msgData:2: ${msgData.length} buffor: ${buffor.length}");
          msgData = msgData.sublist(0, size);
          //print("msgData:3: ${msgData.length} buffor: ${buffor.length}");
          var temp = RosTopic<Message>(topic.name);
          var usedbytes = temp.msg.fromBytes(msgData, offset: 4);

          //print("usedbytes: ${usedbytes} size: $size");

          assert(usedbytes == size - 4);

          _valueUpdate.add(temp.msg);

          recived -= size;
          size = 0;
        } catch (ex) {
          //sleep(Duration(seconds: 10));
          //print("ros_subscriber.establishTCPROSConnection.loop: $ex");
          //rethrow;
          //exit loop do not block other thread to run
          break;
        }
        //print("AFTER received: $recived size: $size buffor: ${buffor.length}");
      }
    }

    //Handshake only
    broadcast.take(1).listen((data) {
      var handshake = _decodeHeader(data);
      var md5sum = handshake.headers
          .where((header) => header.contains('md5sum='))
          .first
          .substring(7);
      var type = handshake.headers
          .where((header) => header.contains('type='))
          .first
          .substring(5);

      assert(md5sum == topic.msg.type_md5);
      assert(type == topic.msg.message_type);

      // var callerid = handshake.headers
      //     .where((header) => header.contains('callerid='))
      //     .firstOrNull();
      // var latching = handshake.headers
      //     .where((header) => header.contains('latching='))
      //     .firstOrNull();

      loop(data.sublist(handshake.size));
    });

    //Data stream
    broadcast.skip(1).listen(loop);

    return socket;
  }

  Future<bool> updatePublisherList(List<String> publishers) async {
    _connections.removeWhere((apiAddress, connection) {
      print("updatePublisherList:$apiAddress");
      final connected = !publishers.contains(apiAddress);
      if (!connected) {
        connection.close();
      }
      return connected == false;
    });

    await Future.wait(
        [for (var connection in publishers) _connectWithPublisher(connection)]);

    return true;
  }

  Future<void> _connectWithPublisher(String connection) async {
    dynamic response;
    try {
      response = await xml_rpc.call(Uri.parse(connection), 'requestTopic', [
        '/${config.name}'.replaceAll("//", "/"),
        '/${topic.name}'.replaceAll("//", "/"),
        [
          ['TCPROS']
        ]
      ]);
    } on SocketException catch (e) {
      var osErr = e.osError;
      if (osErr == null) {
        rethrow;
      }
      if (osErr.errorCode == 1225) {
        return;
      }
      rethrow;
    }

    if ((response[2] as List<dynamic>).isEmpty) {
      return;
    }

    final code = response[0] as int;
    final status = response[1] as String;
    final protocol =
        ProtocolInfo(response[2][0], (response[2] as List<dynamic>).sublist(1));

    Socket? socket;
    switch (protocol.name) {
      case 'TCPROS':
        socket = await establishTCPROSConnection(protocol);
        break;
    }

    if (socket == null) {
      throw 'Could not establish a connection with publisher';
    }

    print("_connectWithPublisher");
    print(response);

    _connections.putIfAbsent(connection, () => socket!);
  }

  Future<void> forceStop() {
    return Future.wait(_connections.values.map((e) async {
      await e.flush();
      return e.close();
    }));
  }
}
