library unittest;

import 'package:unittest/unittest.dart';

export 'package:unittest/unittest.dart';

// Jasmine-like syntax for unittest.
void describe(String spec, TestFunction body) => group(spec, body);
void it(String spec, TestFunction body) => test(spec, body);
