import 'dart:typed_data';
import '../Int8List.dart';
import '../nav_msgs/MapMetaData.dart';
import '../std_msgs/Header.dart';
import '../../ros_message.dart';

class NavMsgsOccupancyGrid extends RosMessage {
  var header = StdMsgsHeader();
  var info = NavMsgsMapMetaData();
  final _data = RosInt8List();

  Int8List get data => _data.list;
  set data(Int8List list) => _data.list = list;

  NavMsgsOccupancyGrid()
      : super('OccupancyGrid msg definition', 'nav_msgs/OccupancyGrid',
            '3381f2d731d4076ec5c71b0759edbe4e') {
    params.add(header);
    params.add(info);
    params.add(_data);
  }
}


class GridImageConverter extends NavMsgsOccupancyGrid {
  Uint8List toRGBA() {
    var buffor = BytesBuilder();
    for (var value in data) {
      switch (value) {
        case -1:
          buffor.add([77, 77, 77, 255]);
          break;
        default:
          var grayscale = (((100 - value) / 100.0) * 255).round().toUnsigned(8);
          var r = grayscale;
          var b = grayscale;
          var g = grayscale;
          const a = 255;
          buffor.add([r, g, b, a]);
      }
    }
    return buffor.takeBytes();
  }
}
