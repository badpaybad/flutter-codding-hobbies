import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_codding_hobbies/AppContext.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_codding_hobbies/NotificationHelper.dart';
import 'package:flutter_codding_hobbies/PermissionsUi.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //todo: mapping your widget with router key for navigate, eg: noti onTab show screen
  AppContext.instance.routesForNavigator.addAll({
    "Permissions": (BuildContext ctx) => PermissionsUi(),
  });

  await AppContext.instance.init_call_in_void_main();

  await NotificationHelper.instance.init_call_in_void_main();

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

    NotificationHelper.instance.onForgroundNotification( (msg) async {
      _lastMsg= jsonEncode(msg.data);
      if (mounted) setState(() {});
    });

    AppContext.instance.SignInSilently().then((v) {
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
        child: AppContext.instance.CurrentUser == null
            ? Text("Have to login first, click float button bellow")
            : _build(),
      ),
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

  Widget _build() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Info: ${AppContext.instance.CurrentUser?.displayName}',
            style: Theme.of(context).textTheme.headline4,
          ),
          ElevatedButton(
            onPressed: () {
              NotificationHelper.instance.showNotification(
                  RemoteMessage(data: {"title": "test local noti"}));
            },
            child: Text("Show noti local test"),
          ),
          ElevatedButton(
            onPressed: () async {
              AppContext.instance.navigatorKey.currentState
                  ?.pushNamed("Permissions");
            },
            child: Text("Show permissions"),
          ),
          Text("Notification received: $_lastMsg"),
          SelectableText("${NotificationHelper.instance.fcmToken}"),
        ],
      ),
    );
  }
}
