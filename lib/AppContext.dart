import 'package:flutter/material.dart';
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
  AppContext._privateConstructor();

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
  FirebaseMessaging? _firebaseMsg;
  FirebaseAuth? _firebaseAuth;
  String? _fcmToken;

  String? FcmToken()=> _fcmToken;

  Future<void> initFirebaseApp() async{
    if(_firebaseApp!=null) return;

    _firebaseApp = await Firebase.initializeApp(
        name: "DEFAULT",
        options: FirebaseOptions(
            apiKey: "AIzaSyBwsIOZ9nZAuypco7ERdCVM74RMF_dK8Xo",
            appId: "realtimedbtest-d8c6b",
            messagingSenderId: "787425357847",
            projectId: "realtimedbtest-d8c6b"));



  }

  Future<void> forgroundNotification(BuildContext context) async{

    //Foreground messages notification (FCM)

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    //
    // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //   print('A new onMessageOpenedApp event was published!');
    //   Navigator.pushNamed(
    //     context,
    //     '/message',
    //     arguments: MessageArguments(message, true),
    //   );
    // });

  }

  Future<void> SignInSilently() async {
    print("-------SignInSilently");

    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      CurrentUser = account;

      if (CurrentUser != null) {
        var info = await _handleGetContact(CurrentUser!);
        logedInfo = LogedInfo(CurrentUser!, info);

        // _firebaseApp = await Firebase.initializeApp(
        //     name: "DEFAULT",
        //     options: FirebaseOptions(
        //         apiKey: "AIzaSyBwsIOZ9nZAuypco7ERdCVM74RMF_dK8Xo",
        //         appId: "realtimedbtest-d8c6b",
        //         messagingSenderId: "787425357847",
        //         projectId: "realtimedbtest-d8c6b"));

        await initFirebaseApp();

        _firebaseAuth= FirebaseAuth.instanceFor(app: _firebaseApp!,
        persistence: Persistence.LOCAL );

        // Obtain the auth details from the request
        final GoogleSignInAuthentication? googleAuth = await account?.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );

        //to access other firebase s
        await _firebaseAuth!.signInWithCredential(credential);

        print("_firebaseAuth");
        if(_firebaseAuth?.currentUser==null){
          await _firebaseAuth?.currentUser?.reload();
        }

        print(_firebaseAuth?.currentUser?.displayName);
        // // //https://firebase.flutter.dev/docs/messaging/usage/
        // NotificationSettings settings = await _firebaseMsg!.requestPermission(
        //   alert: true,
        //   announcement: true,
        //   badge: true,
        //   carPlay: true,
        //   criticalAlert: true,
        //   provisional: true,
        //   sound: true,
        // );
        //
        // settings =
        // await FirebaseMessaging.instance.getNotificationSettings();

        //print('User granted permission: ${settings.authorizationStatus}');

        _firebaseDb = FirebaseDatabase.instanceFor(
            app: _firebaseApp!,
            databaseURL:
                "https://realtimedbtest-d8c6b-default-rtdb.asia-southeast1.firebasedatabase.app");

        _firebaseMsg = FirebaseMessaging.instance;

        _fcmToken = await FirebaseMessaging.instance.getToken();

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
        await dbTestRef
            .set({"name": "du ${DateTime.now().toIso8601String()}"});

        Timer.periodic(Duration(seconds: 1), (timer) async {
          // await dbTestRef
          //     .set({"name": "du ${DateTime.now().toIso8601String()}"});
        });

        print("_fcmToken");
        print(_fcmToken);

        FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
          // TODO: If necessary send token to application server.
          _fcmToken = await FirebaseMessaging.instance.getToken();
          print("_fcmToken refresh");
          print(_fcmToken);
          // Note: This callback is fired at each app startup and whenever a new
          // token is generated.
        }).onError((err) {
          // Error getting token.
        });
        //
        // //Foreground messages notification (FCM)
        //
        // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        //   print('Got a message whilst in the foreground!');
        //   print('Message data: ${message.data}');
        //
        //   if (message.notification != null) {
        //     print('Message also contained a notification: ${message.notification}');
        //   }
        // });


      } else {
        logedInfo = null;
        print("-----fail loged in to google");
      }
    });
    await _googleSignIn.signInSilently();

    print("-------SignInSilently....");
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