// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.nz.co/raytracer/
//
// It has been modified slightly by Google to work as a standalone
// benchmark, but the all the computational code remains
// untouched. This file also contains a copy of parts of the Prototype
// JavaScript framework which is used by the ray tracer.

"use strict";
var scope = this;

// Variable used to hold a number that can be used to verify that
// the scene was ray traced correctly.
var checkNumber;

// ------------------------------------------------------------------------
// ------------------------------------------------------------------------

// The following is a copy of parts of the Prototype JavaScript library:

// Prototype JavaScript framework, version 1.5.0
// (c) 2005-2007 Sam Stephenson
//
// Prototype is freely distributable under the terms of an MIT-style license.
// For details, see the Prototype web site: http://prototype.conio.net/

Object.extend = function(destination, source) {
  Object.keys(source).forEach(function(p) {
    destination[p] = source[p];
  })
  return destination;
};


// ------------------------------------------------------------------------
// ------------------------------------------------------------------------

// The rest of this file is the actual ray tracer written by Adam
// Burmister. It's a concatenation of the following files:
//
//   flog/color.js
//   flog/light.js
//   flog/vector.js
//   flog/ray.js
//   flog/scene.js
//   flog/material/basematerial.js
//   flog/material/solid.js
//   flog/material/chessboard.js
//   flog/shape/baseshape.js
//   flog/shape/sphere.js
//   flog/shape/plane.js
//   flog/intersectioninfo.js
//   flog/camera.js
//   flog/background.js
//   flog/engine.js

/* Fake a Flog.* namespace */
if(typeof(scope.Flog) == 'undefined') {
  var Flog = scope.Flog = { RayTracer: { Shape: {}, Material: {} } };
}

var Color =
Flog.RayTracer.Color = function(r, g, b) {
  this.red = r;
  this.green = g;
  this.blue = b;
};
Color.prototype = {
  add: function(c){
    return new Color(
      this.red   + c.red,
      this.green + c.green,
      this.blue  + c.blue
    );
  },

  addScalar: function(s){
    var result = new Color(
      this.red   + s,
      this.green + s,
      this.blue  + s);
    result.limit();
    return result;
  },

  subtract: function(c1, c2){
    return new Color(
      c1.red   - c2.red,
      c1.green - c2.green,
      c1.blue  - c2.blue
    );
  },

  multiply: function(c) {
    return new Color(
      this.red   * c.red,
      this.green * c.green,
      this.blue  * c.blue
    );
  },

  multiplyScalar: function(f) {
    return new Color(
      this.red   * f,
      this.green * f,
      this.blue  * f
    );
  },

  divideFactor: function(c1, f) {
    return new Color(
      c1.red   / f,
      c1.green / f,
      c1.blue  / f
    );
  },

  limit: function() {
    this.red = (this.red > 0.0) ?
                  ( (this.red > 1.0) ? 1.0 : this.red ) : 0.0;
    this.green = (this.green > 0.0) ?
                  ( (this.green > 1.0) ? 1.0 : this.green ) : 0.0;
    this.blue = (this.blue > 0.0) ?
                  ( (this.blue > 1.0) ? 1.0 : this.blue ) : 0.0;
  },

  distance : function(color) {
    return  Math.abs(this.red   - color.red) +
            Math.abs(this.green - color.green) +
            Math.abs(this.blue  - color.blue);
  },

  blend: function(c, w){
    return this.multiplyScalar(1-w).add(c.multiplyScalar(w));
  },

  brightness : function() {
    var r = Math.floor(this.red*255);
    var g = Math.floor(this.green*255);
    var b = Math.floor(this.blue*255);
    return (r * 77 + g * 150 + b * 29) >> 8;
  },

  toString : function () {
    var r = Math.floor(this.red*255);
    var g = Math.floor(this.green*255);
    var b = Math.floor(this.blue*255);
    return "rgb("+ r +","+ g +","+ b +")";
  }
};

