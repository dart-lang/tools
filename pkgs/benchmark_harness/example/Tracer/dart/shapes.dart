// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

abstract class BaseShape {
  final Vector position;
  final Materials material;

  BaseShape(this.position, this.material);

  IntersectionInfo intersect(Ray ray);

  @override
  String toString() {
    return 'BaseShape';
  }
}

class Plane extends BaseShape {
  final double d;

  Plane(Vector pos, this.d, Materials material) : super(pos, material);

  @override
  IntersectionInfo intersect(Ray ray) {
    var info = IntersectionInfo();

    var Vd = position.dot(ray.direction);
    if (Vd == 0) return info; // no intersection

    var t = -(position.dot(ray.position) + d) / Vd;
    if (t <= 0) return info;

    info.shape = this;
    info.isHit = true;
    info.position = ray.position + ray.direction.multiplyScalar(t);
    info.normal = position;
    info.distance = t;

    if (material.hasTexture) {
      var vU = Vector(position.y, position.z, -position.x);
      var vV = vU.cross(position);
      var u = info.position.dot(vU);
      var v = info.position.dot(vV);
      info.color = material.getColor(u, v);
    } else {
      info.color = material.getColor(0, 0);
    }

    return info;
  }

  @override
  String toString() {
    return 'Plane [$position, d=$d]';
  }
}

class Sphere extends BaseShape {
  double radius;

  Sphere(Vector pos, this.radius, Materials material) : super(pos, material);

  @override
  IntersectionInfo intersect(Ray ray) {
    var info = IntersectionInfo();
    info.shape = this;

    var dst = ray.position - position;

    var B = dst.dot(ray.direction);
    var C = dst.dot(dst) - (radius * radius);
    var D = (B * B) - C;

    if (D > 0) {
      // intersection!
      info.isHit = true;
      info.distance = (-B) - sqrt(D);
      info.position =
          ray.position + ray.direction.multiplyScalar(info.distance);
      info.normal = (info.position - position).normalize();

      info.color = material.getColor(0, 0);
    } else {
      info.isHit = false;
    }
    return info;
  }

  @override
  String toString() {
    return 'Sphere [position=$position, radius=$radius]';
  }
}
