import 'package:flutter_codding_hobbies/AppContext.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';

class HttpBase {

Future<T?> Get<T>(apiUrl, {Map<String,String> ?headers}) async {

  headers ??= Map<String,String>();
  headers['Authorization']= "Bearer ${AppContext.instance.BearerToken}";

  final http.Response response = await http.get(
    Uri.parse(apiUrl),
    headers: headers,
  );

  if (response.statusCode != 200) {
    return null;
  }
  final T data =  json.decode(response.body) as T;

  return data;
}

}