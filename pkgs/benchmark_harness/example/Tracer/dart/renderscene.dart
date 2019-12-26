// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.co.nz/raytracer/
//
// Ported from the v8 benchmark suite by Google 2012.
part of ray_trace;

class Light {
  final Vector position;
  final Color color;
  final double intensity;

  Light(this.position, this.color, [this.intensity = 10.0]);
}

// 'event' null means that we are benchmarking
void renderScene(event) {
  var scene = Scene();
  scene.camera = Camera(
      Vector(0.0, 0.0, -15.0), Vector(-0.2, 0.0, 5.0), Vector(0.0, 1.0, 0.0));
  scene.background = Background(Color(0.5, 0.5, 0.5), 0.4);

  var sphere = Sphere(Vector(-1.5, 1.5, 2.0), 1.5,
      Solid(Color(0.0, 0.5, 0.5), 0.3, 0.0, 0.0, 2.0));

  var sphere1 = Sphere(Vector(1.0, 0.25, 1.0), 0.5,
      Solid(Color(0.9, 0.9, 0.9), 0.1, 0.0, 0.0, 1.5));

  var plane = Plane(
      Vector(0.1, 0.9, -0.5).normalize(),
      1.2,
      Chessboard(
          Color(1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0), 0.2, 0.0, 1.0, 0.7));

  scene.shapes.add(plane);
  scene.shapes.add(sphere);
  scene.shapes.add(sphere1);

  var light = Light(Vector(5.0, 10.0, -1.0), Color(0.8, 0.8, 0.8));

  var light1 = Light(Vector(-3.0, 5.0, -15.0), Color(0.8, 0.8, 0.8), 100.0);

  scene.lights.add(light);
  scene.lights.add(light1);

  int imageWidth, imageHeight, pixelSize;
  bool renderDiffuse, renderShadows, renderHighlights, renderReflections;
  CanvasElement canvas;
  if (event == null) {
    imageWidth = 100;
    imageHeight = 100;
    pixelSize = 5;
    renderDiffuse = true;
    renderShadows = true;
    renderHighlights = true;
    renderReflections = true;
    canvas = null;
  } else {
    imageWidth =
        int.parse((querySelector('#imageWidth') as InputElement).value);
    imageHeight =
        int.parse((querySelector('#imageHeight') as InputElement).value);
    pixelSize = int.parse(
        (querySelector('#pixelSize') as InputElement).value.split(',')[0]);
    renderDiffuse =
        (querySelector('#renderDiffuse') as CheckboxInputElement).checked;
    renderShadows =
        (querySelector('#renderShadows') as CheckboxInputElement).checked;
    renderHighlights =
        (querySelector('#renderHighlights') as CheckboxInputElement).checked;
    renderReflections =
        (querySelector('#renderReflections') as CheckboxInputElement).checked;
    canvas = querySelector('#canvas') as CanvasElement;
  }
  var rayDepth = 2;

  var raytracer = Engine(
      canvasWidth: imageWidth,
      canvasHeight: imageHeight,
      pixelWidth: pixelSize,
      pixelHeight: pixelSize,
      renderDiffuse: renderDiffuse,
      renderShadows: renderShadows,
      renderReflections: renderReflections,
      renderHighlights: renderHighlights,
      rayDepth: rayDepth);

  raytracer.renderScene(scene, canvas);
}
