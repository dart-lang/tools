// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

class Ray {
  final Vector position;
  final Vector direction;

  Ray(this.position, this.direction);

  @override
  String toString() {
    return 'Ray [$position, $direction]';
  }
}

class Camera {
  final Vector position;
  final Vector lookAt;
  final Vector up;
  Vector equator, screen;

  Camera(this.position, this.lookAt, this.up) {
    equator = lookAt.normalize().cross(up);
    screen = position + lookAt;
  }

  Ray getRay(double vx, double vy) {
    var pos = screen - (equator.multiplyScalar(vx) - up.multiplyScalar(vy));
    pos.y = pos.y * -1.0;
    var dir = pos - position;
    var ray = Ray(pos, dir.normalize());
    return ray;
  }

  @override
  String toString() {
    return 'Camera []';
  }
}

class Background {
  final Color color;
  final double ambience;

  Background(this.color, this.ambience);
}

class Scene {
  Camera camera;
  List<BaseShape> shapes;
  List<Light> lights;
  Background background;

  Scene() {
    camera = Camera(
        Vector(0.0, 0.0, -0.5), Vector(0.0, 0.0, 1.0), Vector(0.0, 1.0, 0.0));
    shapes = [];
    lights = [];
    background = Background(Color(0.0, 0.0, 0.5), 0.2);
  }
}
