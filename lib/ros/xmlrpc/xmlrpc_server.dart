import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart' as xml;
import 'converter.dart';
import 'common.dart';
import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

/// A [XmlRpcServer] that handles the XMLRPC server protocol with a single threaded [HttpServer]
class SimpleXmlRpcServer extends XmlRpcServer {
  /// The [HttpServer] used for handling responses
  late HttpServer _httpServer;

  String get HttpHost => _httpServer.address.host;

  int get HttpPort => _httpServer.port;

  /// Creates a [SimpleXmlRpcServer]
  SimpleXmlRpcServer({
    required String host,
    required int port,
    required XmlRpcHandler handler,
    Encoding encoding = utf8,
  }) : super(host: host, port: port, handler: handler, encoding: encoding);

  /// Starts up the [_httpServer] and starts listening to requests
  @override
  Future<void> start() async {
    _httpServer = await HttpServer.bind(host, port);
    _httpServer.listen((req) => acceptRequest(req, encoding));
  }

  /// Stops the [_httpServer]
  ///
  /// [force] determines whether to stop the [HttpServer] immediately even if there are open connections
  @override
  Future<void> stop({bool force = false}) async {
    await _httpServer.close(force: force);
  }
}

/// A [XmlRpcServer] that handles the XMLRPC server protocol.
///
/// Subclasses must provide a http server to bind to the host / port and listen for incoming requests.
///
/// The fault codes specified are from the spec [here](http://xmlrpc-epi.sourceforge.net/specs/rfc.fault_codes.php)
abstract class XmlRpcServer {
  static final rpcPaths = ['/', '/RPC2'];

  /// The [host] uri
  final dynamic host;

  @virtual
  String get HttpHost;

  @virtual
  int get HttpPort;

  /// The [port] to host the server on
  final int port;

  /// The [Encoding] to use as default, this defaults to [utf8]
  final Encoding encoding;

  /// The [XmlRpcHandler] used for method lookup and handling
  final XmlRpcHandler handler;

  /// Creates a [XmlRpcServer] that will bind to the specified [host] and [port]
  ///
  /// as well as the String [encoding] for http requests and responses
  ///
  /// You must await the call to [serverForever] to start up the server
  /// before making any client requests
  XmlRpcServer({
    required this.host,
    required this.port,
    required this.handler,
    this.encoding = utf8,
  });

  /// Starts up the [XmlRpcServer] and starts listening to requests
  Future<void> start();

  /// Stops the [XmlRpcServer]
  ///
  /// [force] determines whether to stop the [XmlRpcServer] immediately even if there are open connections
  Future<void> stop({bool force = false});

  /// Accepts a HTTP [request]
  ///
  /// This method decodes the request with the encoding specified in the content-encoding header, or else the given [encoding]
  /// Then it handles the request using the [dispatcher], and responds with the appropriate response
  @protected
  void acceptRequest(HttpRequest request, Encoding encoding) async {
    final httpResponse = request.response;
    if (request.method != 'POST' || !_isRPCPathValid(request)) {
      _report404(httpResponse);
      return;
    }
    String xmlRpcRequest="";

    try {
      xmlRpcRequest = await encoding.decodeStream(request);

      // print("xmlRpcRequest:");
      // print(xmlRpcRequest);

      final response = await handler.handle(XmlDocument.parse(xmlRpcRequest));
      await _sendResponse(httpResponse, response);
    } on XmlRpcRequestFormatException {
      await _sendResponse(httpResponse,
          handler.handleFault(Fault(-32602, 'invalid method parameters')));
    } on XmlRpcMethodNotFoundException {
      await _sendResponse(httpResponse,
          handler.handleFault(Fault(-32601, 'requested method not found')));
    } on XmlRpcCallException catch (e) {
      await _sendResponse(
          httpResponse,
          handler.handleFault(
              Fault(-32603, 'internal xml-rpc error : ${e.cause}')));
    } on XmlRpcResponseEncodingException {
      await _sendResponse(httpResponse,
          handler.handleFault(Fault(-32603, 'unsupported response')));
    } on Exception catch (e) {
      print('#xmlrpc#Exception: $e');
      print(xmlRpcRequest);
      rethrow;
    }
  }

  /// Reports a 404 error to the [httpResponse]
  void _report404(HttpResponse httpResponse) {
    _sendError(httpResponse, 404, 'No such page');
  }

  /// Checks to make sure that the [request]'s path is meant for the RPC handler
  bool _isRPCPathValid(HttpRequest request) {
    return rpcPaths.contains(request.requestedUri.path);
  }
}

