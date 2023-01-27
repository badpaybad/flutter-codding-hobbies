import 'dart:typed_data';
import 'dart:io' as DartIo;
import 'AppContext.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class HttpBase {
  Map<String, String> _buildHeader({Map<String, String>? headers}) {
    headers ??= <String, String>{};
    headers['Authorization'] = "Bearer ${AppContext.instance.appBearerToken}";
    //todo: add some context info to request
    return headers;
  }

  Future<T?> Get<T>(apiUrl, {Map<String, String>? headers}) async {
    headers = _buildHeader(headers: headers);

    final http.Response response = await http.get(
      Uri.parse(apiUrl),
      headers: headers,
    );

    if (response.statusCode != 200) {
      print("ERROR: ${DateTime.now().toIso8601String()} : $apiUrl");
      print(response.body);
      return null;
    }
    if (T is String) {
      return response.body as T;
    }
    final T data = jsonDecode(response.body) as T;

    return data;
  }

  Future<T?> Post<T>(apiUrl, Object? body,
      {Map<String, String>? headers}) async {
    headers = _buildHeader(headers: headers);
    headers["Content-type"] = "application/json";
    headers["Accept"] = "application/json";
    var jsonBody = jsonEncode(body);
    final http.Response response =
        await http.post(Uri.parse(apiUrl), headers: headers, body: jsonBody);

    if (response.statusCode != 200) {
      print("ERROR: ${DateTime.now().toIso8601String()} : $apiUrl");
      print(response.body);
      return null;
    }

    if (T is String) {
      return response.body as T;
    }
    try {
      final T data = jsonDecode(response.body) as T;

      return data;
    } catch (ex) {
      return response.body as T;
    }
  }

  Future<T?> PostForm<T>(
      String apiUrl, Map<String, String> fields, Map<String, String> files,
      {Map<String, String>? headers}) async {
    headers = _buildHeader(headers: headers);

    headers["accept"] = "application/json";
    headers["Content-Type"] = "multipart/form-data";
    //https://pub.dev/documentation/http/latest/http/MultipartRequest-class.html
    var request = http.MultipartRequest("POST", Uri.parse(apiUrl));
    request.headers.addAll(headers);
    request.fields.addAll(fields);
    print(request.toString());
    for (var fk in files.keys) {
      var filepath = files[fk] ?? "";
      if (filepath == "") {
        print("WARNING: $fk : have no value, no file path provided");
        continue;
      }
      //var file = DartIo.File.fromUri(Uri.parse(filepath));
      // var filename = path.basename(filepath);
      // //var tempBytes=  http.ByteStream(file.openRead());
      //  request.files.add(
      //      http.MultipartFile.fromBytes("faceimage", await file.readAsBytes(), filename: filename));
      //
      // // var xxx= http.MultipartFile("faceimage", http.ByteStream(file.openRead()), await file.length()
      // // , filename: filename);
      // // request.files.add(xxx);
      // //request.files.add(await _multipartFileFromPath("faceimage",filepath));

      request.files
          .add(await http.MultipartFile.fromPath("faceimage", filepath));
    }
    var response = await request.send();
    if (response.statusCode != 200) {
      print("ERROR: ${DateTime.now().toIso8601String()} : $apiUrl");
      print(await response.stream.bytesToString());
      return null;
    }

    if (T is String) {
      return response.stream.bytesToString() as T;
    }
    try {
      final T data = jsonDecode(await response.stream.bytesToString()) as T;

      return data;
    } catch (ex) {
      return response.stream.bytesToString() as T;
    }
  }

  Future<T?> PostFormFilesInBytes<T>(
      String apiUrl, Map<String, String> fields, Map<String, Uint8List> files,
      {Map<String, String>? headers}) async {
    headers = _buildHeader(headers: headers);

    headers["accept"] = "application/json";
    headers["Content-Type"] = "multipart/form-data";
    //https://pub.dev/documentation/http/latest/http/MultipartRequest-class.html
    var request = http.MultipartRequest("POST", Uri.parse(apiUrl));
    request.headers.addAll(headers);
    request.fields.addAll(fields);
    print(request.toString());
    for (var fk in files.keys) {
      if (files[fk]?.length == 0) {
        print("WARNING: $fk : have no value, no file path provided");
        continue;
      }
      var filename = DateTime.now().toIso8601String();
      request.files.add(
          http.MultipartFile.fromBytes(fk, files[fk]!, filename: filename));
    }
    var response = await request.send();
    if (response.statusCode != 200) {
      print("ERROR: ${DateTime.now().toIso8601String()} : $apiUrl");
      print(await response.stream.bytesToString());
      return null;
    }

    if (T is String) {
      return response.stream.bytesToString() as T;
    }

    try {
      final T data = jsonDecode(await response.stream.bytesToString()) as T;

      return data;
    } catch (ex) {
      return response.stream.bytesToString() as T;
    }
  }

  Future<List<int>> _readFileByte(String filePath) async {
    Uri myUri = Uri.parse(filePath);
    var audioFile = DartIo.File.fromUri(myUri);
    var value = await audioFile.readAsBytes();
    return value;
  }

  String _getFileName(String pathFile) {
    var temp = pathFile.replaceAll("\\", "/");
    var idx = temp.lastIndexOf("/");
    if (idx > 0) {
      temp = temp.substring(idx + 1);
      return temp;
    }
    return "";
  }

  MediaType? _getMediaType(String pathFile) {
    var mimeType = lookupMimeType(pathFile);
    if (mimeType == null) return null;

    return MediaType.parse(mimeType);
  }

  Future<http.MultipartFile> _multipartFileFromPath(
      String field, String filePath,
      {String? filename, MediaType? contentType}) async {
    filename ??= path.basename(filePath);
    var file = DartIo.File(filePath);
    var length = await file.length();
    var stream = http.ByteStream(file.openRead());
    return http.MultipartFile(field, stream, length,
        filename: filename, contentType: contentType);
  }
}
