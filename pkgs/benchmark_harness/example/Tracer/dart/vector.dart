// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

class Vector {
  double x, y, z;
  Vector(this.x, this.y, this.z);

  void copy(Vector v) {
    x = v.x;
    y = v.y;
    z = v.z;
  }

  Vector normalize() {
    var m = magnitude();
    return Vector(x / m, y / m, z / m);
  }

  double magnitude() {
    return sqrt((x * x) + (y * y) + (z * z));
  }

  Vector cross(Vector w) {
    return Vector(-z * w.y + y * w.z, z * w.x - x * w.z, -y * w.x + x * w.y);
  }

  double dot(Vector w) {
    return x * w.x + y * w.y + z * w.z;
  }

  Vector operator +(Vector w) {
    return Vector(w.x + x, w.y + y, w.z + z);
  }

  Vector operator -(Vector w) {
    return Vector(x - w.x, y - w.y, z - w.z);
  }

  Vector operator *(Vector w) {
    return Vector(x * w.x, y * w.y, z * w.z);
  }

  Vector multiplyScalar(double w) {
    return Vector(x * w, y * w, z * w);
  }

  @override
  String toString() {
    return 'Vector [$x, $y ,$z ]';
  }
}
