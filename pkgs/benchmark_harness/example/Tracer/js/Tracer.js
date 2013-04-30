// The ray tracer code in this file is written by Adam Burmister. It
// is available in its original form from:
//
//   http://labs.flog.nz.co/raytracer/
//
// It has been modified slightly by Google to work as a standalone
// benchmark, but the all the computational code remains
// untouched. This file also contains a copy of parts of the Prototype
// JavaScript framework which is used by the ray tracer.

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


var Class = {
  create: function() {
    return function() {
      this.initialize.apply(this, arguments);
    }
  }
};


Object.extend = function(destination, source) {
  for (var property in source) {
    destination[property] = source[property];
  }
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
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Color = function(r, g, b) {
  this.red = r;
  this.green = g;
  this.blue = b;
};


Flog.RayTracer.Color.prototype = {
    add : function(c1, c2){
      return new Flog.RayTracer.Color(c1.red + c2.red,
				      c1.green + c2.green,
				      c1.blue + c2.blue);
    },

    addScalar: function(c1, s){
      var result = new Flog.RayTracer.Color(
	c1.red + s, c1.green + s, c1.blue + s);
      result.limit();
      return result;
    },

    subtract: function(c1, c2){
      return new Flog.RayTracer.Color(c1.red - c2.red,
				      c1.green - c2.green,
				      c1.blue - c2.blue);
    },

    multiply : function(c1, c2) {
      return new Flog.RayTracer.Color(c1.red * c2.red,
				      c1.green * c2.green,
				      c1.blue * c2.blue);
    },

    multiplyScalar : function(c1, f) {
      return new Flog.RayTracer.Color(c1.red * f,
				      c1.green * f,
				      c1.blue * f);
    },

    divideFactor : function(c1, f) {
      return new Flog.RayTracer.Color(c1.red / f,
				      c1.green / f,
				      c1.blue / f);
    },

    limit: function() {
        this.red = (this.red > 0.0) ? ( (this.red > 1.0) ? 1.0 : this.red ) : 0.0;
        this.green = (this.green > 0.0) ? ( (this.green > 1.0) ? 1.0 : this.green ) : 0.0;
        this.blue = (this.blue > 0.0) ? ( (this.blue > 1.0) ? 1.0 : this.blue ) : 0.0;
    },

    distance : function(color) {
        var d = Math.abs(this.red - color.red) + Math.abs(this.green - color.green) + Math.abs(this.blue - color.blue);
        return d;
    },

    blend: function(c1, c2, w){
        result = Flog.RayTracer.Color.prototype.add(
                    Flog.RayTracer.Color.prototype.multiplyScalar(c1, 1 - w),
                    Flog.RayTracer.Color.prototype.multiplyScalar(c2, w)
                  );
        return result;
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
}
/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Light = function (pos, color, intensity) {
  this.position = pos;
  this.color = color;
  this.intensity = (intensity ? intensity : 10.0);
};

Flog.RayTracer.Light.prototype = {
    toString : function () {
        return 'Light [' + this.position.x + ',' + this.position.y + ',' + this.position.z + ']';
    }
}
/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Vector = function (x, y, z) {
  this.x = x;
  this.y = y;
  this.z = z;
};


Flog.RayTracer.Vector.prototype = {
    copy: function(vector){
        this.x = vector.x;
        this.y = vector.y;
        this.z = vector.z;
    },

    normalize : function() {
        var m = this.magnitude();
        return new Flog.RayTracer.Vector(this.x / m, this.y / m, this.z / m);
    },

    magnitude : function() {
        return Math.sqrt((this.x * this.x) + (this.y * this.y) + (this.z * this.z));
    },

    cross : function(w) {
        return new Flog.RayTracer.Vector(
                                            -this.z * w.y + this.y * w.z,
                                           this.z * w.x - this.x * w.z,
                                          -this.y * w.x + this.x * w.y);
    },

    dot : function(w) {
        return this.x * w.x + this.y * w.y + this.z * w.z;
    },

    add : function(v, w) {
        return new Flog.RayTracer.Vector(w.x + v.x, w.y + v.y, w.z + v.z);
    },

    subtract : function(v, w) {
        if(!w || !v) throw 'Vectors must be defined [' + v + ',' + w + ']';
        return new Flog.RayTracer.Vector(v.x - w.x, v.y - w.y, v.z - w.z);
    },

    multiplyVector : function(v, w) {
        return new Flog.RayTracer.Vector(v.x * w.x, v.y * w.y, v.z * w.z);
    },

    multiplyScalar : function(v, w) {
        return new Flog.RayTracer.Vector(v.x * w, v.y * w, v.z * w);
    },

    toString : function () {
        return 'Vector [' + this.x + ',' + this.y + ',' + this.z + ']';
    }
}
/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Ray = function(pos, dir) {
  this.position = pos;
  this.direction = dir;
};


Flog.RayTracer.Ray.prototype = {
    toString : function () {
        return 'Ray [' + this.position + ',' + this.direction + ']';
    }
}
/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Scene = function() {
  this.camera = new Flog.RayTracer.Camera(
    new Flog.RayTracer.Vector(0,0,-5),
    new Flog.RayTracer.Vector(0,0,1),
    new Flog.RayTracer.Vector(0,1,0)
  );
  this.shapes = new Array();
  this.lights = new Array();
  this.background = new Flog.RayTracer.Background(new Flog.RayTracer.Color(0,0,0.5), 0.2);
};

/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};
if(typeof(Flog.RayTracer.Material) == 'undefined') Flog.RayTracer.Material = {};

Flog.RayTracer.Material.BaseMaterial = function (reflection, transparency, glass) {
  this.gloss = glass;
  this.transparency = transparency;
  this.reflection = reflection;
  this.refraction = 0.50;
  this.hasTexture = false;
};

Flog.RayTracer.Material.BaseMaterial.prototype = {
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

/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Material.Solid = function(color, reflection, refraction, transparency, gloss) {
  this.color = color;
  this.reflection = reflection;
  this.transparency = transparency;
  this.gloss = gloss;
  this.hasTexture = false;
};


Flog.RayTracer.Material.Solid.prototype = Object.create(Flog.RayTracer.Material.BaseMaterial.prototype);
Flog.RayTracer.Material.Solid.prototype.getColor = function(u, v){
  return this.color;
};

Flog.RayTracer.Material.Solid.prototype.toString = function () {
  return 'SolidMaterial [gloss=' + this.gloss + ', transparency=' + this.transparency + ', hasTexture=' + this.hasTexture +']';
};

/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Material.Chessboard = function(colorEven, colorOdd, reflection, transparency, gloss, density) {
  this.colorEven = colorEven;
  this.colorOdd = colorOdd;
  this.reflection = reflection;
  this.transparency = transparency;
  this.gloss = gloss;
  this.density = density;
  this.hasTexture = true;
};

Flog.RayTracer.Material.Chessboard.prototype = Object.create(Flog.RayTracer.Material.BaseMaterial.prototype);

Flog.RayTracer.Material.Chessboard.prototype.getColor = function(u, v){
  var t = this.wrapUp(u * this.density) * this.wrapUp(v * this.density);

  if(t < 0.0)
    return this.colorEven;
  else
    return this.colorOdd;
};

Flog.RayTracer.Material.Chessboard.prototype.toString = function () {
  return 'ChessMaterial [gloss=' + this.gloss + ', transparency=' + this.transparency + ', hasTexture=' + this.hasTexture +']';
};

/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};
if(typeof(Flog.RayTracer.Shape) == 'undefined') Flog.RayTracer.Shape = {};

Flog.RayTracer.Shape.Sphere = function(pos, radius, material) {
  this.radius = radius;
  this.position = pos;
  this.material = material;
};

Flog.RayTracer.Shape.Sphere.prototype = {
    intersect: function(ray){
        var info = new Flog.RayTracer.IntersectionInfo();
        info.shape = this;

        var dst = Flog.RayTracer.Vector.prototype.subtract(ray.position, this.position);

        var B = dst.dot(ray.direction);
        var C = dst.dot(dst) - (this.radius * this.radius);
        var D = (B * B) - C;

        if(D > 0){ // intersection!
            info.isHit = true;
            info.distance = (-B) - Math.sqrt(D);
            info.position = Flog.RayTracer.Vector.prototype.add(
                                                ray.position,
                                                Flog.RayTracer.Vector.prototype.multiplyScalar(
                                                    ray.direction,
                                                    info.distance
                                                )
                                            );
            info.normal = Flog.RayTracer.Vector.prototype.subtract(
                                            info.position,
                                            this.position
                                        ).normalize();

            info.color = this.material.getColor(0,0);
        } else {
            info.isHit = false;
        }
        return info;
    },

    toString : function () {
        return 'Sphere [position=' + this.position + ', radius=' + this.radius + ']';
    }
}
/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};
if(typeof(Flog.RayTracer.Shape) == 'undefined') Flog.RayTracer.Shape = {};

