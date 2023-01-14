import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:image/image.dart' as DartImage;
import '../RosAppContext.dart';

class VideoDisplayFromRosUi extends StatefulWidget {
  bool showFaceDetect = false;

  double? width;
  double? height;

  VideoDisplayFromRosUi(
      {this.width, this.height, this.showFaceDetect = false, super.key});

  @override
  State<StatefulWidget> createState() {
    return _VideoDisplayFromRosUiState();
  }
}

class _VideoDisplayFromRosUiState extends State<VideoDisplayFromRosUi> {
  final RosAppContext _rosNotifier = RosAppContext.instance;

  DartImage.Image? _firstFrame;

  double _ratioVid = 1;

  @override
  Widget build(BuildContext context) {
    if (_firstFrame == null && _rosNotifier.visionImage != null) {
      _firstFrame = DartImage.readJpg(_rosNotifier.visionImage!);

      if (widget.height != null && widget.width == null) {
        _ratioVid = widget.height! / _firstFrame!.height;

        widget.width = _ratioVid * _firstFrame!.width;
      }
      if (widget.height == null && widget.width != null) {
        _ratioVid = widget.width! / _firstFrame!.width;
        widget.height = _ratioVid * _firstFrame!.height;
      }
    }

    var orient = MediaQuery.of(context).orientation;

    var width = orient == Orientation.landscape
        ? null
        : (widget.width ?? MediaQuery.of(context).size.width);

    var height = orient == Orientation.landscape
        ? (widget.height ?? MediaQuery.of(context).size.height)
        : null;

    //print("_VideoDisplayFromRosState w: ${MediaQuery.of(context).size.width} h: ${MediaQuery.of(context).size.height}");

    var layoutWidth = MediaQuery.of(context).size.width;
    var layoutHeight = MediaQuery.of(context).size.height;

    // print(
    //     "----------------- layoutWidth $layoutWidth layoutHeight $layoutHeight vidWidth: $width vidHeight: $height");

    var mainVidUi = _buildVideoBgAll(width, height);
    if (widget.showFaceDetect) {
      List<Widget> itms = [mainVidUi];

      return Center(
        child: Stack(
          children: itms,
        ),
      );
    }

    return mainVidUi;
  }

  @override
  void initState() {
    super.initState();

    // Timer.periodic(Duration(seconds: 5), (timer) async {
    //   if( _rosNotifier.visionImage!=null)
    //   {
    //     var xxx= await FaceRecognitionHelper().vectorFace(_rosNotifier!.visionImage!);
    //     //
    //     print(xxx);
    //   }
    // });

    _rosNotifier.addListener(() async {
      if (mounted) setState(() {});
    });
  }

  Widget _buildVideoBgAll(double? width, double? height) {
    var orient = MediaQuery.of(context).orientation;

    return Center(
      child: Container(
        child: _rosNotifier.visionImage != null
            ? Image.memory(
          _rosNotifier.visionImage!,
          gaplessPlayback: true,
          fit: orient == Orientation.portrait
              ? BoxFit.fitWidth
              : BoxFit.fitHeight,
        )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
