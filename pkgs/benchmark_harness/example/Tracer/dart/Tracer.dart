// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.

library ray_trace;

import 'dart:html';
import 'dart:math';

import 'package:benchmark_harness/benchmark_harness.dart';

part 'color.dart';
part 'engine.dart';
part 'materials.dart';
part 'scene.dart';
part 'shapes.dart';
part 'vector.dart';
part 'renderscene.dart';

// Variable used to hold a number that can be used to verify that
// the scene was ray traced correctly.
int checkNumber;

class TracerBenchmark extends BenchmarkBase {
  const TracerBenchmark() : super('Tracer');

  @override
  void warmup() {
    renderScene(null);
  }

  @override
  void exercise() {
    renderScene(null);
  }
}

void main() {
  const TracerBenchmark().report();
}
