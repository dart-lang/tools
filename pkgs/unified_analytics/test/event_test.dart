// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  test('Event.doctorValidatorResult constructed', () {
    expect(
        () => Event.doctorValidatorResult(
              validatorName: 'validatorName',
              result: 'result',
              partOfGroupedValidator: false,
              doctorInvocationId: 123,
              statusInfo: 'statusInfo',
            ),
        returnsNormally);
  });
}
