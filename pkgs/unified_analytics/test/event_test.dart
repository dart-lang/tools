// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:unified_analytics/src/enums.dart';
import 'package:unified_analytics/unified_analytics.dart';

void main() {
  test('Event.doctorValidatorResult constructed', () {
    Event genDoctorValidatorResult() => Event.doctorValidatorResult(
          validatorName: 'validatorName',
          result: 'success',
          partOfGroupedValidator: false,
          doctorInvocationId: 123,
          statusInfo: 'statusInfo',
        );

    final constructedEvent = genDoctorValidatorResult();

    expect(genDoctorValidatorResult, returnsNormally);
    expect(constructedEvent.eventName, DashEvent.doctorValidatorResult);
    expect(constructedEvent.eventData['validatorName'], 'validatorName');
    expect(constructedEvent.eventData['result'], 'success');
    expect(constructedEvent.eventData['partOfGroupedValidator'], false);
    expect(constructedEvent.eventData['doctorInvocationId'], 123);
    expect(constructedEvent.eventData['statusInfo'], 'statusInfo');
  });
}
