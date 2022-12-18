import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_codding_hobbies/AppContext.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_codding_hobbies/Permissions.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  //await Firebase.initializeApp();

  await AppContext.instance.initFirebaseApp();
  await setupFlutterNotifications();

  print("Handling a background message: ${message.messageId}");

  print(jsonEncode(message.data));

  showFlutterNotification(message);
}

Future<void> _onTab_onTouch_onSelect_to_notification_showed(NotificationResponse msg) async{

  if (AppContext.instance.routesForNavigator.keys.length > 0) {
    var routeName = AppContext.instance.routesForNavigator.keys.first;
    AppContext.instance.navigatorKey.currentState?.pushNamed(routeName,
    arguments:  {"test":"AppContext.instance.navigatorKey.currentState?.pushNamed(routeName"}
    );
  }
}


/// Create a [AndroidNotificationChannel] for heads up notifications
late AndroidNotificationChannel channel;

final AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings("@drawable/jun_sau_avatar");

final InitializationSettings initializationSettings = InitializationSettings(
  //iOS: initializationSettingsIOS,
  android: initializationSettingsAndroid,
);

var isFlutterLocalNotificationsInitialized = false;

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }
  channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.high,
  );
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveBackgroundNotificationResponse: _onTab_onTouch_onSelect_to_notification_showed,
    onDidReceiveNotificationResponse: _onTab_onTouch_onSelect_to_notification_showed,
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
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  isFlutterLocalNotificationsInitialized = true;
}

void showFlutterNotification(RemoteMessage message) {
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
          icon: '@drawable/jun_sau_avatar',
          largeIcon:
              const DrawableResourceAndroidBitmap('@drawable/jun_sau_avatar'),
        ),
      ),
    );
  }
}

/// Initialize the [FlutterLocalNotificationsPlugin] package.
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppContext.instance.initFirebaseApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  AppContext.instance.routesForNavigator.addAll({
    "Permissions": (BuildContext ctx)=> Permissions(),
  });

  if (!kIsWeb) {
    await setupFlutterNotifications();
  }

  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      navigatorKey: AppContext.instance.navigatorKey,
      routes: AppContext.instance.routesForNavigator,
      title: 'Flutter boilerplate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter boilerplate'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _lastMsg = "";

  @override
  void initState() {
    super.initState();

    AppContext.instance.forgroundNotification(context, showNoti: (msg) async {
      //showFlutterNotification(msg);
      _lastMsg = jsonEncode(msg.data);
      if (mounted) setState(() {});
    });

    AppContext.instance.SignInSilently().then((v) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: _build(),
      ) ,
      floatingActionButton: AppContext.instance.CurrentUser == null
          ? FloatingActionButton(
              tooltip: 'Login',
              onPressed: () async {
                var r = await AppContext.instance.SignIn();

                if (mounted) setState(() {});
              },
              child: const Icon(Icons.login),
            )
          : FloatingActionButton(
              tooltip: 'Logout',
              onPressed: () async {
                await AppContext.instance.SignOut();
                if (mounted) setState(() {});
              },
              child: const Icon(Icons.logout),
            ),
    );
  }

  Widget _build(){
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Info: ${AppContext.instance.CurrentUser?.displayName}',
            style: Theme.of(context).textTheme.headline4,
          ),
          ElevatedButton(onPressed: ()async{
            AppContext.instance.navigatorKey.currentState?.pushNamed("Permissions");
          }, child: Text("Show permissions"),),
          Text("Notification received: $_lastMsg"),
          SelectableText("${AppContext.instance.FcmToken}"),
        ],
      ),
    );
  }
}