var Light =
Flog.RayTracer.Light = function (pos, color, intensity) {
  this.position = pos;
  this.color = color;
  this.intensity = (intensity ? intensity : 10.0);
};
Light.prototype = {
  toString : function () {
    var pos = this.position;
    return 'Light [' + pos.x + ','
                     + pos.y + ','
                     + pos.z + ']';
  }
};

var Vector =
Flog.RayTracer.Vector = function (x, y, z) {
  this.x = x;
  this.y = y;
  this.z = z;
};
Vector.prototype = {
  copy: function(v){
    this.x = v.x;
    this.y = v.y;
    this.z = v.z;
  },

  normalize : function() {
    var m = this.magnitude();
    return new Vector(
      this.x / m,
      this.y / m,
      this.z / m
    );
  },

  magnitude : function() {
    return Math.sqrt(this.x*this.x + this.y*this.y + this.z*this.z);
  },

  cross : function(w) {
    return new Vector(
      -this.z * w.y + this.y * w.z,
       this.z * w.x - this.x * w.z,
      -this.y * w.x + this.x * w.y);
  },

  dot : function(w) {
    return this.x * w.x + this.y * w.y + this.z * w.z;
  },

  add: function(w) {
    return new Vector(w.x + this.x,
                      w.y + this.y,
                      w.z + this.z);
  },

  subtract: function(w) {
    return new Vector(this.x - w.x,
                      this.y - w.y,
                      this.z - w.z);
  },

  multiplyScalar: function(w) {
    return new Vector(this.x * w,
                      this.y * w,
                      this.z * w);
  },

  toString : function () {
    return 'Vector [' + this.x + ',' + this.y + ',' + this.z + ']';
  }
};

var Ray =
Flog.RayTracer.Ray = function(pos, dir) {
  this.position = pos;
  this.direction = dir;
};
Ray.prototype = {
  toString : function () {
    return 'Ray [' + this.position + ',' + this.direction + ']';
  }
};

var Scene =
Flog.RayTracer.Scene = function() {
  this.camera = new Camera(
    new Vector(0,0,-5),
    new Vector(0,0,1),
    new Vector(0,1,0)
  );
  this.shapes = [];
  this.lights = [];
  this.background = new Background(new Color(0,0,0.5), 0.2);
};

var BaseMaterial =
Flog.RayTracer.Material.BaseMaterial = function(reflection,
                                                transparency,
                                                glass) {
  this.gloss = glass;
  this.transparency = transparency;
  this.reflection = reflection;
  this.refraction = 0.50;
  this.hasTexture = false;
};
BaseMaterial.prototype = {
  wrapUp: function(t){
    t = t % 2.0;
    if(t < -1) t += 2.0;
    if(t >= 1) t -= 2.0;
    return t;
  },

  toString : function () {
    return 'Material [gloss=' + this.gloss + ', transparency=' + this.transparency + ', hasTexture=' + this.hasTexture +']';
  }
}

var Solid =
Flog.RayTracer.Material.Solid = function(color, reflection, refraction, transparency, gloss) {
  this.color = color;
  this.reflection = reflection;
  this.transparency = transparency;
  this.gloss = gloss;
  this.hasTexture = false;
};
Solid.prototype = Object.create(BaseMaterial.prototype, {
  getColor: {
    value: function() { return this.color; },
  },
  toString: {
    value: function() {
      return 'SolidMaterial [gloss=' + this.gloss +
                          ', transparency=' + this.transparency +
                          ', hasTexture=' + this.hasTexture +']';
    }
  }
});

var Chessboard =
Flog.RayTracer.Material.Chessboard = function(
    colorEven,
    colorOdd,
    reflection,
    transparency,
    gloss,
    density) {
  this.colorEven = colorEven;
  this.colorOdd = colorOdd;
  this.reflection = reflection;
  this.transparency = transparency;
  this.gloss = gloss;
  this.density = density;
  this.hasTexture = true;
};

Chessboard.prototype = Object.create(BaseMaterial.prototype, {
  getColor: {
    value: function(u, v){
      var t = this.wrapUp(u * this.density) * this.wrapUp(v * this.density);
      if(t < 0.0) {
        return this.colorEven;
      } else {
        return this.colorOdd;
      }
    }
  },
  toString: {
    value: function(){
      return 'ChessMaterial [gloss=' + this.gloss +
                          ', transparency=' + this.transparency +
                          ', hasTexture=' + this.hasTexture +']';
    }
  }
});


