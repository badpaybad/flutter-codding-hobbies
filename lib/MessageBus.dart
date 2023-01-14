import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import "package:mutex/mutex.dart";
import 'package:redis/redis.dart';

class MessageBus {
  //DI as singleton
  MessageBus._privateConstructor() {
    _eventLoop();
  }

  static final MessageBus instance = MessageBus._privateConstructor();
  final String CameraTakePicture = "/camera/take/picture";
  final _channel = <String, Map<String, Future<void> Function(dynamic)>>{};
  final _cache = <String, dynamic>{};
  final _cacheExpired = <String, DateTime?>{};
  final _cacheLockerMutex = Mutex();
  RedisConnection? redisConnection;
  Command? redisCommand;
  bool _isRedisInited = false;
  late Future<Command?> ensureRedisCommandInit;

  Future<void> Init() async {
    ensureRedisCommandInit = initRedis();
  }

  String _redisHost = "192.168.1.8";
  int _redisPort = 6379;
  String _redisPwd = "123456";

  Future<Command?> initRedis() async {
    if (redisCommand != null) {
      try {
        await redisCommand!.send_nothing();
      } catch (ex) {
        _isRedisInited = false;
      }
    }

    if (_isRedisInited) return redisCommand;

    _isRedisInited = true;

    try {
      redisConnection ??= RedisConnection();
      redisCommand = await redisConnection!.connect(_redisHost, _redisPort);
      var value = await redisCommand!.send_object(["AUTH", _redisPwd]);
      value = await redisCommand!.send_object(["SELECT", "0"]);
      print("RedisConnection $_redisHost $_redisPort 0");
      return redisCommand;
    } catch (ex) {
      print("REDIS ERR: $ex");
      return redisCommand;
    }
  }

  Future<Command?> createRedisCmd({String db = "0"}) async {
    try {
      var redconn = RedisConnection();
      var cmd = await redconn.connect(_redisHost, _redisPort);
      var value = await cmd!.send_object(["AUTH", _redisPwd]);
      value = await cmd!.send_object(["SELECT", db]);

      return cmd;
    } catch (ex) {
      print("REDIS ERR: $ex");
      _isRedisInited = false;
      return redisCommand;
    }
  }

  Future<void> RedisDel<T>(String key) async {
    try {
      await initRedis();

      var val1 =
          await MessageBus.instance.redisCommand?.send_object(["DEL", key]);
    } catch (ex) {
      _isRedisInited = false;
      print("RedisDel ERR: $ex");
    }
  }

  Future<T?> RedisGetOrSet<T>(String key, Future<T> Function() setFuc,
      {int? afterMilisec = 60000}) async {
    var temp = await RedisGet(key);
    if (temp == null) {
      temp = await setFuc();
      await RedisSet(key, temp, afterMilisec: afterMilisec);
    }

    return temp;
  }

  Future<void> RedisSet<T>(String key, T val,
      {int? afterMilisec = 60000}) async {
    try {
      await initRedis();

      var valjson = "";

      if (T is String && val is String) {
        valjson = val;
      } else {
        valjson = jsonEncode(val);
      }

      await redisCommand?.send_object(["SET", key, valjson]);
      if (afterMilisec != null) {
        await redisCommand?.send_object([
          "EXPIREAT",
          key,
          DateTime.now().millisecondsSinceEpoch + afterMilisec!
        ]);
      }
    } catch (ex) {
      _isRedisInited = false;
      print("RedisSet ERR: $ex");
    }
  }

  Future<T?> RedisGet<T>(String key) async {
    try {
      await initRedis();
      var val = await redisCommand?.send_object(["GET", key]);
      if (val == null) return null;
      try {
        if (T is String) return val;

        val = jsonDecode(val);
        return val;
      } catch (ex) {
        if (T is String) {
          return val;
        }
      }
    } catch (ex) {
      _isRedisInited = false;
      print("RedisSet ERR: $ex");
      return null;
    }
  }

  Future<void> RedisEnqueue<T>(String key, T val) async {
    try {
      await initRedis();
      var jsonData = "";
      if (T is String && val is String) {
        jsonData = val;
      } else {
        jsonData = jsonEncode(val);
      }
      var val1 = await MessageBus.instance.redisCommand
          ?.send_object(["LPUSH", key, jsonData]);
    } catch (ex) {
      _isRedisInited = false;
      print("RedisSet ERR: $ex");
    }
  }

  Future<T?> RedisDequeue<T>(String key) async {
    try {
      await initRedis();
      var val =
          await MessageBus.instance.redisCommand?.send_object(["ROP", key]);
      if (T is String) return val;

      return jsonDecode(val);
    } catch (ex) {
      _isRedisInited = false;
      print("RedisDequeue ERR: $ex");
      return null;
    }
  }