/// Sends an Http error to the [httpResponse] with the specified [code] and [messsage]
Future<void> _sendError(HttpResponse httpResponse, int code, String message) =>
    (httpResponse
          ..statusCode = code
          ..headers.contentLength = message.length
          ..headers.contentType = ContentType.text
          ..write(message))
        .close();

/// Sends a xmlrpc message to [httpResponse] with the specified [xml].
Future<void> _sendResponse(HttpResponse httpResponse, XmlDocument xml) {
  final text = xml.toXmlString();
  return (httpResponse
        ..statusCode = 200
        ..headers.contentLength = text.length
        ..headers.contentType = ContentType.parse('text/xml')
        ..write(text))
      .close();
}

/// A [XmlRpcHandler] handles the handling RPC functions along with marshalling the arguments and results to / from XMLRPC spec
///
/// Has a set of [codecs] for encoding and decoding the datatypes
class XmlRpcHandler {
  /// Creates a [XmlRpcHandler] that handles the set of [methods].
  ///
  /// It uses the specified set of [codecs] for encoding and decoding.
  XmlRpcHandler({
    required this.methods,
    List<Codec>? codecs,
  }) : codecs = codecs ?? List<Codec>.unmodifiable(<Codec>[
    ...standardCodecs,
    i8Codec,
    nilCodec,
  ]);

  /// The [codecs] used for encoding and decoding
  final List<Codec> codecs;

  /// The function registry
  final Map<String, Function> methods;

  /// Marshalls the [data] from XML to Dart types, and then dispatches the function, and marshals the return value back into the XMLRPC format
  Future<XmlDocument> handle(XmlDocument document) async {
    String methodName;
    // for(var m in methods.keys){
    //   print(m);
    // }
    final params = <dynamic?>[];
    try {
      final methodCall = document.findElements('methodCall').first;
      methodName = methodCall.findElements('methodName').first.text;
      var paramsElements = methodCall.findElements('params');
      if (paramsElements.isNotEmpty) {
        final args = paramsElements.first.findElements('param');
        for (final arg in args) {
          params.add(
            decode(getValueContent(arg.findElements('value').first), codecs),
          );
        }
      }
    } catch (e) {
      print("XmlRpcHandler.handle:ERR: $e");
      throw XmlRpcRequestFormatException(e);
    }

    // check method has target
    if (!methods.containsKey(methodName)) {
      throw XmlRpcMethodNotFoundException(methodName);
    }

    // print("XmlRpcHandler.handle:Execute:$methodName");
    // for(var p in params){
    //   print(p);
    // }
    // execute call
    Object? result;
    try {
      result = await Function.apply(methods[methodName]!, params);
    } catch (e) {
      print("XmlRpcHandler.handle:Execute:$methodName:ERR: $e");
      throw XmlRpcCallException(e);
    }

    // encode result
    XmlNode encodedResult;
    try {
      encodedResult = encode(result, codecs);
    } catch (e) {
      print("XmlRpcResponseEncodingException: $e");
      throw XmlRpcResponseEncodingException(e);
    }
    return XmlDocument([
      XmlProcessing('xml', 'version="1.0"'),
      XmlElement(XmlName('methodResponse'), [], [
        XmlElement(XmlName('params'), [], [
          XmlElement(XmlName('param'), [], [
            XmlElement(XmlName('value'), [], [encodedResult])
          ]),
        ])
      ])
    ]);
  }

  XmlDocument handleFault(Fault fault, {List<Codec>? codecs}) {
    XmlDocument temp;
    // temp=XmlDocument([
    //   XmlProcessing('xml', 'version="1.0"'),
    //   XmlElement(XmlName('methodResponse'), [], [
    //     XmlElement(XmlName('fault'), [], [
    //       XmlElement(XmlName('value'), [], [
    //         XmlText("----Fault: ${fault.toString()}")
    //       ])
    //     ])
    //   ])
    // ]);
    // return temp;
    XmlNode nodeval;
    try {
      nodeval = encode(fault, codecs ?? [faultCodec, ...this.codecs]);
    } catch (ex) {
      print("ERR---------------------------------$ex");
      print("RosFault---------------------------------${fault.toString()}");
      nodeval = XmlText("----Fault: ${fault.toString()} Exception: $ex");
    }

    temp = XmlDocument([
      XmlProcessing('xml', 'version="1.0"'),
      XmlElement(XmlName('methodResponse'), [], [
        XmlElement(XmlName('fault'), [], [
          XmlElement(XmlName('value'), [], [nodeval])
        ])
      ])
    ]);

    return temp;
  }
}

abstract class XmlRpcException implements Exception {
  XmlRpcException([this.cause]);

