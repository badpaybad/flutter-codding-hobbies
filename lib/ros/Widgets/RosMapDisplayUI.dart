import 'dart:io';

import 'package:flutter/material.dart';
import '../ros_nodes.dart';
import '../RosAppContext.dart';
import 'UiImagePainter.dart';

class RosMapDisplayUI extends StatefulWidget {
  RosMapDisplayUI({super.key}) {}

  @override
  State<StatefulWidget> createState() {
    return _RosMapDisplayUIState();
  }
}

class _RosMapDisplayUIState extends State<RosMapDisplayUI> {
  RosAppContext vision = RosAppContext.instance;

  _RosMapDisplayUIState() {
    vision.addListener(_refresh);
  }

  @override
  void dispose() {
    vision.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var row = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        vision.visionAvailable && vision.visionImage != null
            ? SizedBox(
                child: Image.memory(vision.visionImage!, gaplessPlayback: true),
                width: 160,
                height: 120,
              )
            : CircularProgressIndicator(),
        vision.mapAvailable && vision.mapImage != null
            ? SizedBox(
                width: 160,
                height: 120,
                child: CustomPaint(painter: UiImagePainter(vision.mapImage)),
              )
            : CircularProgressIndicator(),
      ],
    );

    return SizedBox(
      width: 320,
      height: 240,
      child: Column(
        children: [
          row,
          Text(vision.veliocityAvailable && vision.veliocity != null
              ? vision.veliocity!.linear.x.toString()
              : "No veliocity available"),
        ],
      ),
    );

// return Scaffold(
//   appBar: AppBar(
//     title: Text(widget.title),
//   ),
//   body: Center(
//     child: ,
//     // FittedBox(
//     //   child: Column(
//     //     children: [
//     //
//     //       // Text(vision.veliocityAvailable
//     //       //     ? vision.veliocity!.linear.x.toString()
//     //       //     : "No veliocity available"),
//     //     ],
//     //   ),
//     // ),
//   ),
//   floatingActionButton: FloatingActionButton(
//     onPressed: _refresh,
//     tooltip: 'Refresh view',
//     child: Icon(Icons.refresh),
//   ), // This trailing comma makes auto-formatting nicer for build methods.
// );
  }
}
