// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

class Color {
  double red;
  double green;
  double blue;

  Color(this.red, this.green, this.blue);

  void limit() {
    red = (red > 0.0) ? ((red > 1.0) ? 1.0 : red) : 0.0;
    green = (green > 0.0) ? ((green > 1.0) ? 1.0 : green) : 0.0;
    blue = (blue > 0.0) ? ((blue > 1.0) ? 1.0 : blue) : 0.0;
  }

  Color operator +(Color c2) {
    return Color(red + c2.red, green + c2.green, blue + c2.blue);
  }

  Color addScalar(double s) {
    var result = Color(red + s, green + s, blue + s);
    result.limit();
    return result;
  }

  Color operator *(Color c2) {
    var result = Color(red * c2.red, green * c2.green, blue * c2.blue);
    return result;
  }

  Color multiplyScalar(double f) {
    var result = Color(red * f, green * f, blue * f);
    return result;
  }

  Color blend(Color c2, double w) {
    var result = multiplyScalar(1.0 - w) + c2.multiplyScalar(w);
    return result;
  }

  int brightness() {
    var r = (red * 255).toInt();
    var g = (green * 255).toInt();
    var b = (blue * 255).toInt();
    return (r * 77 + g * 150 + b * 29) >> 8;
  }

  @override
  String toString() {
    var r = (red * 255).toInt();
    var g = (green * 255).toInt();
    var b = (blue * 255).toInt();

    return 'rgb($r,$g,$b)';
  }
}
