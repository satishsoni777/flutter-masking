import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:ui' as ui show Image;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class Drawing extends StatefulWidget {
  @override
  _DrawingState createState() => new _DrawingState();
}

enum PaintChoice { Paint, Eraser, Masking }

class _DrawingState extends State<Drawing> {
  PaintController _paintController = new PaintController();
  PaintChoice choice = PaintChoice.Paint;
  Color pickerColor = Colors.red;
  Color currentColor = Colors.red;
  double _value = 10;
  ui.Image image;
  @override
  void initState() {
    super.initState();
    cacheImage('assets/image.jpg');
  }

  Future<void> cacheImage(String asset) async {
    try {
      ByteData data = await rootBundle.load(asset);
      ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      ui.FrameInfo fi = await codec.getNextFrame();
      image = fi.image;
      print(image);
    } catch (e) {
      print(e);
    }
  }

  void _showDialog() {
    showDialog(
        context: context,
        child: AlertDialog(
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (c) {
                print(c);
                setState(() {
                  pickerColor = c;
                });
              },
              enableLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: const Text('Got it'),
              onPressed: () {
                setState(() => currentColor = pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.grey[300],
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 8,
            child: CustomPaint(
              child: RepaintBoundary(
                child: GestureDetector(
                  onPanUpdate: (s) {
                    Offset pos = (context.findRenderObject() as RenderBox)
                        .globalToLocal(s.globalPosition);
                    _paintController.addPoint(
                        offset: pos,
                        choice: choice,
                        image: image,
                        color: pickerColor,
                        strokeWidth: _value);
                  },
                  onPanEnd: (e) {
                    print('drag end');
                    _paintController.addPoint(
                        offset: null,
                        choice: choice,
                        color: pickerColor,
                        image: image,
                        strokeWidth: _value);
                  },
                ),
              ),
              painter: _Paint(
                  controller: _paintController, repaint: _paintController),
            ),
          ),
          Slider(
            semanticFormatterCallback: (double d) {
              return '${d.round()} strokeWidth';
            },
            onChanged: (s) {
              setState(() {
                _value = s;
              });
            },
            value: _value ?? 0.0,
            max: 50,
            min: 0.0,
            // divisions: 5,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: pickerColor,
                  child: IconButton(
                    tooltip: 'Choice Color',
                    icon: Icon(Icons.color_lens),
                    onPressed: () => _showDialog(),
                  ),
                ),
                CircleAvatar(
                  backgroundColor: pickerColor,
                  child: IconButton(
                      tooltip: 'Paint',
                      onPressed: () {
                        choice = PaintChoice.Paint;
                      },
                      icon: Icon(Icons.brush)),
                ),
                CircleAvatar(
                  backgroundImage: AssetImage('assets/image.jpg'),
                  child: IconButton(
                      tooltip: 'Masking effect',
                      disabledColor: pickerColor,
                      onPressed: () {
                        choice = PaintChoice.Masking;
                      },
                      icon: Icon(Icons.format_paint)),
                ),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                      tooltip: 'Eraser',
                      disabledColor: pickerColor,
                      onPressed: () {
                        choice = PaintChoice.Eraser;
                      },
                      icon: Icon(Icons.phonelink_erase)),
                ),
                CircleAvatar(
                  child: IconButton(
                      tooltip: 'Clear All',
                      disabledColor: pickerColor,
                      onPressed: () {
                        choice = PaintChoice.Paint;
                        _paintController.clear();
                        setState(() {});
                      },
                      icon: Icon(Icons.clear)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _Paint extends CustomPainter {
  _Paint({this.controller, Listenable repaint}) : super(repaint: repaint);
  PaintController controller;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (int i = 0; i < controller.pathHistory.length - 1; i++) {
      if (controller.pathHistory[i].points != null &&
          controller.pathHistory[i + 1].points != null) {
        canvas.drawLine(
            controller.pathHistory[i].points,
            controller.pathHistory[i + 1].points,
            controller.pathHistory[i].paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_Paint oldDelegate) =>
      oldDelegate.controller.pathHistory != controller.pathHistory;
}

class PathHistory {
  Offset points;
  Paint paint;
  PaintChoice paintChoice;
  ui.Image image;
  final double devicePixelRatio = ui.window.devicePixelRatio;
  PathHistory(
      {Offset offset,
      ui.Image image,
      PaintChoice paintChoice,
      Color color,
      double strokeWidth}) {
    // this.image = image;
    this.paintChoice = paintChoice;
    points = offset;
    final Float64List deviceTransform = new Float64List(16)
      ..[0] = devicePixelRatio
      ..[5] = devicePixelRatio
      ..[10] = 1.0
      ..[15] = 3.5;
    paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color;
    switch (paintChoice) {
      case PaintChoice.Paint:
        break;
      case PaintChoice.Masking:
        paint.shader = ImageShader(
            image, TileMode.repeated, TileMode.repeated, deviceTransform);
        break;
      case PaintChoice.Eraser:
        paint.blendMode = BlendMode.clear;
    }
  }
}

class PaintController extends ChangeNotifier {
  List<PathHistory> pathHistory = [];
  void addPoint(
      {Offset offset,
      PaintChoice choice,
      ui.Image image,
      Color color,
      double strokeWidth = 10}) {
    pathHistory.add(PathHistory(
        offset: offset,
        paintChoice: choice,
        image: image,
        color: color,
        strokeWidth: strokeWidth));
    notifyListeners();
  }

  void clear() {
    pathHistory.clear();
    notifyListeners();
  }
}