var Sphere =
Flog.RayTracer.Shape.Sphere = function(pos, radius, material) {
  this.radius = radius;
  this.position = pos;
  this.material = material;
};
Sphere.prototype = {

  _foundIntersection: function(B, D, info, ray) {
    info.isHit = true;
    info.distance = (-B) - Math.sqrt(D);
    info.position =
      ray.position.add(ray.direction.multiplyScalar(info.distance));
    info.normal = info.position.subtract(this.position).normalize();
    info.color = this.material.getColor(0,0);
  },

  intersect: function(ray){
    var info = new IntersectionInfo();
    info.shape = this;
    info.isHit = false;

    var dst = ray.position.subtract(this.position);
    var B = dst.dot(ray.direction);
    var C = dst.dot(dst) - (this.radius * this.radius);
    var D = (B * B) - C;

    if(D > 0) { // intersection!
      this._foundIntersection(B, D, info, ray);
    }
    return info;
  },

  toString : function () {
    return 'Sphere [position=' + this.position +
                 ', radius=' + this.radius + ']';
  }
}

var Plane =
Plane = function(pos, d, material) {
  this.position = pos;
  this.d = d;
  this.material = material;
};
Plane.prototype = {
  _hasTexture: function() {

  },
  intersect: function(ray){
    var info = new IntersectionInfo();
    var pos = this.position;
    var mat = this.material;

    var Vd = pos.dot(ray.direction);
    if(Vd == 0) return info; // no intersection

    var t = -(pos.dot(ray.position) + this.d) / Vd;
    if(t <= 0) { return info; }

    info.shape = this;
    info.isHit = true;
    info.position = ray.position.add(ray.direction.multiplyScalar(t));
    info.normal = pos;
    info.distance = t;

    if(mat.hasTexture){
      var vU = new Vector(pos.y, pos.z, -pos.x);
      var vV = vU.cross(pos);
      var u = info.position.dot(vU);
      var v = info.position.dot(vV);
      info.color = mat.getColor(u,v);
    } else {
      info.color = mat.getColor(0,0);
    }
    return info;
  },

  toString : function () {
    return 'Plane [' + this.position + ', d=' + this.d + ']';
  }
}

var IntersectionInfo =
Flog.RayTracer.IntersectionInfo = function(shape) {
  this.color = new Color(0,0,0);
  this.isHit = false;
  this.hitCount = 0;
  this.shape = null;
  this.position = null;
  this.normal = null;
  this.color = null;
  this.distance = null;
};
IntersectionInfo.prototype = {
  toString : function () {
    return 'Intersection [' + this.position + ']';
  }
}

var Camera =
Flog.RayTracer.Camera = function(pos, lookAt, up) {
  this.position = pos;
  this.lookAt = lookAt;
  this.up = up;
  this.equator = lookAt.normalize().cross(this.up);
  this.screen = this.position.add(this.lookAt);
};
Camera.prototype = {
  getRay: function(vx, vy){
    var pos = this.screen.subtract(
      this.equator.multiplyScalar(vx).subtract(this.up.multiplyScalar(vy))
    );
    pos.y = pos.y * -1;
    var dir = pos.subtract(this.position);
    return new Ray(pos, dir.normalize());
  },

  toString : function () { return 'Ray []'; }
}

var Background =
Flog.RayTracer.Background = function(color, ambience) {
  this.color = color;
  this.ambience = ambience;
};

