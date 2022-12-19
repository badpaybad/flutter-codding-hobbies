import 'package:flutter/material.dart';
import 'package:flutter_codding_hobbies/NotificationHelper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

//https://firebase.google.com/docs/cloud-messaging/android/first-message
//https://firebase.google.com/docs/flutter/setup?platform=ios
//https://firebase.google.com/docs/flutter/setup?platform=ios#available-plugins

//https://github.com/firebase/flutterfire/blob/master/packages/firebase_messaging/firebase_messaging/example/lib/main.dart

class AppContext {
  AppContext._privateConstructor() {}

  static final AppContext instance = AppContext._privateConstructor();

  GoogleSignInAccount? CurrentUser;

  String? BearerToken;

  LogedInfo? logedInfo;

//https://developers.google.com/android/guides/client-auth
  GoogleSignIn _googleSignIn = GoogleSignIn(
    // Optional clientId
    // clientId: '479882132969-9i9aqik3jfjd7qhci1nqf0bm2g71rm1u.apps.googleusercontent.com',
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/contacts.readonly',
    ],
  );

  FirebaseApp? _firebaseApp;
  FirebaseDatabase? _firebaseDb;
  FirebaseAuth? _firebaseAuth;

  Map<String, WidgetBuilder> routesForNavigator = <String, WidgetBuilder>{};

  bool _isInitFirebaseApp = false;

  Future<void> initFirebaseApp() async {
    if (_isInitFirebaseApp == true) return;
    _isInitFirebaseApp = true;

    _firebaseApp = await Firebase.initializeApp(
        name: "AppContext",
        options: const FirebaseOptions(
            apiKey: "AIzaSyBwsIOZ9nZAuypco7ERdCVM74RMF_dK8Xo",
            appId: "realtimedbtest-d8c6b",
            messagingSenderId: "787425357847",
            projectId: "realtimedbtest-d8c6b"));
  }

  GlobalKey<NavigatorState> navigatorKey =
      GlobalKey(debugLabel: "Main Navigator");

  Future<void> SignInSilently() async {
    await initFirebaseApp();

    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      CurrentUser = account;

      if (CurrentUser != null) {
        var info = await _handleGetContact(CurrentUser!);
        logedInfo = LogedInfo(CurrentUser!, info);


        _firebaseAuth = FirebaseAuth.instanceFor(
            app: _firebaseApp!, persistence: Persistence.LOCAL);

        // Obtain the auth details from the request
        final GoogleSignInAuthentication? googleAuth =
            await account?.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );

        //to access other firebase s
        await _firebaseAuth!.signInWithCredential(credential);

        print("_firebaseAuth");
        if (_firebaseAuth?.currentUser == null) {
          await _firebaseAuth?.currentUser?.reload();
        }

        print(_firebaseAuth?.currentUser?.displayName);

        _firebaseDb = FirebaseDatabase.instanceFor(
            app: _firebaseApp!,
            databaseURL:
                "https://realtimedbtest-d8c6b-default-rtdb.asia-southeast1.firebasedatabase.app");

        DatabaseReference dbTestRef = _firebaseDb!.ref("fluttertest");

        dbTestRef.onValue.listen((event) async {
          print("event.snapshot.value");
          print(event.snapshot.value);
        });

/*{ firebase realtimedb
  "rules": {
    ".read":"auth.uid != null",
    ".write":"auth.uid != null"
  }
}*/
        await dbTestRef.set({"name": "du ${DateTime.now().toIso8601String()}"});

        Timer.periodic(Duration(seconds: 1), (timer) async {
          // await dbTestRef
          //     .set({"name": "du ${DateTime.now().toIso8601String()}"});
        });


      } else {
        logedInfo = null;
      }
    });
    await _googleSignIn.signInSilently();
  }

  Future<void> SignOut() async {
    await _googleSignIn.disconnect();
    CurrentUser = null;
    logedInfo = null;
  }

  Future<void> SignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print(error);
    }
  }

  Future<Map<String, dynamic>> _handleGetContact(
      GoogleSignInAccount user) async {
    final http.Response response = await http.get(
      Uri.parse('https://people.googleapis.com/v1/people/me/connections'
          '?requestMask.includeField=person.names'),
      headers: await user.authHeaders,
    );
    if (response.statusCode != 200) {
      print('People API ${response.statusCode} response: ${response.body}');
      return Map<String, dynamic>();
    }
    final Map<String, dynamic> data = json.decode(response.body);
    //final String? namedContact = _pickFirstNamedContact(data);
    return data;
  }

  String? _pickFirstNamedContact(Map<String, dynamic> data) {
    final List<dynamic>? connections = data['connections'] as List<dynamic>?;
    final Map<String, dynamic>? contact = connections?.firstWhere(
      (dynamic contact) => contact['names'] != null,
      orElse: () => null,
    ) as Map<String, dynamic>?;
    if (contact != null) {
      final Map<String, dynamic>? name = contact['names'].firstWhere(
        (dynamic name) => name['displayName'] != null,
        orElse: () => null,
      ) as Map<String, dynamic>?;
      if (name != null) {
        return name['displayName'] as String?;
      }
    }
    return null;
  }
}

class LogedInfo {
  GoogleSignInAccount? GoogleAcc;

  Map<String, dynamic>? AccInfo;

  LogedInfo(GoogleSignInAccount? googleAcc, Map<String, dynamic>? info)
      : GoogleAcc = googleAcc,
        AccInfo = info {}
}

/// Message route arguments.
class MessageArguments {
  /// The RemoteMessage
  final RemoteMessage message;

  /// Whether this message caused the application to open.
  final bool openedApplication;

  // ignore: public_member_api_docs
  MessageArguments(this.message, this.openedApplication);
}
