import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_codding_hobbies/AppContext.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_codding_hobbies/Permissions.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  NotificationHelper._privateConstructor() {
    print("init notfication helper");
    AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings("@drawable/appicon");
    initializationSettings = InitializationSettings(
      //iOS: initializationSettingsIOS,
      android: initializationSettingsAndroid,
    );

    channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.high,
    );
  }

  /// Initialize the [FlutterLocalNotificationsPlugin] package.
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  static final NotificationHelper instance =
      NotificationHelper._privateConstructor();

  /// Create a [AndroidNotificationChannel] for heads up notifications
  late AndroidNotificationChannel channel;

  late InitializationSettings initializationSettings;

  var isFlutterLocalNotificationsInitialized = false;

  Future<void> setupNotifications(
      Future<void> Function(NotificationResponse)
          topFunction_onTab_onTouch_onSelect_to_notification_showed) async {
    if (isFlutterLocalNotificationsInitialized) {
      return;
    }

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse:
          topFunction_onTab_onTouch_onSelect_to_notification_showed,
      onDidReceiveNotificationResponse:
          topFunction_onTab_onTouch_onSelect_to_notification_showed,
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

    print("Token device id: $token");

    FirebaseMessaging.instance.onTokenRefresh.listen((fcmTokenNew) async {
      // TODO: If necessary send token to application server.
      fcmToken = await FirebaseMessaging.instance.getToken();
      print("_fcmToken refresh");
      print(fcmTokenNew);
      // Note: This callback is fired at each app startup and whenever a new
      // token is generated.
    }).onError((err) {
      // Error getting token.
    });

    isFlutterLocalNotificationsInitialized = true;
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
            icon: 'jun_sau_avatar',
            largeIcon:
                const DrawableResourceAndroidBitmap('@drawable/jun_sau_avatar'),
          ),
        ),
      );
    }
  }

  String? fcmToken;

  Future<String?> getFcmToken() async {
    // // //https://firebase.flutter.dev/docs/messaging/usage/

    fcmToken = await FirebaseMessaging.instance.getToken();

    return fcmToken;
    // NotificationSettings settings = await  FirebaseMessaging.instance!.requestPermission(
    //   alert: true,
    //   announcement: true,
    //   badge: true,
    //   carPlay: true,
    //   criticalAlert: true,
    //   provisional: true,
    //   sound: true,
    // );
    //
    // settings = await FirebaseMessaging.instance.getNotificationSettings();
    //
    // print('User granted permission: ${settings.authorizationStatus}');
  }
}
