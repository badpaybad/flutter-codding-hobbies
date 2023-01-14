import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:image/image.dart' as DartImage;
import '../RosAppContext.dart';

class UiImagePainter extends CustomPainter {
  ui.Image? _image;

  get image => _image;

  UiImagePainter(ui.Image? image) {
    _image = image;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_image == null) return;

    canvas.save();
    canvas.scale(1, -1);
    canvas.translate(0, _image!.height.toDouble());
    canvas.drawImage(_image!, Offset.zero, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(UiImagePainter oldDelegate) {
    return oldDelegate.image != null &&
        oldDelegate.image.hashCode != image.hashCode;
  }
}