Flog.RayTracer.Shape.Plane = function(pos, d, material) {
  this.position = pos;
  this.d = d;
  this.material = material;
};


Flog.RayTracer.Shape.Plane.prototype = {
    intersect: function(ray){
        var info = new Flog.RayTracer.IntersectionInfo();

        var Vd = this.position.dot(ray.direction);
        if(Vd == 0) return info; // no intersection

        var t = -(this.position.dot(ray.position) + this.d) / Vd;
        if(t <= 0) return info;

        info.shape = this;
        info.isHit = true;
        info.position = Flog.RayTracer.Vector.prototype.add(
                                            ray.position,
                                            Flog.RayTracer.Vector.prototype.multiplyScalar(
                                                ray.direction,
                                                t
                                            )
                                        );
        info.normal = this.position;
        info.distance = t;

        if(this.material.hasTexture){
            var vU = new Flog.RayTracer.Vector(this.position.y, this.position.z, -this.position.x);
            var vV = vU.cross(this.position);
            var u = info.position.dot(vU);
            var v = info.position.dot(vV);
            info.color = this.material.getColor(u,v);
        } else {
            info.color = this.material.getColor(0,0);
        }

        return info;
    },

    toString : function () {
        return 'Plane [' + this.position + ', d=' + this.d + ']';
    }
}
/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.IntersectionInfo = function() {
  this.color = new Flog.RayTracer.Color(0,0,0);
  this.isHit = false;
  this.hitCount = 0;
  this.shape = null;
  this.position = null;
  this.normal = null;
  this.color = null;
  this.distance = null;
};

