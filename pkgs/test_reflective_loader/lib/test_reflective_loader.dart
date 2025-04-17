// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:mirrors';

import 'package:test/test.dart' as test_package;

/// A marker annotation used to annotate test methods which are expected to fail
/// when asserts are enabled.
const Object assertFailingTest = _AssertFailingTest();

/// A marker annotation used to annotate test methods which are expected to
/// fail.
const Object failingTest = FailingTest();

/// A marker annotation used to instruct dart2js to keep reflection information
/// for the annotated classes.
const Object reflectiveTest = _ReflectiveTest();

/// A marker annotation used to annotate test methods that should be skipped.
const Object skippedTest = SkippedTest();

/// A marker annotation used to annotate "solo" groups and tests.
const Object soloTest = _SoloTest();

final List<_Group> _currentGroups = <_Group>[];
int _currentSuiteLevel = 0;
String _currentSuiteName = '';

/// Is `true` the application is running in the checked mode.
final bool _isCheckedMode = () {
  try {
    assert(false);
    return false;
  } catch (_) {
    return true;
  }
}();

/// Run the [define] function parameter that calls [defineReflectiveTests] to
/// add normal and "solo" tests, and also calls [defineReflectiveSuite] to
/// create embedded suites.  If the current suite is the top-level one, perform
/// check for "solo" groups and tests, and run all or only "solo" items.
void defineReflectiveSuite(void Function() define, {String name = ''}) {
  var groupName = _currentSuiteName;
  _currentSuiteLevel++;
  try {
    _currentSuiteName = _combineNames(_currentSuiteName, name);
    define();
  } finally {
    _currentSuiteName = groupName;
    _currentSuiteLevel--;
  }
  _addTestsIfTopLevelSuite();
}

/// Runs test methods existing in the given [type].
///
/// If there is a "solo" test method in the top-level suite, only "solo" methods
/// are run.
///
/// If there is a "solo" test type, only its test methods are run.
///
/// Otherwise all tests methods of all test types are run.
///
/// Each method is run with a new instance of [type].
/// So, [type] should have a default constructor.
///
/// If [type] declares method `setUp`, it methods will be invoked before any
/// test method invocation.
///
/// If [type] declares method `tearDown`, it will be invoked after any test
/// method invocation. If method returns [Future] to test some asynchronous
/// behavior, then `tearDown` will be invoked in `Future.complete`.
void defineReflectiveTests(Type type) {
  var classMirror = reflectClass(type);
  if (!classMirror.metadata.any((InstanceMirror annotation) =>
      annotation.type.reflectedType == _ReflectiveTest)) {
    var name = MirrorSystem.getName(classMirror.qualifiedName);
    throw Exception('Class $name must have annotation "@reflectiveTest" '
        'in order to be run by runReflectiveTests.');
  }

  _Group group;
  {
    var isSolo = _hasAnnotationInstance(classMirror, soloTest);
    var className = MirrorSystem.getName(classMirror.simpleName);
    group = _Group(isSolo, _combineNames(_currentSuiteName, className));
    _currentGroups.add(group);
  }

  classMirror.instanceMembers
      .forEach((Symbol symbol, MethodMirror memberMirror) {
    // we need only methods
    if (!memberMirror.isRegularMethod) {
      return;
    }
    // prepare information about the method
    var memberName = MirrorSystem.getName(symbol);
    var isSolo = memberName.startsWith('solo_') ||
        _hasAnnotationInstance(memberMirror, soloTest);
    // test_
    if (memberName.startsWith('test_')) {
      if (_hasSkippedTestAnnotation(memberMirror)) {
        group.addSkippedTest(memberName);
      } else {
        group.addTest(isSolo, memberName, memberMirror, () {
          if (_hasFailingTestAnnotation(memberMirror) ||
              _isCheckedMode && _hasAssertFailingTestAnnotation(memberMirror)) {
            return _runFailingTest(classMirror, symbol);
          } else {
            return _runTest(classMirror, symbol);
          }
        });
      }
      return;
    }
    // solo_test_
    if (memberName.startsWith('solo_test_')) {
      group.addTest(true, memberName, memberMirror, () {
        return _runTest(classMirror, symbol);
      });
    }
    // fail_test_
    if (memberName.startsWith('fail_')) {
      group.addTest(isSolo, memberName, memberMirror, () {
        return _runFailingTest(classMirror, symbol);
      });
    }
    // solo_fail_test_
    if (memberName.startsWith('solo_fail_')) {
      group.addTest(true, memberName, memberMirror, () {
        return _runFailingTest(classMirror, symbol);
      });
    }
    // skip_test_
    if (memberName.startsWith('skip_test_')) {
      group.addSkippedTest(memberName);
    }
  });

  // Support for the case of missing enclosing [defineReflectiveSuite].
  _addTestsIfTopLevelSuite();
}

/// If the current suite is the top-level one, add tests to the `test` package.
void _addTestsIfTopLevelSuite() {
  if (_currentSuiteLevel == 0) {
    void runTests({required bool allGroups, required bool allTests}) {
      for (var group in _currentGroups) {
        if (allGroups || group.isSolo) {
          for (var test in group.tests) {
            if (allTests || test.isSolo) {
              test_package.test(test.name, test.function,
                  timeout: test.timeout, skip: test.isSkipped);
            }
          }
        }
      }
    }

    if (_currentGroups.any((g) => g.hasSoloTest)) {
      runTests(allGroups: true, allTests: false);
    } else if (_currentGroups.any((g) => g.isSolo)) {
      runTests(allGroups: false, allTests: true);
    } else {
      runTests(allGroups: true, allTests: true);
    }
    _currentGroups.clear();
  }
}

