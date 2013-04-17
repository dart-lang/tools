// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

class Ray {
  final position;
  final direction;

  Ray(this.position, this.direction);
  String toString() {
    return 'Ray [$position, $direction]';
  }
}


class Camera {
  final position;
  final lookAt;
  final up;
  var equator, screen;

  Camera(this.position, this.lookAt, this.up) {
    this.equator = lookAt.normalize().cross(this.up);
    this.screen = this.position + this.lookAt;
  }

  Ray getRay(double vx, double vy) {
    var pos = screen -
        (this.equator.multiplyScalar(vx) - this.up.multiplyScalar(vy));
    pos.y = pos.y * -1.0;
    var dir = pos - this.position;
    var ray = new Ray(pos, dir.normalize());
    return ray;
  }

  toString() {
    return 'Camera []';
  }
}


class Background {
  final Color color;
  final double ambience;

  Background(this.color, this.ambience);
}


class Scene {
  var camera;
  var shapes;
  var lights;
  var background;
  Scene() {
    camera = new Camera(new Vector(0.0, 0.0, -0.5),
                        new Vector(0.0, 0.0, 1.0),
                        new Vector(0.0, 1.0, 0.0));
    shapes = new List();
    lights = new List();
    background = new Background(new Color(0.0, 0.0, 0.5), 0.2);
  }
}