  Future<List<T>> RedisListGetAll<T>(String key,
      {int start = 0, int? stop}) async {
    try {
      await initRedis();
      stop ??= 9999999999900;

      var val = await MessageBus.instance.redisCommand
          ?.send_object(["LRANGE", key, start, stop]);

      print("RedisListGetAll: $key : $val");
      if (val == null) return [];

      var temp = val as List<dynamic>;

      print(temp);

      List<T> r = [];
      List<String> rs = [];

      for (var t in temp) {
        if (T is String && t is String) {
          rs.add(t);
        } else {
          r.add(jsonDecode(t));
        }
      }

      if (T is String) return rs as List<T>;

      return r;
    } catch (ex) {
      _isRedisInited = false;
      print("RedisListGetAll ERR: $ex");
      return [];
    }
  }

  Future<void> RedisListAdd<T>(String key, T val) async {
    try {
      await initRedis();
      var jsonData = "";
      if (T is String && val is String) {
        jsonData = val;
      } else {
        jsonData = jsonEncode(val);
      }
      var val1 = await MessageBus.instance.redisCommand
          ?.send_object(["LPUSH", key, jsonData]);
    } catch (ex) {
      _isRedisInited = false;
      print("RedisListAdd ERR: $ex");
    }
  }

  Future<void> RedisListRemove(String key, int idx) async {
    try {
      await initRedis();
      throw Exception("Not implement RedisListRemove");
    } catch (ex) {
      _isRedisInited = false;
    }
  }

  Future<void> RedisPub<T>(String channelKey, T val) async {
    try {
      await initRedis();
      var jsonData = "";
      if (T is String && val is String) {
        jsonData = val;
      } else {
        jsonData = jsonEncode(val);
      }
      await redisCommand?.send_object(["PUBLISH", channelKey, jsonData]);
    } catch (ex) {
      _isRedisInited = false;
      print("RedisPub ERR: $ex");
    }
  }

  Map<String, Command?> _redisListCmdForSubcribe = {};
  Map<String, PubSub?> _redisListPubSubForSubcribe = {};

  Future<void> RedisUnsub(String channelKey, String subscriberName) async {
    var keyToUnSub = "$channelKey#_#$subscriberName";

    _redisListPubSubForSubcribe[keyToUnSub]?.unsubscribe([subscriberName]);

    _redisListCmdForSubcribe.remove(keyToUnSub);
    _redisListPubSubForSubcribe.remove(keyToUnSub);
  }

  Future<void> RedisSub<T>(String channelKey, String subscriberName,
      Future Function(T) handle) async {
    try {
      var cmd = await createRedisCmd();

      var keyToUnSub = "$channelKey#_#$subscriberName";
      _redisListCmdForSubcribe[keyToUnSub] = cmd;

      final pubsub = PubSub(cmd!);

      pubsub.subscribe([channelKey]);

      _redisListPubSubForSubcribe[keyToUnSub] = pubsub;

      final stream = pubsub.getStream();

      stream.listen((event) {
        //event: [subscribe, coddinghobbies:livestream:webrtc_channel:cLT5ZRx4SF2g3F3-4j2AEh:APA91bFpvjUFegnVK0m-mOSbPElunbZkRkWciXcj9Kd6IsdRisHglrJ4FI95piLVnpGOHM_qrdm7ZMFXPrr7CmqhfIviSAUu3FUnjv3YZ8rpjS-jdt9wBssiv1h5xOXuf7dforl3X1WR, 1]
        print("RedisSub: chanel: $channelKey");
        print("sub: $subscriberName event: $event");
        print("event: $event");
        var typeEvt = event[0].toString();
        print("typeEvt: $typeEvt");

        if (typeEvt != "message") {
          return;
        }

        var eventData = event[2];
        try {
          if (T is String && eventData is String) {
            handle(eventData as dynamic);
          } else {
            var jsonData = jsonDecode(eventData);
            handle(jsonData);
          }
        } catch (exh) {
          print("RedisSub ERR Handle: $exh");
        }
      });
    } catch (ex) {
      _isRedisInited = false;
      print("RedisSub ERR: $ex");
    }
  }

  Future<bool> Set<T>(String key, T val, {int? afterMilisec = 60000}) async {
    try {
      await _cacheLockerMutex.acquire();

      var dtnow = DateTime.now();
      _cache[key] = val;

      if (afterMilisec != null) {
        _cacheExpired[key] = dtnow.add(Duration(milliseconds: afterMilisec!));
      } else {
        //never expired
        _cacheExpired[key] = null;
      }
      return true;
    } finally {
      _cacheLockerMutex.release();
    }
  }

