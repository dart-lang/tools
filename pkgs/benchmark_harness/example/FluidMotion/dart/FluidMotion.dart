import 'dart:html';

/// Copyright 2013 the V8 project authors. All rights reserved.
/// Copyright 2009 Oliver Hunt <http://nerget.com>
///
/// Permission is hereby granted, free of charge, to any person
/// obtaining a copy of this software and associated documentation
/// files (the 'Software'), to deal in the Software without
/// restriction, including without limitation the rights to use,
/// copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the
/// Software is furnished to do so, subject to the following
/// conditions:
///
/// The above copyright notice and this permission notice shall be
/// included in all copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
/// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
/// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
/// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
/// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
/// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
/// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
/// OTHER DEALINGS IN THE SOFTWARE.

// Ported from the v8 benchmark suite by Google 2013.
// Uses Float64List for data.

import 'dart:math';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';

/// Copyright 2009 Oliver Hunt <http://nerget.com>
///
/// Permission is hereby granted, free of charge, to any person
/// obtaining a copy of this software and associated documentation
/// files (the 'Software'), to deal in the Software without
/// restriction, including without limitation the rights to use,
/// copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the
/// Software is furnished to do so, subject to the following
/// conditions:
///
/// The above copyright notice and this permission notice shall be
/// included in all copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
/// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
/// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
/// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
/// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
/// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
/// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
/// OTHER DEALINGS IN THE SOFTWARE.
// Ported from the v8 benchmark suite by Google 2013.
// Uses Float64List for data.

/// Copyright 2009 Oliver Hunt <http://nerget.com>
///
/// Permission is hereby granted, free of charge, to any person
/// obtaining a copy of this software and associated documentation
/// files (the 'Software'), to deal in the Software without
/// restriction, including without limitation the rights to use,
/// copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the
/// Software is furnished to do so, subject to the following
/// conditions:
///
/// The above copyright notice and this permission notice shall be
/// included in all copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
/// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
/// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
/// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
/// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
/// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
/// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
/// OTHER DEALINGS IN THE SOFTWARE.
// Ported from the v8 benchmark suite by Google 2013.
// Uses Float64List for data.

void main() {
  const FluidMotion().report();
}

class FluidMotion extends BenchmarkBase {
  static FluidField solver;
  static int framesTillAddingPoints = 0;
  static int framesBetweenAddingPoints = 5;

  const FluidMotion() : super('FluidMotion');

  static void setupFluidMotion() {
    framesTillAddingPoints = 0;
    framesBetweenAddingPoints = 5;
    solver = FluidField.create(null, 128, 128, 20);
    solver.setDisplayFunction((a) {});
    solver.setUICallback(prepareFrame);
  }

  static void runFluidMotion() {
    setupFluidMotion();
    for (var i = 0; i < 10; i++) {
      solver.update();
    }
    solver.validate(758.9012130174812, -352.56376676179076, -357.3690235879736);
  }

  static void main() {
    runFluidMotion();
  }

  static void addPoints(Field field) {
    var n = 64;
    for (var i = 1; i <= n; i++) {
      field.setVelocity(i, i, n.toDouble(), n.toDouble());
      field.setDensity(i, i, 5.0);
      field.setVelocity(i, n - i, -n.toDouble(), -n.toDouble());
      field.setDensity(i, n - i, 20.0);
      field.setVelocity(128 - i, n + i, -n.toDouble(), -n.toDouble());
      field.setDensity(128 - i, n + i, 30.0);
    }
  }

  static void prepareFrame(Field field) {
    if (framesTillAddingPoints == 0) {
      addPoints(field);
      framesTillAddingPoints = framesBetweenAddingPoints;
      framesBetweenAddingPoints++;
    } else {
      framesTillAddingPoints--;
    }
  }

  // Overrides of BenchmarkBase.

  @override
  void warmup() {
    runFluidMotion();
  }

  @override
  void exercise() {
    runFluidMotion();
  }
}

