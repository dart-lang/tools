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
var checkNumber;

main() {
  var button = query('#render');
  var canvas = query('#canvas');
  var time = query('#time');
  button.onClick.listen((e) {
    canvas.width = int.parse(query('#imageWidth').value);
    canvas.height = int.parse(query('#imageHeight').value);
    var sw = new Stopwatch()..start();
    renderScene(e);
    sw.stop();
    time.text = sw.elapsedMilliseconds.toString();
  });
}