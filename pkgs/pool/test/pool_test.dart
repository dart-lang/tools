// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:pool/pool.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/test.dart';

void main() {
  group("request()", () {
    test("resources can be requested freely up to the limit", () {
      var pool = new Pool(50);
      for (var i = 0; i < 50; i++) {
        expect(pool.request(), completes);
      }
    });

    test("resources block past the limit", () {
      new FakeAsync().run((async) {
        var pool = new Pool(50);
        for (var i = 0; i < 50; i++) {
          expect(pool.request(), completes);
        }
        expect(pool.request(), doesNotComplete);

        async.elapse(new Duration(seconds: 1));
      });
    });

    test("a blocked resource is allocated when another is released", () {
      new FakeAsync().run((async) {
        var pool = new Pool(50);
        for (var i = 0; i < 49; i++) {
          expect(pool.request(), completes);
        }

        pool.request().then((lastAllocatedResource) {
          // This will only complete once [lastAllocatedResource] is released.
          expect(pool.request(), completes);

          new Future.delayed(new Duration(microseconds: 1)).then((_) {
            lastAllocatedResource.release();
          });
        });

        async.elapse(new Duration(seconds: 1));
      });
    });
  });

  group("withResource()", () {
    test("can be called freely up to the limit", () {
      var pool = new Pool(50);
      for (var i = 0; i < 50; i++) {
        pool.withResource(expectAsync(() => new Completer().future));
      }
    });

    test("blocks the callback past the limit", () {
      new FakeAsync().run((async) {
        var pool = new Pool(50);
        for (var i = 0; i < 50; i++) {
          pool.withResource(expectAsync(() => new Completer().future));
        }
        pool.withResource(expectNoAsync());

        async.elapse(new Duration(seconds: 1));
      });
    });

    test("a blocked resource is allocated when another is released", () {
      new FakeAsync().run((async) {
        var pool = new Pool(50);
        for (var i = 0; i < 49; i++) {
          pool.withResource(expectAsync(() => new Completer().future));
        }

        var completer = new Completer();
        pool.withResource(() => completer.future);
        var blockedResourceAllocated = false;
        pool.withResource(() {
          blockedResourceAllocated = true;
        });

        new Future.delayed(new Duration(microseconds: 1)).then((_) {
          expect(blockedResourceAllocated, isFalse);
          completer.complete();
          return new Future.delayed(new Duration(microseconds: 1));
        }).then((_) {
          expect(blockedResourceAllocated, isTrue);
        });

        async.elapse(new Duration(seconds: 1));
      });
    });
  });

  group("with a timeout", () {
    test("doesn't time out if there are no pending requests", () {
      new FakeAsync().run((async) {
        var pool = new Pool(50, timeout: new Duration(seconds: 5));
        for (var i = 0; i < 50; i++) {
          expect(pool.request(), completes);
        }

        async.elapse(new Duration(seconds: 6));
      });
    });

    test("resets the timer if a resource is returned", () {
      new FakeAsync().run((async) {
        var pool = new Pool(50, timeout: new Duration(seconds: 5));
        for (var i = 0; i < 49; i++) {
          expect(pool.request(), completes);
        }

        pool.request().then((lastAllocatedResource) {
          // This will only complete once [lastAllocatedResource] is released.
          expect(pool.request(), completes);

          new Future.delayed(new Duration(seconds: 3)).then((_) {
            lastAllocatedResource.release();
            expect(pool.request(), doesNotComplete);
          });
        });

        async.elapse(new Duration(seconds: 6));
      });
    });

    test("resets the timer if a resource is requested", () {
      new FakeAsync().run((async) {
        var pool = new Pool(50, timeout: new Duration(seconds: 5));
        for (var i = 0; i < 50; i++) {
          expect(pool.request(), completes);
        }
        expect(pool.request(), doesNotComplete);

        new Future.delayed(new Duration(seconds: 3)).then((_) {
          expect(pool.request(), doesNotComplete);
        });

        async.elapse(new Duration(seconds: 6));
      });
    });

    test("times out if nothing happens", () {
      new FakeAsync().run((async) {
        var pool = new Pool(50, timeout: new Duration(seconds: 5));
        for (var i = 0; i < 50; i++) {
          expect(pool.request(), completes);
        }
        expect(pool.request(), throwsA(new isInstanceOf<TimeoutException>()));

        async.elapse(new Duration(seconds: 6));
      });
    });
  });

  group("allowRelease()", () {
    test("runs the callback once the resource limit is exceeded", () async {
      var pool = new Pool(50);
      for (var i = 0; i < 49; i++) {
        expect(pool.request(), completes);
      }

      var resource = await pool.request();
      var onReleaseCalled = false;
      resource.allowRelease(() => onReleaseCalled = true);
      await new Future.delayed(Duration.ZERO);
      expect(onReleaseCalled, isFalse);

      expect(pool.request(), completes);
      await new Future.delayed(Duration.ZERO);
      expect(onReleaseCalled, isTrue);
    });

    test("runs the callback immediately if there are blocked requests",
        () async {
      var pool = new Pool(1);
      var resource = await pool.request();

      // This will be blocked until [resource.allowRelease] is called.
      expect(pool.request(), completes);

      var onReleaseCalled = false;
      resource.allowRelease(() => onReleaseCalled = true);
      await new Future.delayed(Duration.ZERO);
      expect(onReleaseCalled, isTrue);
    });

    test("blocks the request until the callback completes", () async {
      var pool = new Pool(1);
      var resource = await pool.request();

      var requestComplete = false;
      pool.request().then((_) => requestComplete = true);

      var completer = new Completer();
      resource.allowRelease(() => completer.future);
      await new Future.delayed(Duration.ZERO);
      expect(requestComplete, isFalse);

      completer.complete();
      await new Future.delayed(Duration.ZERO);
      expect(requestComplete, isTrue);
    });

    test("completes requests in request order regardless of callback order",
        () async {
      var pool = new Pool(2);
      var resource1 = await pool.request();
      var resource2 = await pool.request();

      var request1Complete = false;
      pool.request().then((_) => request1Complete = true);
      var request2Complete = false;
      pool.request().then((_) => request2Complete = true);

      var onRelease1Called = false;
      var completer1 = new Completer();
      resource1.allowRelease(() {
        onRelease1Called = true;
        return completer1.future;
      });
      await new Future.delayed(Duration.ZERO);
      expect(onRelease1Called, isTrue);

      var onRelease2Called = false;
      var completer2 = new Completer();
      resource2.allowRelease(() {
        onRelease2Called = true;
        return completer2.future;
      });
      await new Future.delayed(Duration.ZERO);
      expect(onRelease2Called, isTrue);
      expect(request1Complete, isFalse);
      expect(request2Complete, isFalse);

      // Complete the second resource's onRelease callback first. Even though it
      // was triggered by the second blocking request, it should complete the
      // first one to preserve ordering.
      completer2.complete();
      await new Future.delayed(Duration.ZERO);
      expect(request1Complete, isTrue);
      expect(request2Complete, isFalse);

      completer1.complete();
      await new Future.delayed(Duration.ZERO);
      expect(request1Complete, isTrue);
      expect(request2Complete, isTrue);
    });

    test("runs onRequest in the zone it was created", () async {
      var pool = new Pool(1);
      var resource = await pool.request();

      var outerZone = Zone.current;
      runZoned(() {
        var innerZone = Zone.current;
        expect(innerZone, isNot(equals(outerZone)));

        resource.allowRelease(expectAsync(() {
          expect(Zone.current, equals(innerZone));
        }));
      });

      pool.request();
    });
  });
}

/// Returns a function that will cause the test to fail if it's called.
///
/// This should only be called within a [FakeAsync.run] zone.
Function expectNoAsync() {
  var stack = new Trace.current(1);
  return () => registerException(
      new TestFailure("Expected function not to be called."), stack);
}

/// A matcher for Futures that asserts that they don't complete.
///
/// This should only be called within a [FakeAsync.run] zone.
Matcher get doesNotComplete => predicate((future) {
  expect(future, new isInstanceOf<Future>());

  var stack = new Trace.current(1);
  future.then((_) => registerException(
      new TestFailure("Expected future not to complete."), stack));
  return true;
});
