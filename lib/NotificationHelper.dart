import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_codding_hobbies/AppContext.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_codding_hobbies/PermissionsUi.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  //await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
  await AppContext.instance.initFirebaseApp();
  print(
      "---- Handling a background message: AppContext.instance.initFirebaseApp()");
  await NotificationHelper.instance
      ._setupNotifications(_do_when_use_touch_tab_into_notification_showed);
  print(
      "---- Handling a background message: _do_when_use_touch_tab_into_notification_showed");

  print(jsonEncode(message.data));

  NotificationHelper.instance.showNotification(message);
}

Future<void> _do_when_use_touch_tab_into_notification_showed(
    NotificationResponse msg) async {
  if (AppContext.instance.routesForNavigator.keys.length > 0) {
    //todo: base on msg then find route matching
    var routeName = AppContext.instance.routesForNavigator.keys.first;

    AppContext.instance.navigatorKey.currentState
        ?.pushNamed(routeName, arguments: {
      "test":
          "AppContext.instance.navigatorKey.currentState?.pushNamed(routeName",
      "msg": msg
    });

    // get args in method build (ContextBuilder context){
    // final args = ModalRoute.of(context)!.settings.arguments as dynamic;
  }
}

class NotificationHelper {
  static const String appIcon = "@mipmap/ic_launcher_adaptive_fore";

  // single color and should be .png
  static const String notifySmallIcon = "@mipmap/ic_launcher_adaptive_fore";

  static const String notifyLagerIcon = "@drawable/notification_icon";

  static AndroidInitializationSettings initializationSettingsAndroid =
      const AndroidInitializationSettings(notifySmallIcon);

  /// Create a [AndroidNotificationChannel] for heads up notifications
  static AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.high,
    //enableLights: true,
    //ledColor: Colors.orange
  );

  NotificationHelper._privateConstructor() {}

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  static final NotificationHelper instance =
      NotificationHelper._privateConstructor();

  static InitializationSettings initializationSettings = InitializationSettings(
    //iOS: initializationSettingsIOS,
    android: initializationSettingsAndroid,
  );

  var isFlutterLocalNotificationsInitialized = false;

  bool _is_init_call_in_void_main = false;

  Future<void> init_call_in_void_main() async {
    if (_is_init_call_in_void_main == true) return;
    _is_init_call_in_void_main = true;

    print("---- NotificationHelper.init_call_in_void_main");

    AppContext.instance.initFirebaseApp();
    FirebaseMessaging.instance.app = AppContext.instance.firebaseApp!;
    if (!kIsWeb) {
      await NotificationHelper.instance
          ._setupNotifications(_do_when_use_touch_tab_into_notification_showed);
    }
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  bool _isForgroundRegister = false;

  Future<void> onForgroundNotification(
      Future<void> Function(RemoteMessage) handle) async {
    if (_isForgroundRegister == true) {
      print(
          "---- onForgroundNotification: WARNING : called somewhere, should call one time in main");
      return;
    }
    _isForgroundRegister = true;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await init_call_in_void_main();
      print('---- Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      handle(message);
    });
  }

  Future<void> _setupNotifications(
      Future<void> Function(NotificationResponse)
          do_when_use_touch_tab_into_notification_showed) async {
    if (isFlutterLocalNotificationsInitialized) {
      return;
    }

    isFlutterLocalNotificationsInitialized = true;

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse:
          do_when_use_touch_tab_into_notification_showed,
      onDidReceiveNotificationResponse:
          do_when_use_touch_tab_into_notification_showed,
    );

    /// Create an Android Notification Channel.
    ///
    /// We use this channel in the `AndroidManifest.xml` file to override the
    /// default FCM channel to enable heads up notifications.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    var token = await getFcmToken();

    print("---- Token device id: $token");

    FirebaseMessaging.instance.onTokenRefresh?.listen((fcmTokenNew) async {
      // TODO: If necessary send token to application server.
      //fcmToken = await FirebaseMessaging.instance.getToken();
      print("---- _fcmToken refresh");
      print(fcmTokenNew);
      // Note: This callback is fired at each app startup and whenever a new
      // token is generated.
    }).onError((err) {
      // Error getting token.
    });

    // NotificationSettings settings = await  FirebaseMessaging.instance.requestPermission(
    //   alert: true,
    //   announcement: true,
    //   badge: true,
    //   carPlay: true,
    //   criticalAlert: true,
    //   provisional: true,
    //   sound: true,
    // );
    //
    // var recheckSettings = await FirebaseMessaging.instance.getNotificationSettings();
    //
    // print("---User granted permission:");
    // print('${recheckSettings?.authorizationStatus??""}');
  }

  void showNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    if (!kIsWeb) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        jsonEncode(message.data),
        jsonEncode(message.data),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            // TODO add a proper drawable resource to android, for now using
            //      one that already exists in example app.
            icon: notifySmallIcon,
            colorized: true,
            color: Colors.orange,
            largeIcon: const DrawableResourceAndroidBitmap(notifyLagerIcon),
          ),
        ),
      );
    }
  }

  String? fcmToken;

  Future<String?> getFcmToken() async {
    // // //https://firebase.flutter.dev/docs/messaging/usage/

    fcmToken = await FirebaseMessaging.instance.getToken();

    return fcmToken ?? "";
  }
}
