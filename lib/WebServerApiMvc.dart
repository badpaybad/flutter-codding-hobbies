import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'HttpBase.dart';

class WebServerApiMvc {
  WebServerApiMvc._() {
//wss://meet.jit.si/xmpp-websocket
  }

  static WebServerApiMvc instance = WebServerApiMvc._();

  final Map<String, Future<MvcResponse> Function(HttpRequest)> _route =
      <String, Future<MvcResponse> Function(HttpRequest)>{};

  Future<void> _registerRequestHandle() async {
//register handle for routing similar to mvc
    _route["/"] = (request) async {
      return MvcResponse(
          "Root path<br> To test api response json <a href='/jsontest'>click here</a>",
          ContentType.html);
    };
    _route["/swagger"] = (request) async {
      return MvcResponse(
          "Some blade engin to render swagger docs", ContentType.html);
    };
    _route["/jsontest"] = (request) async {
      return MvcResponse(
          jsonEncode({"name": "Nguyen Phan Du"}), ContentType.json);
    };
  }

  late HttpServer _http_server;

  Future<void> start() async {
    await _registerRequestHandle();

    _http_server = await HttpServer.bind(InternetAddress.anyIPv4, 8123);
    print(
        "webserver listening: ${_http_server.address.host}:${_http_server.port}");

    _loopServeRequest();

    HttpBase().Post<String>("http://192.168.232.2:8123", "{'ping':'test'}");

    //HttpBase().PostForm("http://192.168.232.2:8123", {"myname":"nguyen phan du"},{});
  }

  Future<void> _loopServeRequest() async {
    _http_server.listen(
        (request) async {
          var requestBody = await request.toList();
          List<int> temp = [];
          for (var i in requestBody) {
            temp.addAll(i);
          }
          var bodyInText = Utf8Decoder().convert(temp);

          print(
              "request.requestedUri.path: ${request.requestedUri.path} request.body: $bodyInText");

          if (_route.containsKey(request.requestedUri.path)) {
            var responseData =
                await _route[request.requestedUri.path]!(request);
            request.response.statusCode = HttpStatus.ok;
            request.response.headers
                .set("Content-Type", responseData.contentType.mimeType);
            request.response.write(responseData.body);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.headers
                .set("Content-Type", ContentType.html.mimeType);
            request.response.write('404');
          }
          request.response.close();
        },
        onDone: () {},
        onError: (objErr) {
          print("_http_server.onError: ${objErr}");
        });

    // await _http_server.forEach((HttpRequest request) async {
    //   print("request.requestedUri.path: ${request.requestedUri.path}");
    //
    //   if (_route.containsKey(request.requestedUri.path)) {
    //     var responseData = await _route![request.requestedUri.path]!(request);
    //     request.response.write(responseData);
    //   } else {
    //     request.response.write('404');
    //     request.response.statusCode = 404;
    //   }
    //   request.response.close();
    // });
    print("End web server");
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

class MvcResponse {
  String body;
  ContentType contentType;

  MvcResponse(this.body, this.contentType);
}
//
// final channel =
// WebSocketChannel.connect(Uri.parse('wss://meet.jit.si/xmpp-websocket'),
//     //   Uri.parse('wss://ws-feed.pro.coinbase.com'),
//     protocols: ["xmpp"]);
//
// channel.stream.listen((message) {
// print("WebSocketChannel--------------------------");
// print(message);
// // channel.sink.add('received!');
// // channel.sink.close(WssStatus.goingAway);
// });
//
// channel.sink.add('received!');
// //
// // channel.sink.add(
// //   jsonEncode(
// //     {
// //       "type": "subscribe",
// //       "channels": [
// //         {
// //           "name": "ticker",
// //           "product_ids": [
// //             "BTC-EUR",
// //           ]
// //         }
// //       ]
// //     },
// //   ),
// // );
