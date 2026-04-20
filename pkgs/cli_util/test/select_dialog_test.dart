// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cli_util/src/components/select_dialog.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

void main() {
  group('select_dialog', () {
    late MockStdin mockStdin; // Handles capturing line/echo mode changes.
    late MockStdout mockStdout; // Used to verify output.
    late StreamController<List<int>> inputController; // Actual input stream.

    // Custom test helper to test a series of inputs for both single and multi
    // select dialogs
    @isTestGroup
    void testInputSequence(
      String testName,
      // If a list is provided, each version will be tried for that entry.
      List<Object /*int|List<int>*/ > inputs, {
      List<String> options = const ['a', 'b', 'c'],
      required String? singleSelectOutput,
      required List<String>? multiSelectOutput,
    }) {
      group(testName, () {
        final defaultCombo = [
          // Initial default input combo is just all the first keys of the inputs.
          for (var input in inputs)
            if (input is int) input else (input as List<int>).first,
        ];
        // We don't test every permutation, individual keys are only tested
        // against the default combo for the other keys.
        final allInputCombinations = <List<int>>[defaultCombo];
        for (var i = 0; i < inputs.length; i++) {
          final input = inputs[i];
          if (input is List<int>) {
            for (var j = 1; j < input.length; j++) {
              allInputCombinations.add([
                ...defaultCombo.take(i),
                input[j],
                ...defaultCombo.skip(i + 1),
              ]);
            }
          }
        }

        for (var inputCombo in allInputCombinations) {
          for (var multiSelect in [false, true]) {
            final dialogType = multiSelect ? 'MultiSelect' : 'SingleSelect';
            test('$dialogType - ${inputCombo.join(', ')}', () async {
              final future = multiSelect
                  ? showMultiSelectDialog(
                      options,
                      inputController.stream,
                    )
                  : showSingleSelectDialog(
                      options,
                      inputController.stream,
                    );
              await pumpEventQueue();
              expect(mockStdin.lineMode, isFalse);
              expect(mockStdin.echoMode, isFalse);

              inputController.add(inputCombo);
              await pumpEventQueue();

              expect(
                await future,
                multiSelect ? multiSelectOutput : singleSelectOutput,
              );
            });
          }
        }
      });
    }

    setUp(() {
      mockStdin = MockStdin();
      mockStdout = MockStdout();
      inputController = StreamController<List<int>>();
      addTearDown(() => inputController.close());

      // Ensure terminal settings are restored and close the stream after tests.
      final previousOverrides = IOOverrides.current;
      addTearDown(() => IOOverrides.global = previousOverrides);

      IOOverrides.global = MyIOOverrides(mockStdin, mockStdout);
    });

    tearDown(() {
      // Verify terminal modes are restored.
      expect(mockStdin.lineMode, isTrue);
      expect(mockStdin.echoMode, isTrue);
      // First, we should have disabled the visible cursor.
      expect(mockStdout.buffer.first, '\x1b[?25l');
      // Then we should have re-enabled it at the end.
      expect(mockStdout.buffer.last, '\x1b[?25h\x1b[0m');
      // Should no longer be listening to the input stream.
      expect(inputController.hasListener, isFalse);
    });

    testInputSequence(
      'basic navigation',
      [Keys.down, Keys.space, Keys.down, Keys.space, Keys.enter],
      singleSelectOutput: 'c',
      multiSelectOutput: ['b', 'c'],
    );

    testInputSequence(
      'home key',
      [Keys.down, Keys.home, Keys.enter],
      singleSelectOutput: 'a',
      multiSelectOutput: [],
    );

    testInputSequence(
      'end key',
      [Keys.end, Keys.enter],
      singleSelectOutput: 'c',
      multiSelectOutput: [],
    );

    testInputSequence(
      'boundary conditions - top',
      [Keys.up, Keys.space, Keys.enter],
      singleSelectOutput: 'a',
      multiSelectOutput: ['a'],
    );

    testInputSequence(
      'boundary conditions - bottom',
      [Keys.down, Keys.down, Keys.down, Keys.space, Keys.enter],
      singleSelectOutput: 'c',
      multiSelectOutput: ['c'],
    );

    testInputSequence(
      'page down',
      [Keys.pageDown, Keys.space, Keys.enter],
      singleSelectOutput: 'c',
      multiSelectOutput: ['c'],
    );

    testInputSequence(
      'page up',
      [Keys.end, Keys.pageUp, Keys.space, Keys.enter],
      singleSelectOutput: 'a',
      multiSelectOutput: ['a'],
    );

    testInputSequence(
      'page down with many items',
      [Keys.pageDown, Keys.space, Keys.enter],
      options: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
      singleSelectOutput: 'f',
      multiSelectOutput: ['f'],
    );

    testInputSequence(
      'select and unselect',
      [Keys.down, Keys.space, Keys.space, Keys.enter],
      singleSelectOutput: 'b',
      multiSelectOutput: [],
    );

    testInputSequence(
      'select, unselect, select',
      [Keys.down, Keys.space, Keys.space, Keys.space, Keys.enter],
      singleSelectOutput: 'b',
      multiSelectOutput: ['b'],
    );

    testInputSequence(
      'select multiple items with movement',
      [Keys.down, Keys.space, Keys.up, Keys.space, Keys.enter],
      singleSelectOutput: 'a',
      multiSelectOutput: ['a', 'b'],
    );

    testInputSequence(
      'unselect one of multiple',
      [
        Keys.down,
        Keys.space,
        Keys.down,
        Keys.space,
        Keys.up,
        Keys.space,
        Keys.up,
        Keys.space,
        Keys.enter
      ],
      singleSelectOutput: 'a',
      multiSelectOutput: ['a', 'c'],
    );

    testInputSequence('Cancelling dialog', [Keys.quit],
        singleSelectOutput: null, multiSelectOutput: null);
  });
}

class MockStdin extends Stream<List<int>> implements Stdin {
  @override
  bool hasTerminal = true;
  @override
  bool lineMode = true;
  @override
  bool echoMode = true;

  @override
  int readByteSync() => throw UnimplementedError();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStdout implements Stdout {
  final buffer = <String>[];

  @override
  void write(Object? object) {
    buffer.add(object as String);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

base class MyIOOverrides extends IOOverrides {
  final Stdin _stdin;
  final Stdout _stdout;

  MyIOOverrides(this._stdin, this._stdout);

  @override
  Stdin get stdin => _stdin;

  @override
  Stdout get stdout => _stdout;
}

extension Keys on Never {
  // Normal-ish ascii characters
  static const space = 32;
  static const enter = [10, 13]; // newline, carraige return
  static const quit = [3, 4, 27]; // end of text, end of transmission, escape

  // Final parts of escape sequences
  static const up = 65; // A
  static const down = 66; // B
  static const pageUp = 53; // 5
  static const pageDown = 54; // 6
  static const home = [49, 72]; // 1, H
  static const end = [52, 70]; // 4, F
}
