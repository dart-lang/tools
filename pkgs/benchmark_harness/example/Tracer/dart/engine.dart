// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

class IntersectionInfo {
  bool isHit = false;
  int hitCount = 0;
  BaseShape shape;
  Vector position;
  Vector normal;
  Color color;
  double distance;

  IntersectionInfo() {
    color = Color(0.0, 0.0, 0.0);
  }

  @override
  String toString() => 'Intersection [$position]';
}

class Engine {
  int canvasWidth;
  int canvasHeight;
  int pixelWidth, pixelHeight;
  bool renderDiffuse, renderShadows, renderHighlights, renderReflections;
  int rayDepth;
  CanvasRenderingContext2D canvas;

  Engine(
      {canvasWidth = 100,
      this.canvasHeight = 100,
      this.pixelWidth = 2,
      this.pixelHeight = 2,
      this.renderDiffuse = false,
      this.renderShadows = false,
      this.renderHighlights = false,
      this.renderReflections = false,
      this.rayDepth = 2}) {
    canvasHeight = canvasHeight ~/ pixelHeight;
    canvasWidth = canvasWidth ~/ pixelWidth;
  }

  void setPixel(int x, int y, Color color) {
    int pxW, pxH;
    pxW = pixelWidth;
    pxH = pixelHeight;

    if (canvas != null) {
      canvas.fillStyle = color.toString();
      canvas.fillRect(x * pxW, y * pxH, pxW, pxH);
    } else {
      if (x == y) {
        checkNumber += color.brightness();
      }
    }
  }

  // 'canvas' can be null if raytracer runs as benchmark
  void renderScene(Scene scene, CanvasElement canvas) {
    checkNumber = 0;
    /* Get canvas */
    this.canvas = canvas?.context2D;

    var canvasHeight = this.canvasHeight;
    var canvasWidth = this.canvasWidth;

    for (var y = 0; y < canvasHeight; y++) {
      for (var x = 0; x < canvasWidth; x++) {
        var yp = y * 1.0 / canvasHeight * 2 - 1;
        var xp = x * 1.0 / canvasWidth * 2 - 1;

        var ray = scene.camera.getRay(xp, yp);
        setPixel(x, y, getPixelColor(ray, scene));
      }
    }
    if ((canvas == null) && (checkNumber != 2321)) {
      // Used for benchmarking.
      throw 'Scene rendered incorrectly';
    }
  }

  Color getPixelColor(Ray ray, Scene scene) {
    var info = testIntersection(ray, scene, null);
    if (info.isHit) {
      var color = rayTrace(info, ray, scene, 0);
      return color;
    }
    return scene.background.color;
  }

  IntersectionInfo testIntersection(Ray ray, Scene scene, BaseShape exclude) {
    var hits = 0;
    var best = IntersectionInfo();
    best.distance = 2000;

    for (var i = 0; i < scene.shapes.length; i++) {
      var shape = scene.shapes[i];

      if (shape != exclude) {
        var info = shape.intersect(ray);
        if (info.isHit &&
            (info.distance >= 0) &&
            (info.distance < best.distance)) {
          best = info;
          hits++;
        }
      }
    }
    best.hitCount = hits;
    return best;
  }

  Ray getReflectionRay(Vector P, Vector N, Vector V) {
    var c1 = -N.dot(V);
    var R1 = N.multiplyScalar(2 * c1) + V;
    return Ray(P, R1);
  }

  Color rayTrace(IntersectionInfo info, Ray ray, Scene scene, int depth) {
    // Calc ambient
    var color = info.color.multiplyScalar(scene.background.ambience);
    var shininess = pow(10, info.shape.material.gloss + 1);

    for (var i = 0; i < scene.lights.length; i++) {
      var light = scene.lights[i];

      // Calc diffuse lighting
      var v = (light.position - info.position).normalize();

      if (renderDiffuse) {
        var L = v.dot(info.normal);
        if (L > 0.0) {
          color = color + info.color * light.color.multiplyScalar(L);
        }
      }

      // The greater the depth the more accurate the colours, but
      // this is exponentially (!) expensive
      if (depth <= rayDepth) {
        // calculate reflection ray
        if (renderReflections && info.shape.material.reflection > 0) {
          var reflectionRay =
              getReflectionRay(info.position, info.normal, ray.direction);
          var refl = testIntersection(reflectionRay, scene, info.shape);

          if (refl.isHit && refl.distance > 0) {
            refl.color = rayTrace(refl, reflectionRay, scene, depth + 1);
          } else {
            refl.color = scene.background.color;
          }

          color = color.blend(refl.color, info.shape.material.reflection);
        }
        // Refraction
        /* TODO */
      }
      /* Render shadows and highlights */

      var shadowInfo = IntersectionInfo();

      if (renderShadows) {
        var shadowRay = Ray(info.position, v);

        shadowInfo = testIntersection(shadowRay, scene, info.shape);
        if (shadowInfo.isHit && shadowInfo.shape != info.shape
            /*&& shadowInfo.shape.type != 'PLANE'*/) {
          var vA = color.multiplyScalar(0.5);
          var dB = 0.5 * pow(shadowInfo.shape.material.transparency, 0.5);
          color = vA.addScalar(dB);
        }
      }
      // Phong specular highlights
      if (renderHighlights &&
          !shadowInfo.isHit &&
          (info.shape.material.gloss > 0)) {
        var Lv = (info.shape.position - light.position).normalize();

        var E = (scene.camera.position - info.shape.position).normalize();

        var H = (E - Lv).normalize();

        var glossWeight = pow(max(info.normal.dot(H), 0), shininess).toDouble();
        color = light.color.multiplyScalar(glossWeight) + color;
      }
    }
    color.limit();
    return color;
  }

  @override
  String toString() {
    return 'Engine [canvasWidth: $canvasWidth, canvasHeight: $canvasHeight]';
  }
}