  /// The cause thrown when the real method was called.
  Object? cause;
}

class XmlRpcRequestFormatException extends XmlRpcException {
  XmlRpcRequestFormatException([Object? cause]) : super(cause);
}

/// When an exception occurs in the real method call
class XmlRpcMethodNotFoundException extends XmlRpcException {
  XmlRpcMethodNotFoundException(this.name);

  /// The name of the method not found.
  String name;
}

/// When an exception occurs in the real method call
class XmlRpcCallException extends XmlRpcException {
  XmlRpcCallException([Object? cause]) : super(cause);
}

/// When an exception occurs in response encoding
class XmlRpcResponseEncodingException extends XmlRpcException {
  XmlRpcResponseEncodingException([Object? cause]) : super(cause);
}

//https://github.com/Sashiri/xmlrpc_server/commit/09ab0085cf20d2bed047ce267ea2489e0d729817
//
// class XmlRpcServer {
//   final Map<String, Future<xml.XmlDocument> Function(List<dynamic>)> _bindings =
//       {};
//   int _port = 0;
//   dynamic _host = InternetAddress.anyIPv4;
//   HttpServer ? _server;
//
//   int get port {
//     return _server?.port??0;
//   }
//
//   dynamic get host {
//    return _server?.address.host;
//   }
//
//   HttpServer get __server{
//     if( _server==null)
//       {
//         throw Exception("Have to call function before do anything: XmlRpcServer.startServer");
//       }
//
//     return _server!;
//   }
//
//   XmlRpcServer({dynamic? host, int? port}) {
//     if (host != null) _host = host;
//     if (port != null) _port = port;
//   }
//
//   void bind(String methodName,
//       Future<xml.XmlDocument> Function(List<dynamic>) callback) {
//     _bindings.putIfAbsent(methodName, () => callback);
//   }
//
//   Future<xml.XmlDocument> _handleRequest(xml.XmlDocument document) async {
//     var methodCall = document.findElements('methodCall').first;
//     var methodName = methodCall.findElements('methodName').first.text;
//     var method = _bindings.entries.firstWhere((x) => x.key == methodName).value;
//
//     final params = methodCall.findElements('params');
//     if (params.isNotEmpty) {
//       final values = [];
//       params.first.findElements('param').forEach((param) {
//         final valueNode = param.findElements('value').first;
//         final value = getValueContent(valueNode);
//         values.add(decode(value, xml_rpc.standardCodecs));
//       });
//       return await method(values);
//     } else {
//       //TODO: Jeśli nie zostały przekazane parametry
//       print("_handleRequest: Jeśli nie zostały przekazane parametry");
//     }
//
//     return xml.XmlDocument({
//       xml.XmlProcessing('xml', 'version="1.0"'),
//       xml.XmlElement(xml.XmlName('methodResponse'), [], [])
//     });
//   }
//
//   Future<void> startServer() async {
//     _server = await HttpServer.bind(_host, _port, shared: true);
//
//     print("ROS_HOSTNAME: ${__server.address.host}:${__server.port}");
//
//     _loopProcessCallback();
//   }
//
//   Future<void> _loopProcessCallback() async{
//
//     await for (HttpRequest request in __server) {
//
//       var xmlRequest = await utf8.decoder
//           .bind(request)
//           .join()
//           .then((value) => xml.XmlDocument.parse(value));
//
//       final response =
//       await _handleRequest(xmlRequest).then((doc) => doc.toXmlString());
//
//       request.response.statusCode = HttpStatus.ok;
//       request.response.headers
//         ..contentType = ContentType('text', 'xml')
//         ..contentLength = response.length;
//
//       request.response.write(response);
//
//       await request.response.close();
//     }
//
//     print("ROS_HOSTNAME: ${__server.address.host}:${__server.port} -> Ended");
//   }
//
//   Future<void> stopServer() {
//     return __server.close();
//   }
// }
//
// xml.XmlDocument generateXmlResponse(List params, {List<Codec>? encodeCodecs}) {
//   encodeCodecs = encodeCodecs ?? xml_rpc.standardCodecs;
//   final methodCallChildren = [
//     xml.XmlElement(
//         xml.XmlName('params'),
//         [],
//         params.map((p) => xml.XmlElement(xml.XmlName('param'), [], [
//               xml.XmlElement(
//                   xml.XmlName('value'), [], [encode(p, encodeCodecs!)])
//             ])))
//   ];
//   return xml.XmlDocument([
//     xml.XmlProcessing('xml', 'version="1.0"'),
//     xml.XmlElement(xml.XmlName('methodResponse'), [], methodCallChildren)
//   ]);
// }
