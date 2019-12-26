library ray_trace;

import 'dart:html';
import 'dart:math';

part 'color.dart';
part 'engine.dart';
part 'materials.dart';
part 'scene.dart';
part 'shapes.dart';
part 'vector.dart';
part 'renderscene.dart';

// used to check if raytrace was correct (used by benchmarks)
int checkNumber;

void main() {
  var button = querySelector('#render');
  var canvas = querySelector('#canvas') as CanvasElement;
  var time = querySelector('#time');
  button.onClick.listen((e) {
    canvas.width =
        int.parse((querySelector('#imageWidth') as InputElement).value);
    canvas.height =
        int.parse((querySelector('#imageHeight') as InputElement).value);
    var sw = Stopwatch()..start();
    renderScene(e);
    sw.stop();
    time.text = sw.elapsedMilliseconds.toString();
  });
}