// Code from Oliver Hunt (http://nerget.com/fluidSim/pressure.js) starts here.

class FluidField {
  final CanvasElement canvas;
  final int iterations;
  final double dt = 0.1;
  final int size;
  Float64List dens, dens_prev;
  Float64List u, u_prev;
  Float64List v, v_prev;
  final int width, height;
  final int rowSize;
  void Function(Field) displayFunc;

  static FluidField _lastCreated;

  static bool approxEquals(double a, double b) => (a - b).abs() < 0.000001;

  void validate(double expectedDens, double expectedU, double expectedV) {
    var sumDens = 0.0;
    var sumU = 0.0;
    var sumV = 0.0;
    for (var i = 0; i < dens.length; i++) {
      sumDens += dens[i];
      sumU += u[i];
      sumV += v[i];
    }

    if (!approxEquals(sumDens, expectedDens) ||
        !approxEquals(sumU, expectedU) ||
        !approxEquals(sumV, expectedV)) {
      throw 'Incorrect result';
    }
  }

  // Allocates a new FluidField or return previously allocated field if the
  // size is too large.
  factory FluidField.create(
      CanvasElement canvas, int hRes, int wRes, int iterations) {
    final res = wRes * hRes;
    if ((res > 0) && (res < 1000000)) {
      _lastCreated = FluidField(canvas, hRes, wRes, iterations);
    }
    _lastCreated ??= FluidField(canvas, 64, 64, iterations);
    assert((canvas == _lastCreated.canvas) &&
        (iterations == _lastCreated.iterations));
    return _lastCreated;
  }

  FluidField(this.canvas, this.height, this.width, this.iterations)
      : rowSize = width + 2,
        size = (width + 2) * (height + 2) {
    reset();
  }

  void reset() {
    // All Float64List elements are initialized to 0.0.
    dens = Float64List(size);
    dens_prev = Float64List(size);
    u = Float64List(size);
    u_prev = Float64List(size);
    v = Float64List(size);
    v_prev = Float64List(size);
  }

  void addFields(Float64List x, Float64List s, double dt) {
    for (var i = 0; i < size; i++) {
      x[i] += dt * s[i];
    }
  }

  void set_bnd(int b, Float64List x) {
    if (b == 1) {
      var i = 1;
      for (; i <= width; i++) {
        x[i] = x[i + rowSize];
        x[i + (height + 1) * rowSize] = x[i + height * rowSize];
      }

      for (var j = 1; j <= height; j++) {
        x[j * rowSize] = x[1 + j * rowSize];
        x[(width + 1) + j * rowSize] = -1 * x[width + j * rowSize];
      }
    } else if (b == 2) {
      for (var i = 1; i <= width; i++) {
        x[i] = -1 * x[i + rowSize];
        x[i + (height + 1) * rowSize] = -1 * x[i + height * rowSize];
      }

      for (var j = 1; j <= height; j++) {
        x[j * rowSize] = x[1 + j * rowSize];
        x[(width + 1) + j * rowSize] = x[width + j * rowSize];
      }
    } else {
      for (var i = 1; i <= width; i++) {
        x[i] = x[i + rowSize];
        x[i + (height + 1) * rowSize] = x[i + height * rowSize];
      }

      for (var j = 1; j <= height; j++) {
        x[j * rowSize] = x[1 + j * rowSize];
        x[(width + 1) + j * rowSize] = x[width + j * rowSize];
      }
    }
    var maxEdge = (height + 1) * rowSize;
    x[0] = 0.5 * (x[1] + x[rowSize]);
    x[maxEdge] = 0.5 * (x[1 + maxEdge] + x[height * rowSize]);
    x[(width + 1)] = 0.5 * (x[width] + x[(width + 1) + rowSize]);
    x[(width + 1) + maxEdge] =
        0.5 * (x[width + maxEdge] + x[(width + 1) + height * rowSize]);
  }

