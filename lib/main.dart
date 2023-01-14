import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_codding_hobbies/AppContext.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_codding_hobbies/MessageBus.dart';
import 'package:flutter_codding_hobbies/NotificationHelper.dart';
import 'package:flutter_codding_hobbies/PermissionsPage.dart';
import 'package:flutter_codding_hobbies/WebRtcP2pVideoStreamPage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oktoast/oktoast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await MessageBus.instance.Init();
  await AppContext.instance.init_call_in_void_main();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    AppContext.instance.permissionsRequest();

    return MaterialApp(
      builder: (_, Widget? child) => OKToast(child: child!, position: ToastPosition.top,),
      navigatorKey: AppContext.instance.navigatorKey,
      routes: AppContext.instance.routesForNavigator,
      title: 'Flutter boilerplate',
      theme: ThemeData(
        primarySwatch: Colors.brown,
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

    NotificationHelper.instance.onForgroundNotification((msg) async {
      _lastMsg = jsonEncode(msg.data);
      if (mounted) setState(() {});
    });

    AppContext.instance.googleSignInSilently().then((v) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: AppContext.instance.googleCurrentUser == null
            ? const Text("Have to login first, click float button bellow")
            : _build(),
      ),
      floatingActionButton: AppContext.instance.googleCurrentUser == null
          ? FloatingActionButton(
              tooltip: 'Login',
              onPressed: () async {
                var r = await AppContext.instance.googleSignIn();

                if (mounted) setState(() {});
              },
              child: const Icon(Icons.login),
            )
          : FloatingActionButton(
              tooltip: 'Logout',
              onPressed: () async {
                await AppContext.instance.googleSignOut();
                if (mounted) setState(() {});
              },
              child: const Icon(Icons.logout),
            ),
    );
  }

  Widget _build() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Info: ${AppContext.instance.googleCurrentUser?.displayName}',
            style: Theme.of(context).textTheme.headline4,
          ),
          ElevatedButton(
            onPressed: () {
              NotificationHelper.instance.showNotification(
                  RemoteMessage(data: {"title": "test local noti ${DateTime.now()}"}));
            },
            child: const Text("Show notify local"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) {
                return  const WebRtcP2pVideoStreamPage();
              }));
            },
            child: const Text("Webrtc sample"),
          ),
          Text("LastMsg: $_lastMsg"),
          SelectableText("Fcm token: ${NotificationHelper.instance.fcmToken}"),
        ],
      ),
    );
  }
}
