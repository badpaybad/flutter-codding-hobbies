import 'dart:io';

import 'package:flutter/material.dart';
import '/NotificationHelper.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';


//https://firebase.google.com/docs/cloud-messaging/android/first-message
//https://firebase.google.com/docs/flutter/setup?platform=ios
//https://firebase.google.com/docs/flutter/setup?platform=ios#available-plugins

//https://github.com/firebase/flutterfire/blob/master/packages/firebase_messaging/firebase_messaging/example/lib/main.dart

class AppContext {
  AppContext._privateConstructor() {}

  static final AppContext instance = AppContext._privateConstructor();

  GoogleSignInAccount? googleCurrentUser;

  String? appBearerToken;

  String? appFcmToken;

  UserContext? logedInfo;

//https://developers.google.com/android/guides/client-auth
  GoogleSignIn appGoogleSignIn = GoogleSignIn(
    // Optional clientId
    // clientId: '479882132969-9i9aqik3jfjd7qhci1nqf0bm2g71rm1u.apps.googleusercontent.com',
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/contacts.readonly',
    ],
  );

  FirebaseApp? firebaseApp;
  FirebaseDatabase? firebaseDb;
  FirebaseAuth? firebaseAuth;

  Map<String, WidgetBuilder> routesForNavigator = <String, WidgetBuilder>{};

  final String screenUiPermission = "PermissionsUi";
  final String screenUiFaceDefinitionRegister = "FaceDefinitionRegister";

  Image get logo => Image.network(
      "https://omt.vn/wp-content/themes/omt/assets/images/home/logo_header_2.png");

  Future<void> init_call_in_void_main() async {
    //todo: mapping your widget with router key for navigate, eg: noti onTab show screen
    // AppContext.instance.routesForNavigator.addAll({
    // });

    initFirebaseApp().then((value) async {
      NotificationHelper.instance.init();

    });
  }

  Future<void> openScreen(String screenName) async {
    await AppContext.instance.navigatorKey.currentState?.pushNamed(screenName);
  }

  bool _isInitFirebaseApp = false;

  Future<void> initFirebaseApp() async {
    try {
      if (_isInitFirebaseApp == true) return;
      _isInitFirebaseApp = true;

      await Firebase.initializeApp();

      firebaseApp = await Firebase.initializeApp(
          name: "EnglishApplication",
          options: const FirebaseOptions(
              apiKey: "AIzaSyBwsIOZ9nZAuypco7ERdCVM74RMF_dK8Xo",
              appId: "realtimedbtest-d8c6b",
              messagingSenderId: "787425357847",
              projectId: "realtimedbtest-d8c6b"));

      _isInitFirebaseApp = true;
    } catch (ex) {
      print("initFirebaseApp ERR: $ex");
      _isInitFirebaseApp = false;
    }
  }

  GlobalKey<NavigatorState> navigatorKey =
  GlobalKey(debugLabel: "Main Navigator");

  Future<void> googleSignInSilently() async {
    await initFirebaseApp();

    //todo: if you dont want use google login, use your server, you need custom token from server use firebase admin to generate
    //_firebaseAuth!.signInWithCustomToken(token_custom);

    appGoogleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      googleCurrentUser = account;

      if (googleCurrentUser != null) {
        var info = await _handleGetContact(googleCurrentUser!);
        logedInfo = UserContext(googleCurrentUser!, info);

        firebaseAuth = FirebaseAuth.instanceFor(
            app: firebaseApp!, persistence: Persistence.LOCAL);

        // Obtain the auth details from the request
        final GoogleSignInAuthentication? googleAuth =
        await account?.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );

        //to access other firebase s
        await firebaseAuth!.signInWithCredential(credential);

        print(firebaseAuth?.currentUser?.displayName);

        firebaseDb = FirebaseDatabase.instanceFor(
            app: firebaseApp!,
            databaseURL:
            "https://realtimedbtest-d8c6b-default-rtdb.asia-southeast1.firebasedatabase.app");

        DatabaseReference dbTestRef = firebaseDb!.ref("fluttertest");

        dbTestRef.onValue.listen((event) async {
          print("event.snapshot.value");
          print(event.snapshot.value);
        });

        await dbTestRef.set({"name": "du ${DateTime.now().toIso8601String()}"});

        Timer.periodic(const Duration(seconds: 1), (timer) async {
          // await dbTestRef
          //     .set({"name": "du ${DateTime.now().toIso8601String()}"});
        });
      } else {
        logedInfo = null;
      }
    });
    await appGoogleSignIn.signInSilently();
  }

  Future<void> googleSignOut() async {
    await initFirebaseApp();

    await appGoogleSignIn.disconnect();
    googleCurrentUser = null;
    logedInfo = null;
  }

  Future<void> googleSignIn() async {
    try {
      await initFirebaseApp();

      await appGoogleSignIn.signIn();

      appFcmToken = await NotificationHelper.instance.getFcmToken();
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


  void permissionsRequest() {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      [
        Permission.accessMediaLocation,
        Permission.camera,
        Permission.audio,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
        Permission.ignoreBatteryOptimizations,

        //Permission.accessNotificationPolicy,
        Permission.notification,
        Permission.mediaLibrary,
        Permission.microphone,
        Permission.manageExternalStorage,
        Permission.storage,
        //add more permission to request here.
      ].request().then((statuses) async {
        // var isDenied =
        //     statuses.values.any((p) => (p.isDenied || p.isPermanentlyDenied
        //         //||
        //         //p.isLimited ||
        //         //p.isRestricted
        //         ));
        // if (isDenied) {
        //   for (var pk in statuses.keys) {
        //     print("${pk}: ${statuses[pk]}");
        //   }
        //
        //   showToast(
        //       "You have allow access microphone and storage, quiting ...\r\n\r\nIf you see message again and again should re-install application\r\nThen allow permission to access microphone and storage",
        //       duration: const Duration(seconds: 5),
        //       textAlign: TextAlign.left);
        //   await Future.delayed(const Duration(seconds: 5));
        //   try {
        //     if (mounted) Navigator.of(context).pop();
        //   } catch (ex) {}
        //   try {
        //     if (mounted) SystemNavigator.pop();
        //   } catch (ex) {}
        // }
      });
    }
  }

}

class UserContext {
  GoogleSignInAccount? GoogleAcc;

  Map<String, dynamic>? AccInfo;

  UserContext(GoogleSignInAccount? googleAcc, Map<String, dynamic>? info)
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