var Engine =
Flog.RayTracer.Engine = function(options){
  this.options = Object.extend({
    canvasHeight: 100,
    canvasWidth: 100,
    pixelWidth: 2,
    pixelHeight: 2,
    renderDiffuse: false,
    renderShadows: false,
    renderHighlights: false,
    renderReflections: false,
    rayDepth: 2
  }, options || {});

  this.options.canvasHeight /= this.options.pixelHeight;
  this.options.canvasWidth /= this.options.pixelWidth;
  this.canvas = null;
  /* TODO: dynamically include other scripts */
};
Engine.prototype = {
  setPixel: function(x, y, color){
    var pxW, pxH;
    pxW = this.options.pixelWidth;
    pxH = this.options.pixelHeight;

    if (this.canvas) {
      this.canvas.fillStyle = color.toString();
      this.canvas.fillRect (x * pxW, y * pxH, pxW, pxH);
    } else {
      if (x ===  y) {
        checkNumber += color.brightness();
      }
      // print(x * pxW, y * pxH, pxW, pxH);
    }
  },

  renderScene: function(scene, canvas){
    checkNumber = 0;
    /* Get canvas */
    if (canvas) {
      this.canvas = canvas.getContext("2d");
    } else {
      this.canvas = null;
    }

    var canvasHeight = this.options.canvasHeight;
    var canvasWidth = this.options.canvasWidth;

    for(var y=0; y < canvasHeight; y++){
      for(var x=0; x < canvasWidth; x++){
          var yp = y * 1.0 / canvasHeight * 2 - 1;

    		var xp = x * 1.0 / canvasWidth * 2 - 1;
    		var ray = scene.camera.getRay(xp, yp);
    		var color = this.getPixelColor(ray, scene);
      	this.setPixel(x, y, color);
      }
    }
    if (canvas == null && checkNumber !== 2321) {
      throw new Error("Scene rendered incorrectly");
    }
  },

  getPixelColor: function(ray, scene){
    var info = this.testIntersection(ray, scene, null);
    if(info.isHit){
      return this.rayTrace(info, ray, scene, 0);
    }
    return scene.background.color;
  },

  // FIXME(slightlyoff): HOT!
  testIntersection: function(ray, scene, exclude){
    var hits = 0;
    var best = new IntersectionInfo();
    best.distance = 2000;
    var info;
    var distance = 0|0;

    var shapesLength = scene.shapes.length;
    for(var i = 0; i < shapesLength; i++){
      if(scene.shapes[i] !== exclude){
        info = scene.shapes[i].intersect(ray);
        distance = info.distance;
        if(info.isHit && distance >= 0 && distance < best.distance) {
          best = info;
          hits++;
        }
      }
    }
    best.hitCount = hits;
    return best;
  },

  getReflectionRay: function(P,N,V){
    var c1 = -N.dot(V);
    var R1 = N.multiplyScalar(2*c1).add(V);
    return new Ray(P, R1);
  },

  rayTrace: function(info, ray, scene, depth) {
    // Calc ambient
    var color = info.color.multiplyScalar(scene.background.ambience);
    var oldColor = color;
    var shininess = Math.pow(10, info.shape.material.gloss + 1);

    for(var i=0; i<scene.lights.length; i++) {
      var light = scene.lights[i];

      // Calc diffuse lighting
      var v = light.position.subtract(info.position).normalize();

      if(this.options.renderDiffuse){
        var L = v.dot(info.normal);
        if(L > 0){
          color = color.add(
                    info.color.multiply(
                      light.color.multiplyScalar(L)
                    )
                  );
        }
      }

      // The greater the depth the more accurate the colours, but
      // this is exponentially (!) expensive
      if(depth <= this.options.rayDepth){
        // calculate reflection ray
        if(this.options.renderReflections &&
           info.shape.material.reflection > 0) {

          var reflectionRay = this.getReflectionRay(
                info.position, info.normal, ray.direction);
          var refl = this.testIntersection(reflectionRay, scene, info.shape);

          if (refl.isHit && refl.distance > 0){
            refl.color = this.rayTrace(refl, reflectionRay, scene, depth + 1);
          } else {
            refl.color = scene.background.color;
          }

          color = color.blend(
            refl.color, info.shape.material.reflection
          );
        }
          // Refraction
          /* TODO */
      }

      /* Render shadows and highlights */
      var shadowInfo = new IntersectionInfo();

      if(this.options.renderShadows) {
        var shadowRay = new Ray(info.position, v);

        shadowInfo = this.testIntersection(shadowRay, scene,
                                           info.shape);
        if(shadowInfo.isHit && shadowInfo.shape != info.shape
            /*&& shadowInfo.shape.type != 'PLANE'*/) {
          var vA = color.multiplyScalar(0.5);
          var dB = (0.5 * Math.pow(shadowInfo.shape.material.transparency, 0.5));
          color = vA.addScalar(dB);
        }
      }

      // Phong specular highlights
      if(this.options.renderHighlights && !shadowInfo.isHit && info.shape.material.gloss > 0) {
        var Lv = info.shape.position.subtract(light.position)
                  .normalize();
        var E = scene.camera.position.subtract(info.shape.position)
                  .normalize();
        var H = E.subtract(Lv).normalize();
        var glossWeight =
              Math.pow(Math.max(info.normal.dot(H), 0), shininess);
        color = light.color.multiplyScalar(glossWeight).add(color);
      }
    }
    color.limit();
    return color;
  }
};