  void lin_solve(int b, Float64List x, Float64List x0, int a, int c) {
    if (a == 0 && c == 1) {
      for (var j = 1; j <= height; j++) {
        var currentRow = j * rowSize;
        ++currentRow;
        for (var i = 0; i < width; i++) {
          x[currentRow] = x0[currentRow];
          ++currentRow;
        }
      }
      set_bnd(b, x);
    } else {
      var invC = 1 / c;
      for (var k = 0; k < iterations; k++) {
        for (var j = 1; j <= height; j++) {
          var lastRow = (j - 1) * rowSize;
          var currentRow = j * rowSize;
          var nextRow = (j + 1) * rowSize;
          var lastX = x[currentRow];
          ++currentRow;
          for (var i = 1; i <= width; i++) {
            lastX = x[currentRow] = (x0[currentRow] +
                    a *
                        (lastX +
                            x[++currentRow] +
                            x[++lastRow] +
                            x[++nextRow])) *
                invC;
          }
        }
        set_bnd(b, x);
      }
    }
  }

  void diffuse(int b, Float64List x, Float64List x0, double dt) {
    var a = 0;
    lin_solve(b, x, x0, a, 1 + 4 * a);
  }

  void lin_solve2(Float64List x, Float64List x0, Float64List y, Float64List y0,
      int a, int c) {
    if (a == 0 && c == 1) {
      for (var j = 1; j <= height; j++) {
        var currentRow = j * rowSize;
        ++currentRow;
        for (var i = 0; i < width; i++) {
          x[currentRow] = x0[currentRow];
          y[currentRow] = y0[currentRow];
          ++currentRow;
        }
      }
      set_bnd(1, x);
      set_bnd(2, y);
    } else {
      var invC = 1 / c;
      for (var k = 0; k < iterations; k++) {
        for (var j = 1; j <= height; j++) {
          var lastRow = (j - 1) * rowSize;
          var currentRow = j * rowSize;
          var nextRow = (j + 1) * rowSize;
          var lastX = x[currentRow];
          var lastY = y[currentRow];
          ++currentRow;
          for (var i = 1; i <= width; i++) {
            lastX = x[currentRow] = (x0[currentRow] +
                    a * (lastX + x[currentRow] + x[lastRow] + x[nextRow])) *
                invC;
            lastY = y[currentRow] = (y0[currentRow] +
                    a *
                        (lastY +
                            y[++currentRow] +
                            y[++lastRow] +
                            y[++nextRow])) *
                invC;
          }
        }
        set_bnd(1, x);
        set_bnd(2, y);
      }
    }
  }

  void diffuse2(
      Float64List x, Float64List x0, Float64List y, Float64List y0, double dt) {
    var a = 0;
    lin_solve2(x, x0, y, y0, a, 1 + 4 * a);
  }

  void advect(int b, Float64List d, Float64List d0, Float64List u,
      Float64List v, double dt) {
    var Wdt0 = dt * width;
    var Hdt0 = dt * height;
    var Wp5 = width + 0.5;
    var Hp5 = height + 0.5;
    for (var j = 1; j <= height; j++) {
      var pos = j * rowSize;
      for (var i = 1; i <= width; i++) {
        var x = i - Wdt0 * u[++pos];
        var y = j - Hdt0 * v[pos];
        if (x < 0.5) {
          x = 0.5;
        } else if (x > Wp5) x = Wp5;
        var i0 = x.toInt();
        var i1 = i0 + 1;
        if (y < 0.5) {
          y = 0.5;
        } else if (y > Hp5) y = Hp5;
        var j0 = y.toInt();
        var j1 = j0 + 1;
        var s1 = x - i0;
        var s0 = 1 - s1;
        var t1 = y - j0;
        var t0 = 1 - t1;
        var row1 = j0 * rowSize;
        var row2 = j1 * rowSize;
        d[pos] = s0 * (t0 * d0[i0 + row1] + t1 * d0[i0 + row2]) +
            s1 * (t0 * d0[i1 + row1] + t1 * d0[i1 + row2]);
      }
    }
    set_bnd(b, d);
  }

