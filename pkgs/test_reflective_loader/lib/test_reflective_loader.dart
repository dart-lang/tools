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
    group = _Group(
        isSolo, _combineNames(_currentSuiteName, className), classMirror);
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
        group.addSkippedTest(memberName, memberMirror.testLocation);
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
      group.addSkippedTest(memberName, memberMirror.testLocation);
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
        var runTestCount = 0;
        if (allGroups || group.isSolo) {
          for (var test in group.tests) {
            if (allTests || test.isSolo) {
              if (!test.isSkipped) {
                runTestCount += 1;
              }
              test_package.test(test.name, () async {
                await group.ensureSetUpClass();
                try {
                  await test.function();
                } finally {
                  runTestCount -= 1;
                  if (runTestCount == 0) {
                    group.tearDownClass();
                  }
                }
              },
                  timeout: test.timeout,
                  skip: test.isSkipped,
                  location: test.location);
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
    ObjectMirror objectMirror, Symbol symbol) {
  Object? invocationResult;
  InstanceMirror? closure;
  try {
    closure = objectMirror.getField(symbol);
    // ignore: avoid_catching_errors
  } on NoSuchMethodError {
    // ignore: empty_catches
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
  var failed = false;
  return runZonedGuarded(() {
    // ignore: void_checks
    return Future.sync(() => _runTest(classMirror, symbol)).then<void>((_) {
      // Only consider a passed test (and therefore something we should fail) if
      // this completed without another failure (such as an out-of-band
      // exception) occurring during the run.
      if (!failed) {
        passed = true;
        test_package.fail('Test passed - expected to fail.');
      }
    }).catchError((Object e) {
      // if passed, and we call fail(), rethrow this exception
      if (passed) {
        // ignore: only_throw_errors
        throw e;
      }
      failed = true;
      // otherwise, an exception is not a failure for _runFailingTest
    });
  }, (e, st) {
    // if passed, and we call fail(), rethrow this exception
    if (passed) {
      // ignore: only_throw_errors
      throw e;
    }
    failed = true;
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

  /// For static group-wide operations eg `setUpClass` and `tearDownClass`.
  final ClassMirror _classMirror;
  Future<Object?>? _setUpCompletion;

  _Group(this.isSolo, this.name, this._classMirror);

  bool get hasSoloTest => tests.any((test) => test.isSolo);

  void addSkippedTest(String name, test_package.TestLocation? location) {
    var fullName = _combineNames(this.name, name);
    tests.add(_Test.skipped(isSolo, fullName, location));
  }

  void addTest(bool isSolo, String name, MethodMirror memberMirror,
      _TestFunction function) {
    var fullName = _combineNames(this.name, name);
    var timeout =
        _getAnnotationInstance(memberMirror, TestTimeout) as TestTimeout?;
    tests.add(_Test(isSolo, fullName, function, timeout?._timeout,
        memberMirror.testLocation));
  }

  /// Runs group-wide setup if it has not been started yet,
  /// ensuring it only runs once for a group. Set up runs and
  /// completes before any test of the group runs
  Future<Object?> ensureSetUpClass() =>
      _setUpCompletion ??= _invokeSymbolIfExists(_classMirror, #setUpClass);

  /// Runs group-wide tear down iff [ensureSetUpClass] was called at least once.
  /// Must be called once and only called after all tests of the group have
  /// completed
  void tearDownClass() => _setUpCompletion != null
      ? _invokeSymbolIfExists(_classMirror, #tearDownClass)
      : null;
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
  final test_package.TestLocation? location;

  final bool isSkipped;

  _Test(this.isSolo, this.name, this.function, this.timeout, this.location)
      : isSkipped = false;

  _Test.skipped(this.isSolo, this.name, this.location)
      : isSkipped = true,
        function = (() {}),
        timeout = null;
}

extension on DeclarationMirror {
  test_package.TestLocation? get testLocation {
    if (location case var location?) {
      return test_package.TestLocation(
          location.sourceUri, location.line, location.column);
    } else {
      return null;
    }
  }
}