// 'event' null means that we are benchmarking
var renderScene =
scope.renderScene = function(event){
  var scene = new Scene();

  scene.camera = new Camera(
                   new Vector(0, 0, -15),
                   new Vector(-0.2, 0, 5),
                   new Vector(0, 1, 0)
                 );

  scene.background = new Background(new Color(0.5, 0.5, 0.5), 0.4 );

  var sphere = new Sphere(
    new Vector(-1.5, 1.5, 2),
    1.5,
    new Solid(
      new Color(0,0.5,0.5),
      0.3,
      0.0,
      0.0,
      2.0
    )
  );

  var sphere1 = new Sphere(
    new Vector(1, 0.25, 1),
    0.5,
    new Solid(
      new Color(0.9,0.9,0.9),
      0.1,
      0.0,
      0.0,
      1.5
    )
  );

  var plane = new Plane(
    new Vector(0.1, 0.9, -0.5).normalize(),
    1.2,
    new Chessboard(
      new Color(1,1,1),
      new Color(0,0,0),
      0.2,
      0.0,
      1.0,
      0.7
    )
  );

  scene.shapes.push(plane);
  scene.shapes.push(sphere);
  scene.shapes.push(sphere1);

  var light = new Light(
    new Vector(5, 10, -1),
    new Color(0.8, 0.8, 0.8)
  );

  var light1 = new Light(
    new Vector(-3, 5, -15),
    new Color(0.8, 0.8, 0.8),
    100
  );

  scene.lights.push(light);
  scene.lights.push(light1);

  var imageWidth, imageHeight, pixelSize;
  var renderDiffuse, renderShadows, renderHighlights, renderReflections;
  var canvas;

  if (typeof(event) == 'undefined' || event == null) {
	  imageWidth = 100;
	  imageHeight = 100;
	  pixelSize = "5,5".split(',');
	  renderDiffuse = true;
	  renderShadows = true;
	  renderHighlights = true;
	  renderReflections = true;
	  canvas = null;
	} else {
	  imageWidth = parseInt(document.getElementById('imageWidth').value);
	  imageHeight = parseInt(document.getElementById('imageHeight').value);
	  pixelSize = document.getElementById('pixelSize').value.split(',');
	  renderDiffuse = document.getElementById('renderDiffuse').checked;
	  renderShadows = document.getElementById('renderShadows').checked;
	  renderHighlights = document.getElementById('renderHighlights').checked;
	  renderReflections = document.getElementById('renderReflections').checked;
	  canvas = document.getElementById("canvas");
	}

  var rayDepth = 2;//$F('rayDepth');

  var raytracer = new Engine({
    canvasWidth: imageWidth,
    canvasHeight: imageHeight,
    pixelWidth: parseInt(pixelSize[0]),
    pixelHeight: parseInt(pixelSize[1]),
    "renderDiffuse": renderDiffuse,
    "renderHighlights": renderHighlights,
    "renderShadows": renderShadows,
    "renderReflections": renderReflections,
    "rayDepth": rayDepth
  });

  raytracer.renderScene(scene, canvas, 0);
};
