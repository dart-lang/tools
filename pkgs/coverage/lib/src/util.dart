// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library coverage.src.util;

import 'dart:async';

/// Retries the specified function with the specified interval and returns
/// the result on successful completion.
Future retry(Future f(), Duration interval) {
  var completer = new Completer();
  doRetry() {
    f().then((result) => completer.complete(result),
        onError: (e) => new Timer(interval, doRetry));
  }
  doRetry();
  return completer.future;
}
