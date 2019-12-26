// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

abstract class Materials {
  final double gloss; // [0...infinity] 0 = matt
  final double transparency; // 0=opaque
  final double reflection; // [0...infinity] 0 = no reflection
  var refraction = 0.50;
  var hasTexture = false;

  Materials(this.reflection, this.transparency, this.gloss);

  Color getColor(double u, double v);

  double wrapUp(double t) {
    t = t % 2.0;
    if (t < -1) t += 2.0;
    if (t >= 1) t -= 2.0;
    return t;
  }
}

class Chessboard extends Materials {
  Color colorEven, colorOdd;
  double density;

  Chessboard(this.colorEven, this.colorOdd, double reflection,
      double transparency, double gloss, this.density)
      : super(reflection, transparency, gloss) {
    hasTexture = true;
  }

  @override
  Color getColor(double u, double v) {
    var t = wrapUp(u * density) * wrapUp(v * density);

    if (t < 0.0) {
      return colorEven;
    } else {
      return colorOdd;
    }
  }
}

class Solid extends Materials {
  Color color;

  Solid(this.color, double reflection, double refraction, double transparency,
      double gloss)
      : super(reflection, transparency, gloss) {
    hasTexture = false;
    this.refraction = refraction;
  }

  @override
  Color getColor(num u, num v) => color;
}