  Future<T?> Get<T>(String key) async {
    try {
      await _cacheLockerMutex.acquire();

      if (_cache.containsKey(key) == false) return null;
      return _cache[key] as T;
    } finally {
      _cacheLockerMutex.release();
    }
  }

  Future<T> GetOrSet<T>(String key, Future<T> Function() setFuc,
      {int? afterMilisec = 60000}) async {
    var temp = await Get<T>(key);
    if (temp != null) return temp;

    temp = await setFuc();
    Set(key, temp, afterMilisec: afterMilisec);

    return temp!;
  }

  Future<void> _eventLoop() async {
    while (true) {
      try {
        await _cacheLockerMutex.acquire();

        var dtnow = DateTime.now().microsecondsSinceEpoch;
        List<String> keysExp = [];
        for (var k in _cacheExpired.keys) {
          var dt = _cacheExpired[k];
          if (dt == null) continue;
          if (dt!.microsecondsSinceEpoch < dtnow) {
            keysExp.add(k);
          }
        }
        for (var k in keysExp) {
          _cacheExpired.remove(k);
          _cache.remove(k);
          //print("MessageBuss._cache.remove: $k");
        }
      } finally {
        _cacheLockerMutex.release();
      }

      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  final _queueMap = Map<String, Queue<dynamic>>();
  final _queueLockerMutex = Mutex();

  Future<bool> Enqueue<T>(String queueName, T data, {limitTo: 1000}) async {
    try {
      var getLock = await _queueLockerMutex.acquire();
      //if (getLock == null) return false; //some how can not talk to cpu get lock

      //if (_queueLocker == true) return false;

      if (_queueMap.containsKey(queueName) == false) {
        _queueMap[queueName] = Queue<dynamic>();
      }
      var qlen = _queueMap[queueName]?.length ?? 0;
      if (qlen > limitTo) {
        //prevent stuck queue or over ram consume
        var toRemove = qlen - limitTo;
        for (var i = 0; i < toRemove; i++) {
          _queueMap[queueName]?.removeFirst();
        }
      }

      _queueMap[queueName]?.add(data);
      return true;
    } finally {
      _queueLockerMutex.release();
    }
  }

  Future<T?> Dequeue<T>(String queueName) async {
    try {
      var getLock = await _queueLockerMutex.acquire();

      if (_queueMap.containsKey(queueName) == false) {
        _queueMap[queueName] = Queue<dynamic>();
      }

      var qlen = _queueMap[queueName]?.length ?? 0;
      if (qlen == 0) return null;

      T itm = _queueMap[queueName]?.first;
      _queueMap[queueName]?.remove(itm);
      return itm;
    } finally {
      _queueLockerMutex.release();
    }
  }

  Future<void> Subscribe(String channelName, String subscriberName,
      Future<void> Function(dynamic) handle) async {
    if (_channel.containsKey(channelName) == false) {
      _channel[channelName] = <String, Future<void> Function(dynamic)>{};
    }
    _channel[channelName]?[subscriberName] = handle;
  }

  Future<void> Unsubscribe(String channelName, String subscriberName) async {
    _channel[channelName]!.remove(subscriberName);
  }

  Future<void> ClearChannel(String channelName) async {
    _channel.remove(channelName);
  }

  Future<void> Publish(String channelName, dynamic data) async {
    if (_channel.containsKey(channelName) == false) {
      _channel[channelName] = <String, Future<void> Function(dynamic)>{};
    }
    for (var h in _channel[channelName]!.values) {
      h(data);
    }
  }
}

//
//   late Isolate isolate;
//
//   late ReceivePort receivePort;
//  late SendPort sendPort;
//   static void _isolatePing(SendPort sendPort) async{
//
//     while(true){
//
//       for(var k in _isolateActionQueue.keys){
//         var actions = _isolateActionQueue[k]??[];
//
//         var handlers= _isolateResultQueue[k]?.values??[];
//
//         for(var a in actions){
//           var r = await a();
//           for(var h in handlers){
//              await h(r);
//           }
//         }
//       }
//
//       Future.delayed(Duration(milliseconds: 10));
//     }
//
//   }
//
// static Map<String,  List<Future<dynamic> Function()>> _isolateActionQueue= Map<String,  List<Future<dynamic> Function()>>();
// static Map<String,Map<String,Future<void> Function(dynamic)>> _isolateResultQueue= Map<String,Map<String,Future<void> Function(dynamic)>>();