  void project(Float64List u, Float64List v, Float64List p, Float64List div) {
    var h = -0.5 / sqrt(width * height);
    for (var j = 1; j <= height; j++) {
      var row = j * rowSize;
      var previousRow = (j - 1) * rowSize;
      var prevValue = row - 1;
      var currentRow = row;
      var nextValue = row + 1;
      var nextRow = (j + 1) * rowSize;
      for (var i = 1; i <= width; i++) {
        div[++currentRow] = h *
            (u[++nextValue] - u[++prevValue] + v[++nextRow] - v[++previousRow]);
        p[currentRow] = 0.0;
      }
    }
    set_bnd(0, div);
    set_bnd(0, p);

    lin_solve(0, p, div, 1, 4);
    var wScale = 0.5 * width;
    var hScale = 0.5 * height;
    for (var j = 1; j <= height; j++) {
      var prevPos = j * rowSize - 1;
      var currentPos = j * rowSize;
      var nextPos = j * rowSize + 1;
      var prevRow = (j - 1) * rowSize;
      var nextRow = (j + 1) * rowSize;

      for (var i = 1; i <= width; i++) {
        u[++currentPos] -= wScale * (p[++nextPos] - p[++prevPos]);
        v[currentPos] -= hScale * (p[++nextRow] - p[++prevRow]);
      }
    }
    set_bnd(1, u);
    set_bnd(2, v);
  }

  void dens_step(
      Float64List x, Float64List x0, Float64List u, Float64List v, double dt) {
    addFields(x, x0, dt);
    diffuse(0, x0, x, dt);
    advect(0, x, x0, u, v, dt);
  }

  void vel_step(
      Float64List u, Float64List v, Float64List u0, Float64List v0, double dt) {
    addFields(u, u0, dt);
    addFields(v, v0, dt);
    var temp = u0;
    u0 = u;
    u = temp;
    temp = v0;
    v0 = v;
    v = temp;
    diffuse2(u, u0, v, v0, dt);
    project(u, v, u0, v0);
    temp = u0;
    u0 = u;
    u = temp;
    temp = v0;
    v0 = v;
    v = temp;
    advect(1, u, u0, u0, v0, dt);
    advect(2, v, v0, u0, v0, dt);
    project(u, v, u0, v0);
  }

  void Function(Field) uiCallback;

  void setDisplayFunction(void Function(Field) func) {
    displayFunc = func;
  }

  void setUICallback(void Function(Field) callback) {
    uiCallback = callback;
  }

  void queryUI(Float64List d, Float64List u, Float64List v) {
    for (var i = 0; i < size; i++) {
      u[i] = v[i] = d[i] = 0.0;
    }
    uiCallback(Field(d, u, v, rowSize));
  }

  void update() {
    queryUI(dens_prev, u_prev, v_prev);
    vel_step(u, v, u_prev, v_prev, dt);
    dens_step(dens, dens_prev, u, v, dt);
    displayFunc(Field(dens, u, v, rowSize));
  }
}

// Difference from JS version: Field takes an argument rowSize, but this
// used for display purpose only.
class Field {
  final Float64List dens, u, v;
  final int rowSize;

  Field(this.dens, this.u, this.v, this.rowSize);

  void setDensity(int x, int y, double d) {
    dens[(x + 1) + (y + 1) * rowSize] = d;
  }

  double getDensity(int x, int y) {
    return dens[(x + 1) + (y + 1) * rowSize]; // rowSize from FluidField?
  }

  void setVelocity(int x, int y, double xv, double yv) {
    u[(x + 1) + (y + 1) * rowSize] = xv;
    v[(x + 1) + (y + 1) * rowSize] = yv;
  }

  double getXVelocity(int x, int y) {
    return u[(x + 1) + (y + 1) * rowSize];
  }

  double getYVelocity(int x, int y) {
    return v[(x + 1) + (y + 1) * rowSize];
  }
}
