// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:boolean_selector/boolean_selector.dart';

void main(List<String> args) {
  var selector = BooleanSelector.parse('(x && y) || z');
  print(selector.evaluate((variable) => args.contains(variable)));
}