/// Return the combination of the [base] and [addition] names.
/// If any other two is `null`, then the other one is returned.
String _combineNames(String base, String addition) {
  if (base.isEmpty) {
    return addition;
  } else if (addition.isEmpty) {
    return base;
  } else {
    return '$base | $addition';
  }
}

Object? _getAnnotationInstance(DeclarationMirror declaration, Type type) {
  for (var annotation in declaration.metadata) {
    if ((annotation.reflectee as Object).runtimeType == type) {
      return annotation.reflectee;
    }
  }
  return null;
}

bool _hasAnnotationInstance(DeclarationMirror declaration, Object instance) =>
    declaration.metadata.any((InstanceMirror annotation) =>
        identical(annotation.reflectee, instance));

bool _hasAssertFailingTestAnnotation(MethodMirror method) =>
    _hasAnnotationInstance(method, assertFailingTest);

bool _hasFailingTestAnnotation(MethodMirror method) =>
    _hasAnnotationInstance(method, failingTest);

bool _hasSkippedTestAnnotation(MethodMirror method) =>
    _hasAnnotationInstance(method, skippedTest);

Future<Object?> _invokeSymbolIfExists(
    InstanceMirror instanceMirror, Symbol symbol) {
  Object? invocationResult;
  InstanceMirror? closure;
  try {
    closure = instanceMirror.getField(symbol);
    // ignore: avoid_catching_errors
  } on NoSuchMethodError {
    // ignore
  }

  if (closure is ClosureMirror) {
    invocationResult = closure.apply([]).reflectee;
  }
  return Future.value(invocationResult);
}

/// Run a test that is expected to fail, and confirm that it fails.
///
/// This properly handles the following cases:
/// - The test fails by throwing an exception
/// - The test returns a future which completes with an error.
/// - An exception is thrown to the zone handler from a timer task.
Future<Object?>? _runFailingTest(ClassMirror classMirror, Symbol symbol) {
  var passed = false;
  return runZonedGuarded(() {
    // ignore: void_checks
    return Future.sync(() => _runTest(classMirror, symbol)).then<void>((_) {
      passed = true;
      test_package.fail('Test passed - expected to fail.');
    }).catchError((Object e) {
      // if passed, and we call fail(), rethrow this exception
      if (passed) {
        // ignore: only_throw_errors
        throw e;
      }
      // otherwise, an exception is not a failure for _runFailingTest
    });
  }, (e, st) {
    // if passed, and we call fail(), rethrow this exception
    if (passed) {
      // ignore: only_throw_errors
      throw e;
    }
    // otherwise, an exception is not a failure for _runFailingTest
  });
}

Future<void> _runTest(ClassMirror classMirror, Symbol symbol) async {
  var instanceMirror = classMirror.newInstance(const Symbol(''), []);
  try {
    await _invokeSymbolIfExists(instanceMirror, #setUp);
    await instanceMirror.invoke(symbol, []).reflectee;
  } finally {
    await _invokeSymbolIfExists(instanceMirror, #tearDown);
  }
}

typedef _TestFunction = dynamic Function();

/// A marker annotation used to annotate test methods which are expected to
/// fail.
class FailingTest {
  /// Initialize this annotation with the given arguments.
  ///
  /// [issue] is a full URI describing the failure and used for tracking.
  /// [reason] is a free form textual description.
  const FailingTest({String? issue, String? reason});
}

/// A marker annotation used to annotate test methods which are skipped.
class SkippedTest {
  /// Initialize this annotation with the given arguments.
  ///
  /// [issue] is a full URI describing the failure and used for tracking.
  /// [reason] is a free form textual description.
  const SkippedTest({String? issue, String? reason});
}

/// A marker annotation used to annotate test methods with additional timeout
/// information.
class TestTimeout {
  final test_package.Timeout _timeout;

  /// Initialize this annotation with the given timeout.
  const TestTimeout(test_package.Timeout timeout) : _timeout = timeout;
}

/// A marker annotation used to annotate test methods which are expected to fail
/// when asserts are enabled.
class _AssertFailingTest {
  const _AssertFailingTest();
}

/// Information about a type based test group.
class _Group {
  final bool isSolo;
  final String name;
  final List<_Test> tests = <_Test>[];

  _Group(this.isSolo, this.name);

  bool get hasSoloTest => tests.any((test) => test.isSolo);

  void addSkippedTest(String name) {
    var fullName = _combineNames(this.name, name);
    tests.add(_Test.skipped(isSolo, fullName));
  }

  void addTest(bool isSolo, String name, MethodMirror memberMirror,
      _TestFunction function) {
    var fullName = _combineNames(this.name, name);
    var timeout =
        _getAnnotationInstance(memberMirror, TestTimeout) as TestTimeout?;
    tests.add(_Test(isSolo, fullName, function, timeout?._timeout));
  }
}

/// A marker annotation used to instruct dart2js to keep reflection information
/// for the annotated classes.
class _ReflectiveTest {
  const _ReflectiveTest();
}

/// A marker annotation used to annotate "solo" groups and tests.
class _SoloTest {
  const _SoloTest();
}

/// Information about a test.
class _Test {
  final bool isSolo;
  final String name;
  final _TestFunction function;
  final test_package.Timeout? timeout;

  final bool isSkipped;

  _Test(this.isSolo, this.name, this.function, this.timeout)
      : isSkipped = false;

  _Test.skipped(this.isSolo, this.name)
      : isSkipped = true,
        function = (() {}),
        timeout = null;
}