Flog.RayTracer.IntersectionInfo.prototype = {
    toString : function () {
        return 'Intersection [' + this.position + ']';
    }
}
/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Camera = function(pos, lookAt, up) {
  this.position = pos;
  this.lookAt = lookAt;
  this.up = up;
  this.equator = lookAt.normalize().cross(this.up);
  this.screen = Flog.RayTracer.Vector.prototype.add(this.position, this.lookAt);
};

Flog.RayTracer.Camera.prototype = {
    getRay: function(vx, vy){
        var pos = Flog.RayTracer.Vector.prototype.subtract(
            this.screen,
            Flog.RayTracer.Vector.prototype.subtract(
                Flog.RayTracer.Vector.prototype.multiplyScalar(this.equator, vx),
                Flog.RayTracer.Vector.prototype.multiplyScalar(this.up, vy)
            )
        );
        pos.y = pos.y * -1;
        var dir = Flog.RayTracer.Vector.prototype.subtract(
            pos,
            this.position
        );

        var ray = new Flog.RayTracer.Ray(pos, dir.normalize());

        return ray;
    },

    toString : function () {
        return 'Ray []';
    }
}
/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

Flog.RayTracer.Background = function(color, ambience) {
  this.color = color;
  this.ambience = ambience;
};

/* Fake a Flog.* namespace */
if(typeof(Flog) == 'undefined') var Flog = {};
if(typeof(Flog.RayTracer) == 'undefined') Flog.RayTracer = {};

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


