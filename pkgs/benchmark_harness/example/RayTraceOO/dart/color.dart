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
    this.red = (this.red > 0.0) ? ((this.red > 1.0) ? 1.0 : this.red) : 0.0;
    this.green = (this.green > 0.0) ?
        ((this.green > 1.0) ? 1.0 : this.green) : 0.0;
    this.blue = (this.blue > 0.0) ?
        ((this.blue > 1.0) ? 1.0 : this.blue) : 0.0;
  }

  Color operator +(Color c2) {
    return new Color(red + c2.red, green + c2.green, blue + c2.blue);
  }

  Color addScalar(double s){
    var result = new Color(red + s, green + s, blue + s);
    result.limit();
    return result;
  }

  Color operator *(Color c2) {
    var result = new Color(red * c2.red, green * c2.green, blue * c2.blue);
    return result;
  }

  Color multiplyScalar(double f) {
    var result = new Color(red * f, green * f, blue * f);
    return result;
  }

  Color blend(Color c2, double w) {
    var result = this.multiplyScalar(1.0 - w) + c2.multiplyScalar(w);
    return result;
  }

  int brightness() {
    var r = (this.red * 255).toInt();
    var g = (this.green * 255).toInt();
    var b = (this.blue * 255).toInt();
    return (r * 77 + g * 150 + b * 29) >> 8;
  }

  String toString() {
    var r = (this.red * 255).toInt();
    var g = (this.green * 255).toInt();
    var b = (this.blue * 255).toInt();

    return 'rgb($r,$g,$b)';
  }
}
