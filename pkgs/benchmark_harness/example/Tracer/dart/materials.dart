// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

abstract class Materials {
  final gloss;             // [0...infinity] 0 = matt
  final transparency;      // 0=opaque
  final reflection;        // [0...infinity] 0 = no reflection
  var refraction = 0.50;
  var hasTexture = false;

  Materials(this.reflection, this.transparency, this.gloss);

  Color getColor(num u, num v);

  wrapUp(t) {
    t = t % 2.0;
    if(t < -1) t += 2.0;
    if(t >= 1) t -= 2.0;
    return t;
  }
}


class Chessboard extends Materials {
  var colorEven, colorOdd, density;

  Chessboard(this.colorEven,
             this.colorOdd,
             reflection,
             transparency,
             gloss,
             this.density) : super(reflection, transparency, gloss) {
    this.hasTexture = true;
  }

  Color getColor(num u, num v) {
    var t = this.wrapUp(u * this.density) * this.wrapUp(v * this.density);

    if (t < 0.0) {
      return this.colorEven;
    } else {
      return this.colorOdd;
    }
  }
}


class Solid extends Materials {
  var color;

  Solid(this.color, reflection, refraction, transparency, gloss)
      : super(reflection, transparency, gloss) {
    this.hasTexture = false;
    this.refraction = refraction;
  }

  Color getColor(num u, num v) {
    return this.color;
  }
}