Flog.RayTracer.Engine.prototype = {
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
            var color = this.rayTrace(info, ray, scene, 0);
            return color;
        }
        return scene.background.color;
    },

    testIntersection: function(ray, scene, exclude){
        var hits = 0;
        var best = new Flog.RayTracer.IntersectionInfo();
        best.distance = 2000;

        for(var i=0; i<scene.shapes.length; i++){
            var shape = scene.shapes[i];

            if(shape != exclude){
                var info = shape.intersect(ray);
                if(info.isHit && info.distance >= 0 && info.distance < best.distance){
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
        var R1 = Flog.RayTracer.Vector.prototype.add(
            Flog.RayTracer.Vector.prototype.multiplyScalar(N, 2*c1),
            V
        );
        return new Flog.RayTracer.Ray(P, R1);
    },

    rayTrace: function(info, ray, scene, depth){
        // Calc ambient
        var color = Flog.RayTracer.Color.prototype.multiplyScalar(info.color, scene.background.ambience);
        var oldColor = color;
        var shininess = Math.pow(10, info.shape.material.gloss + 1);

        for(var i=0; i<scene.lights.length; i++){
            var light = scene.lights[i];

            // Calc diffuse lighting
            var v = Flog.RayTracer.Vector.prototype.subtract(
                                light.position,
                                info.position
                            ).normalize();

            if(this.options.renderDiffuse){
                var L = v.dot(info.normal);
                if(L > 0.0){
                    color = Flog.RayTracer.Color.prototype.add(
                                        color,
                                        Flog.RayTracer.Color.prototype.multiply(
                                            info.color,
                                            Flog.RayTracer.Color.prototype.multiplyScalar(
                                                light.color,
                                                L
                                            )
                                        )
                                    );
                }
            }

            // The greater the depth the more accurate the colours, but
            // this is exponentially (!) expensive
            if(depth <= this.options.rayDepth){
          // calculate reflection ray
          if(this.options.renderReflections && info.shape.material.reflection > 0)
          {
              var reflectionRay = this.getReflectionRay(info.position, info.normal, ray.direction);
              var refl = this.testIntersection(reflectionRay, scene, info.shape);

              if (refl.isHit && refl.distance > 0){
                  refl.color = this.rayTrace(refl, reflectionRay, scene, depth + 1);
              } else {
                  refl.color = scene.background.color;
                        }

                  color = Flog.RayTracer.Color.prototype.blend(
                    color,
                    refl.color,
                    info.shape.material.reflection
                  );
          }

                // Refraction
                /* TODO */
            }

            /* Render shadows and highlights */

            var shadowInfo = new Flog.RayTracer.IntersectionInfo();

            if(this.options.renderShadows){
                var shadowRay = new Flog.RayTracer.Ray(info.position, v);

                shadowInfo = this.testIntersection(shadowRay, scene, info.shape);
                if(shadowInfo.isHit && shadowInfo.shape != info.shape /*&& shadowInfo.shape.type != 'PLANE'*/){
                    var vA = Flog.RayTracer.Color.prototype.multiplyScalar(color, 0.5);
                    var dB = (0.5 * Math.pow(shadowInfo.shape.material.transparency, 0.5));
                    color = Flog.RayTracer.Color.prototype.addScalar(vA,dB);
                }
            }

      // Phong specular highlights
      if(this.options.renderHighlights && !shadowInfo.isHit && info.shape.material.gloss > 0){
        var Lv = Flog.RayTracer.Vector.prototype.subtract(
                            info.shape.position,
                            light.position
                        ).normalize();

        var E = Flog.RayTracer.Vector.prototype.subtract(
                            scene.camera.position,
                            info.shape.position
                        ).normalize();

        var H = Flog.RayTracer.Vector.prototype.subtract(
                            E,
                            Lv
                        ).normalize();

        var glossWeight = Math.pow(Math.max(info.normal.dot(H), 0), shininess);
        color = Flog.RayTracer.Color.prototype.add(
                            Flog.RayTracer.Color.prototype.multiplyScalar(light.color, glossWeight),
                            color
                        );
      }
        }
        color.limit();
        return color;
    }
};

// 'event' null means that we are benchmarking
function renderScene(event){
    var scene = new Flog.RayTracer.Scene();

    scene.camera = new Flog.RayTracer.Camera(
                        new Flog.RayTracer.Vector(0, 0, -15),
                        new Flog.RayTracer.Vector(-0.2, 0, 5),
                        new Flog.RayTracer.Vector(0, 1, 0)
                    );

    scene.background = new Flog.RayTracer.Background(
                                new Flog.RayTracer.Color(0.5, 0.5, 0.5),
                                0.4
                            );

    var sphere = new Flog.RayTracer.Shape.Sphere(
        new Flog.RayTracer.Vector(-1.5, 1.5, 2),
        1.5,
        new Flog.RayTracer.Material.Solid(
            new Flog.RayTracer.Color(0,0.5,0.5),
            0.3,
            0.0,
            0.0,
            2.0
        )
    );

    var sphere1 = new Flog.RayTracer.Shape.Sphere(
        new Flog.RayTracer.Vector(1, 0.25, 1),
        0.5,
        new Flog.RayTracer.Material.Solid(
            new Flog.RayTracer.Color(0.9,0.9,0.9),
            0.1,
            0.0,
            0.0,
            1.5
        )
    );

    var plane = new Flog.RayTracer.Shape.Plane(
                                new Flog.RayTracer.Vector(0.1, 0.9, -0.5).normalize(),
                                1.2,
                                new Flog.RayTracer.Material.Chessboard(
                                    new Flog.RayTracer.Color(1,1,1),
                                    new Flog.RayTracer.Color(0,0,0),
                                    0.2,
                                    0.0,
                                    1.0,
                                    0.7
                                )
                            );

    scene.shapes.push(plane);
    scene.shapes.push(sphere);
    scene.shapes.push(sphere1);

    var light = new Flog.RayTracer.Light(
        new Flog.RayTracer.Vector(5, 10, -1),
        new Flog.RayTracer.Color(0.8, 0.8, 0.8)
    );

    var light1 = new Flog.RayTracer.Light(
        new Flog.RayTracer.Vector(-3, 5, -15),
        new Flog.RayTracer.Color(0.8, 0.8, 0.8),
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

    var raytracer = new Flog.RayTracer.Engine(
        {
            canvasWidth: imageWidth,
            canvasHeight: imageHeight,
            pixelWidth: parseInt(pixelSize[0]),
            pixelHeight: parseInt(pixelSize[1]),
            "renderDiffuse": renderDiffuse,
            "renderHighlights": renderHighlights,
            "renderShadows": renderShadows,
            "renderReflections": renderReflections,
            "rayDepth": rayDepth
        }
    );

    raytracer.renderScene(scene, canvas, 0);
}
