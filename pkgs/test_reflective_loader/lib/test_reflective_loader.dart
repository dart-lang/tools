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

/// The current group stack of nested [defineReflectiveSuite] calls.
List<_Group> _currentGroupStack = [];

/// The root groups or tests created by [defineReflectiveSuite] or
/// [defineReflectiveTests] calls.
List<_GroupEntry> _rootGroupEntries = [];

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
void defineReflectiveSuite(void Function() define, {String? name}) {
  _addGroup(_Group(name), define);

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

  var isSolo = _hasAnnotationInstance(classMirror, soloTest);
  var className = MirrorSystem.getName(classMirror.simpleName);

  _addGroup(
      _Group(className,
          solo: isSolo,
          location: classMirror.testLocation,
          classMirror: classMirror), () {
    classMirror.instanceMembers
        .forEach((Symbol symbol, MethodMirror memberMirror) {
      // we need only methods
      if (!memberMirror.isRegularMethod) {
        return;
      }
      // prepare information about the method
      var memberName = MirrorSystem.getName(symbol);
      var isTest = memberName.startsWith(RegExp('(solo_|fail_|skip_)*test_'));
      if (isTest) {
        var isSolo = memberName.startsWith('solo_') ||
            _hasAnnotationInstance(memberMirror, soloTest);
        var isSkipped = memberName.startsWith('skip_') ||
            _hasSkippedTestAnnotation(memberMirror);
        var expectFail = memberName.startsWith('fail_') ||
            memberName.startsWith('solo_fail_') ||
            _hasFailingTestAnnotation(memberMirror) ||
            _isCheckedMode && _hasAssertFailingTestAnnotation(memberMirror);
        var timeout =
            _getAnnotationInstance(memberMirror, TestTimeout) as TestTimeout?;

        _addTest(
          _Test(
              memberName,
              timeout: timeout?._timeout,
              location: memberMirror.testLocation,
              solo: isSolo,
              skip: isSkipped,
              () => expectFail
                  ? _runFailingTest(classMirror, symbol)
                  : _runTest(classMirror, symbol)),
        );
      }
    });
  });

  _addTestsIfTopLevelSuite();
}

/// If we're back at the top level ([_currentGroupStack] is empty), registers
/// all known groups and tests by calling [test_package.group] and
/// [test_package.test] appropriately.
void _addTestsIfTopLevelSuite() {
  if (_currentGroupStack.isNotEmpty) return;

  void addGroupsAndTests(List<_GroupEntry> entries) {
    for (var entry in entries) {
      switch (entry) {
        case _Group group:
          // Only add groups if they have names, otherwise just add their
          // children directly.
          if (group.name != null) {
            test_package.group(
              group.name,
              location: group.location,
              // ignore: deprecated_member_use, invalid_use_of_do_not_submit_member
              solo: group.solo,
              () {
                // If this group is a class, it may have class-wide
                // setUp/tearDown.
                if (group.classMirror != null) {
                  test_package.setUpAll(group.ensureSetUpClass);
                  test_package.tearDownAll(group.tearDownClass);
                }
                addGroupsAndTests(group.children);
              },
            );
          } else {
            addGroupsAndTests(group.children);
          }
          break;
        case _Test test:
          test_package.test(
              test.name,
              timeout: test.timeout,
              location: test.location,
              // ignore: deprecated_member_use, invalid_use_of_do_not_submit_member
              solo: test.solo,
              skip: test.skip,
              test.function);
          break;
      }
    }
  }

  addGroupsAndTests(_rootGroupEntries);
  _rootGroupEntries.clear();
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

/// Adds a group to the current stack and executes [define] for child group
/// or tests definitions.
void _addGroup(_Group group, void Function() define) {
  var parentCollection =
      _currentGroupStack.lastOrNull?.children ?? _rootGroupEntries;
  parentCollection.add(group);
  _currentGroupStack.add(group);
  try {
    define();
  } finally {
    _currentGroupStack.removeLast();
  }
}

/// Adds a test to the current group (or as a root test if there is no current
/// group).
void _addTest(_Test test) {
  var parentCollection =
      _currentGroupStack.lastOrNull?.children ?? _rootGroupEntries;
  parentCollection.add(test);
}

/// Run a test that is expected to fail, and confirm that it fails.
///
/// This properly handles the following cases:
/// - The test fails by throwing an exception
/// - The test returns a future which completes with an error.
/// - An exception is thrown to the zone handler from a timer task.
Future<void> _runFailingTest(ClassMirror classMirror, Symbol symbol) async {
  _FailedTestResult? result;

  await runZonedGuarded(() {
    // ignore: void_checks
    return Future.sync(() => _runTest(classMirror, symbol)).then<void>((_) {
      // We can't throw async exceptions inside here because `runZoneGuarded`
      // will never complete (see docs on `runZonedGuarded`), so we need to
      // capture this state and throw later if there wasn't otherwise an
      // exception.

      // If we didn't already have a failure (eg. an unawaited exception) then
      // this successful completion is an unexpected pass state.
      result ??= _FailedTestResult.pass;
    }).catchError((Object e) {
      // an awaited exception is always expected failure.
      result = _FailedTestResult.expectedFail;
    });
  }, (e, st) {
    result = _FailedTestResult.expectedFail;
  });

  // We can safely throw exceptions back outside of the error zone.
  if (result == _FailedTestResult.pass) {
    throw test_package.TestFailure('Test passed - expected to fail.');
  }
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

/// The result of a test that was expected to fail.
enum _FailedTestResult {
  /// The test (unexpectedly) passed.
  pass,

  /// The test failed as expected.
  expectedFail,
}

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

/// A marker annotation used to instruct dart2js to keep reflection information
/// for the annotated classes.
class _ReflectiveTest {
  const _ReflectiveTest();
}

/// A marker annotation used to annotate "solo" groups and tests.
class _SoloTest {
  const _SoloTest();
}

abstract class _GroupEntry {
  final String? name;
  final test_package.TestLocation? location;
  final bool solo;

  _GroupEntry(
    this.name, {
    this.location,
    this.solo = false,
  });
}

/// Information about a test group which could be from a call to
/// [defineReflectiveSuite] with a `name`, or a test class itself.
class _Group extends _GroupEntry {
  final List<_GroupEntry> children = [];
  final ClassMirror? classMirror;
  Future<Object?>? _setUpCompletion;

  _Group(
    super.name, {
    super.location,
    super.solo,
    this.classMirror,
  });

  /// Runs group-wide setup if it has not been started yet,
  /// ensuring it only runs once for a group. Set up runs and
  /// completes before any test of the group runs
  Future<Object?> ensureSetUpClass() {
    if (classMirror == null) return Future.value();
    return _setUpCompletion ??=
        _invokeSymbolIfExists(classMirror!, #setUpClass);
  }

  /// Runs group-wide tear down if [ensureSetUpClass] was called at least once.
  /// Must be called once and only called after all tests of the group have
  /// completed
  Future<Object?>? tearDownClass() {
    if (classMirror == null) return null;
    return _setUpCompletion != null
        ? _invokeSymbolIfExists(classMirror!, #tearDownClass)
        : null;
  }
}

/// Information about a test created for a method of a class with
/// [defineReflectiveTests].
class _Test extends _GroupEntry {
  final FutureOr<Object?>? Function() function;
  final bool skip;
  final test_package.Timeout? timeout;

  _Test(
    super.name,
    this.function, {
    required super.location,
    required super.solo,
    required this.skip,
    required this.timeout,
  });
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
