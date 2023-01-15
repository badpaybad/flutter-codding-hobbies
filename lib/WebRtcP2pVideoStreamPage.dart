import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oktoast/oktoast.dart';
import '../NotificationHelper.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:typed_data';
import '../MessageBus.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import '../extensions/list.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as WssStatus;

class WebRtcP2pVideoStreamPage extends StatefulWidget {
  const WebRtcP2pVideoStreamPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _WebRtcP2pVideoStreamPageState();
  }
}

class _WebRtcP2pVideoStreamPageState extends State<WebRtcP2pVideoStreamPage> {
  bool _isOwnerCreatedOffer = false;
  String _localFcmToken = "";
  String _remoteFcmToken = "";
  List<String> _webRtcRemoteTokens = [];

  bool _isWebRtcDataChannelReady = false;

  RTCPeerConnection? _localPeerConnection;
  List<String> _localCandidates = [];
  Map<String, String> _candidatesFromRemotes = {};
  RTCVideoRenderer? _localVideoRenderer;
  RTCVideoRenderer? _remoteVideoRenderer;
  MediaStream? _localStream;
  Map<String, RTCDataChannel> _dataChannels = {};

//https://github.com/yeasin50/Flutter-Video-Calling-App/blob/master/lib/screens/call_page.dart
  final Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': {
      /// `Provide your own width, height and frame rate here`
      /// if it's larger than your screen , it wount showUP
      'mandatory': {
        'minWidth': '200',
        'minHeight': '200',
        'minFrameRate': '30',
      },
      'facingMode': 'user',
      'optional': [],
    },
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      //'OfferToReceiveAudio': true,
      //'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  final _iceConfiguration = <String, dynamic>{
    //important
    "iceTransportsType": 3,
    //PeerConnection.IceTransportsType.ALL (NONE:0,    RELAY:1,    NOHOST:2,  ALL:3)
    "keyType": 1,
    //PeerConnection.KeyType.ECDSA (  RSA:0, ECDSA:1,  )
    "iceCandidatePoolSize": 10,
    "iceServers": [
      {
        "urls": [
          'stun:stun2.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          "stun:stun3.l.google.com:19302",
          "stun:stun4.l.google.com:19302",
          'stun:stun.l.google.com:19302',
        ],
      }
    ],
  };

  Future<void> getListRemoteWebRtcTokens() async {
    var allTokens = await MessageBus.instance
        .RedisListGetAll<String>("coddinghobbies:livestream:webrtc:_list");

    _webRtcRemoteTokens =
        allTokens.where((ie) => ie != _localFcmToken).toSet().toList();
  }

  Future<String> _initDataChannel(
      String topic, Future<void> Function(RTCDataChannelMessage?) onMessage,
      {String type = "text"}) async {
    ///https://github.com/webrtc/samples/blob/gh-pages/src/content/datachannel/basic/js/main.js

    if (_dataChannels.containsKey(topic) == true) {
      return topic;
    }

    _localPeerConnection!.onDataChannel = (channel) {
      print("onDataChannel------------------- $channel");
      channel.onMessage = (msg) {
        print("onDataChannel.onMessage-------------- $msg");
      };
    };
    _localPeerConnection!.onIceGatheringState = (conn) {
      print("onIceGatheringState $conn");
    };

    RTCDataChannelInit typempsg = RTCDataChannelInit()
      ..negotiated = true
      ..maxRetransmits = 30;

    typempsg.binaryType = type; // "binary" || "text"

    var dataChannel =
        await _localPeerConnection!.createDataChannel(topic, typempsg);

    dataChannel!.onMessage = onMessage;

    _dataChannels[topic] = dataChannel;

    return topic;
  }

  String _peerCreatedAt = DateTime.now()
      .toIso8601String()
      .replaceAll("T", "_")
      .replaceAll(":", "-");

  Future<RTCPeerConnection> _webrtcCreatePeerConnecion(String fcmToken) async {
    ///ok = js//https://fireship.io/lessons/webrtc-firebase-video-chat/
    ///ok=js//https://github.com/fireship-io/webrtc-firebase-demo
    ///https://github.com/msddev/WebRTC-Serverless-Kotlin-Example
    ///https://www.100ms.live/blog/flutter-webrtc
    ///https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
    ///https://hub.docker.com/r/coturn/coturn
    ///docker pull coturn/coturn
    ///docker run -d -p 3478:3478 -p 3478:3478/udp -p 5349:5349 -p 5349:5349/udp -p 49152-49153:49152-49153/udp coturn/coturn
    ///docker run -d --network=host coturn/coturn
    ///

    _peerCreatedAt = DateTime.now()
        .toIso8601String()
        .replaceAll("T", "_")
        .replaceAll(":", "-");

    print("_webrtcCreatePeerConnecion-----------$_peerCreatedAt");

    _localPeerConnection =
        await createPeerConnection(_iceConfiguration, _config);
    _localCandidates = [];
    _candidatesFromRemotes = {};
    _dataChannels = {};

    await _initDataChannel("test_topic", (msg) async {
      print("_dataChannel.onMessage----------------- $msg");
      //todo: your code do with msg
      showToast("msg webrtc: ${msg?.text}");
    });

    _localPeerConnection!.onIceCandidate = (e) async {
      if (e.candidate != null) {
        var localCandidate = json.encode({
          'candidate': e.candidate,
          'sdpMid': e.sdpMid,
          'sdpMlineIndex': e.sdpMLineIndex,
        });

        await Future.delayed(Duration(seconds: 1), () async {
          await _signalingSendCadidate(localCandidate);
        });
      }
    };
    _localPeerConnection!.onIceConnectionState = (e) {
      print("onIceConnectionState $e");
      /*
      enum RTCIceConnectionState {        RTCIceConnectionStateNew,        RTCIceConnectionStateChecking,        RTCIceConnectionStateCompleted,        RTCIceConnectionStateConnected,        RTCIceConnectionStateCount,        RTCIceConnectionStateFailed,        RTCIceConnectionStateDisconnected,        RTCIceConnectionStateClosed,      }*/
    };
    _localPeerConnection!.onAddStream = (stream) {
      print('addStream--------------------: $stream');
      _remoteVideoRenderer?.srcObject = stream;
    };
    _localPeerConnection!.onAddTrack = (stream, track) {
      print('onAddTrack---------- $stream $track');
      // if (track.kind == 'video') {
      //
      // }
      //_remoteVideoRenderer?.srcObject = stream;
    };
    _localPeerConnection!.onTrack = (event) {
      print('onTrack--------------- $event');
      // if (event.track.kind == 'video') {
      //   _remoteVideoRenderer?.srcObject = event.streams[0];
      // }
    };

    _localPeerConnection!.onConnectionState = (conn) async {
      print("onConnectionState $conn");
      /*enum RTCPeerConnectionState {        RTCPeerConnectionStateClosed,        RTCPeerConnectionStateFailed,        RTCPeerConnectionStateDisconnected,        RTCPeerConnectionStateNew,        RTCPeerConnectionStateConnecting,        RTCPeerConnectionStateConnected      }*/
      if (conn == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        await Future.delayed(const Duration(seconds: 2), () async {
          await _signalingSendOffer(_remoteFcmToken);
        });
      }

      if (conn == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _isWebRtcDataChannelReady = true;

        if (mounted) setState(() {});
      }
    };

    _localVideoRenderer = RTCVideoRenderer();
    _remoteVideoRenderer = RTCVideoRenderer();
    await _localVideoRenderer!.initialize();
    await _remoteVideoRenderer!.initialize();
    _localStream = await _getUserMedia();

    if (_localStream != null) {
      for (var t in _localStream!.getTracks()) {
        _localPeerConnection!.addTrack(t, _localStream!);
      }
    }

    return _localPeerConnection!;
  }

  @override
  void initState() {
    super.initState();
    _initPeerAndSignaling();
  }

  Future<void> _initPeerAndSignaling() async {
    NotificationHelper.instance.getFcmToken().then((value) async {
      _localFcmToken = value!;

      await MessageBus.instance.RedisGetOrSet(
          "coddinghobbies:livestream:webrtc:$_localFcmToken", () async {
        await MessageBus.instance.RedisListAdd(
            "coddinghobbies:livestream:webrtc:_list", _localFcmToken);

        return _localFcmToken;
      });

      await _webrtcCreatePeerConnecion(_localFcmToken);

      ///redis pub sub: signaling for offer, answer, candidate transfer
      MessageBus.instance.RedisSub<dynamic>(
          "coddinghobbies:livestream:webrtc_channel:$_localFcmToken",
          _localFcmToken, (p0) async {
        var type = p0["type"];
        _remoteFcmToken = p0["fromid"];
        var toId = p0["toid"];

        print("BEGIN-----local: $_localFcmToken\r\nremote: $_remoteFcmToken");

        if (toId != _localFcmToken) {
          print("todo: wrong target -------------------");
        }

        if (type == "offered") {
          await _signalingHandleOffer(p0["data"], p0["candidates"]);
        }

        if (type == "answered") {
          await _signalingHandleAnswer(p0["data"], p0["candidates"]);
        }

        if (type == "candidated") {
          await _signalingAddCandidate(p0["candidates"]);
        }

        if (type == "closed") {
          await _closePeerConnection();
        }

        print("END----- $_localFcmToken");
      });

      await getListRemoteWebRtcTokens();

      if (mounted) setState(() {});
    });
  }

  Future<void> _signalingSendOffer(String remoteToken) async {
    var offered = await _webrtcCreateOffer();

    _remoteFcmToken = remoteToken;

    var tempCandidates = await _getListLocalCandidate();

    await MessageBus.instance
        .RedisPub("coddinghobbies:livestream:webrtc_channel:$_remoteFcmToken", {
      "fromid": _localFcmToken,
      "toid": _remoteFcmToken,
      "data": offered,
      "type": "offered",
      "candidates": tempCandidates
    });
  }

  Future<void> _signalingHandleOffer(
      String offerData, List<dynamic> candidates) async {
    ///https://github.com/webrtc/samples/blob/gh-pages/src/content/peerconnection/channel/js/main.js
    _isWebRtcDataChannelReady = false;

    if (_localPeerConnection == null) {
      await _webrtcCreatePeerConnecion(_localFcmToken);
    }

    await _webrctSetRemoteDescriptionOffer(offerData);

    await MessageBus.instance.RedisListAdd(
        "webrtclogs:$_localFcmToken:offered:$_peerCreatedAt", offerData);

    var answered = await _webrtcCreateAnswer();

    var tempCandidates = await _getListLocalCandidate();

    await MessageBus.instance
        .RedisPub("coddinghobbies:livestream:webrtc_channel:$_remoteFcmToken", {
      "type": "answered",
      "data": answered,
      "fromid": _localFcmToken,
      "toid": _remoteFcmToken,
      "candidates": tempCandidates
    });

    await _signalingAddCandidate(candidates);

    showToast("Sent answer to $_remoteFcmToken");
  }

  Future<void> _signalingHandleAnswer(
      String answerData, List<dynamic> candidates) async {
    _isWebRtcDataChannelReady = false;

    await _webrtcSetRemoteDescriptionAnswer(answerData);

    await MessageBus.instance.RedisListAdd(
        "webrtclogs:$_localFcmToken:answered:$_peerCreatedAt", answerData);

    await _signalingAddCandidate(candidates);

    showToast("Received answer from $_remoteFcmToken");
  }

  Future<void> _signalingSendClosed() async {
    if (_remoteFcmToken != null && _remoteFcmToken != "") {
      await MessageBus.instance.RedisPub(
          "coddinghobbies:livestream:webrtc_channel:$_remoteFcmToken", {
        "type": "closed",
        "data": _localFcmToken,
        "fromid": _localFcmToken,
        "toid": _remoteFcmToken,
        "candidates": _localCandidates
      });
    }
  }

  Future<void> _signalingSendCadidate(String localCandidate) async {
    await MessageBus.instance.RedisListAdd(
        "webrtclogs:$_localFcmToken:candidate:$_peerCreatedAt", localCandidate);

    _localCandidates.add(localCandidate);

    //await _addCandidate(localCandidate);

    if (_remoteFcmToken != null && _remoteFcmToken != "") {
      await MessageBus.instance.RedisPub(
          "coddinghobbies:livestream:webrtc_channel:$_remoteFcmToken", {
        "type": "candidated",
        "data": localCandidate,
        "fromid": _localFcmToken,
        "toid": _remoteFcmToken,
        "candidates": _localCandidates
      });
    }
  }

  Future<void> _signalingAddCandidate(List<dynamic> candidates) async {
    for (String keyCan in candidates) {
      if (_candidatesFromRemotes.containsKey(keyCan) == false) {
        _candidatesFromRemotes[keyCan] =
            DateTime.now().millisecondsSinceEpoch.toString();
        await _webrtcAddCandidate(keyCan);
      }
    }
  }

  Future<String> _webrtcCreateOffer() async {
    _localPeerConnection ??= await _webrtcCreatePeerConnecion(_localFcmToken);

    RTCSessionDescription description =
        await _localPeerConnection!.createOffer(_constraints);
    var session = parse(description.sdp.toString());
    _isOwnerCreatedOffer = true;

    await _localPeerConnection!.setLocalDescription(description);

    var sdpOfferedData = json.encode(session);

    return sdpOfferedData;
  }

  Future<String> _webrtcCreateAnswer() async {
    RTCSessionDescription description =
        await _localPeerConnection!.createAnswer(_constraints);

    var session = parse(description.sdp.toString());

    await _localPeerConnection!.setLocalDescription(description);

    var answeredData = json.encode(session);

    return answeredData;
  }

  Future<void> _webrctSetRemoteDescriptionOffer(String sdpOfferedData) async {
    try {
      dynamic session = await jsonDecode(sdpOfferedData);

      String sdp = write(session, null);

      RTCSessionDescription description = RTCSessionDescription(sdp, 'offer');

      await _localPeerConnection!.setRemoteDescription(description);
    } catch (ex) {
      print("_setRemoteDescriptionOffer---err_retrying---$ex");

      await Future.delayed(const Duration(seconds: 2));

      await _webrtcCreatePeerConnecion(_localFcmToken);

      await _webrctSetRemoteDescriptionOffer(sdpOfferedData);
    }
  }

  Future<void> _webrtcSetRemoteDescriptionAnswer(String sdpAnsweredData) async {
    dynamic session = await jsonDecode(sdpAnsweredData);

    String sdp = write(session, null);

    RTCSessionDescription description = RTCSessionDescription(sdp, 'answer');

    await _localPeerConnection!.setRemoteDescription(description);
  }

  Future<void> _webrtcAddCandidate(String sdpAnsweredData_candidate) async {
    print(sdpAnsweredData_candidate);

    dynamic session = await jsonDecode(sdpAnsweredData_candidate);

    dynamic candidate = RTCIceCandidate(session['candidate'] ?? "",
        session['sdpMid'] ?? "0", session['sdpMlineIndex'] ?? 0);
    await _localPeerConnection!.addCandidate(candidate);
  }

  SizedBox videoRenderers() => SizedBox(
        height: 210,
        child: Row(children: [
          Flexible(
            child: Container(
              key: const Key('local'),
              margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: const BoxDecoration(color: Colors.black),
              child: _localVideoRenderer == null
                  ? Text("No viđeo")
                  : RTCVideoView(_localVideoRenderer!),
            ),
          ),
          Flexible(
            child: Container(
              key: const Key('remote'),
              margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: const BoxDecoration(color: Colors.black),
              child: _remoteVideoRenderer == null
                  ? Text("No viđeo")
                  : RTCVideoView(_remoteVideoRenderer!),
            ),
          ),
        ]),
      );

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if (_localVideoRenderer != null) {
      print("_getUserMedia------- $stream");
      _localVideoRenderer!.srcObject = stream;
    }
    return stream;
  }

  Future<List<String>> _getListLocalCandidate() async {
    var counterTimeout = 0;
    while (true) {
      counterTimeout = counterTimeout + 1;
      await Future.delayed(const Duration(milliseconds: 100));
      if (counterTimeout > 12) {
        break;
      }
      if (_localCandidates.isNotEmpty) {
        break;
      }
    }
    return _localCandidates;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> remoteSessions = [];
    for (var t in _webRtcRemoteTokens) {
      remoteSessions.add(ElevatedButton(
          onPressed: () async {
            await _signalingSendOffer(t);
          },
          child: Text("Connect to: $t")));
    }

    return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text("Webrtc test"),
              IconButton(
                  onPressed: () async {
                    await getListRemoteWebRtcTokens();

                    if (mounted) setState(() {});
                  },
                  icon: Icon(Icons.refresh)),
              ElevatedButton(
                  onPressed: _isWebRtcDataChannelReady == false
                      ? null
                      : () async {
                          for (var dataChannel in _dataChannels.values) {
                            await dataChannel.send(RTCDataChannelMessage(
                                "${dataChannel.label} ${DateTime.now().toIso8601String()}"));
                          }

                          showToast("sent msg rnd test");
                        },
                  child: Text("Send rnd test"))
            ],
          ),
        ),
        body: Column(
          children: [
            SelectableText(_localFcmToken),
            videoRenderers(),
            Expanded(
                child: ListView(
              children: remoteSessions,
            ))
          ],
        ));
  }

  @override
  void dispose() async {
    await _closePeerConnection();
    await _signalingSendClosed();

    MessageBus.instance.RedisUnsub(
        "coddinghobbies:livestream:webrtc_channel:$_localFcmToken",
        _localFcmToken);

    super.dispose();
  }

  Future<void> _closePeerConnection() async {
    if (null != _localPeerConnection) _localPeerConnection!.close();
    if (null != _localVideoRenderer) _localVideoRenderer!.dispose();
    if (null != _remoteVideoRenderer) _remoteVideoRenderer!.dispose();
    if (null != _localStream) _localStream!.dispose();

    _localPeerConnection = null;
    _localVideoRenderer = null;
    _remoteVideoRenderer = null;
    _localStream = null;
  }
}
