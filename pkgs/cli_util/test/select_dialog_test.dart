// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cli_util/src/components/select_dialog.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'fake_terminal.dart';

void main() {
  group('select_dialog', () {
    late MockStdin mockStdin; // Handles capturing line/echo mode changes.
    late MockStdout mockStdout; // Used to verify output.
    late StreamController<ByteSequence> inputController; // Actual input stream.

    // Custom test helper to test a series of inputs for both single and multi
    // select dialogs
    @isTestGroup
    void testInputSequence(
      String testName,
      // Every variant of every input will be tried, but only with one
      // combination of other variants.
      List<KeyVariants> inputs, {
      List<String> options = const ['a', 'b', 'c'],
      required int? singleSelectOutput,
      required Set<int>? multiSelectOutput,
    }) {
      group(testName, () {
        final defaultVariant = [
          // Initial default input combo is just all the first keys of the
          // inputs.
          for (var input in inputs) input.first,
        ];
        // We don't test every permutation, individual keys are only tested
        // against the default combo for the other keys.
        final allInputCombinations = <List<ByteSequence>>[defaultVariant];
        for (var i = 0; i < inputs.length; i++) {
          final input = inputs[i];
          // Add an extra combination for each variant other than the first.
          for (var j = 1; j < input.length; j++) {
            allInputCombinations.add([
              ...defaultVariant.take(i),
              input[j],
              ...defaultVariant.skip(i + 1),
            ]);
          }
        }

        for (var inputCombo in allInputCombinations) {
          for (var multiSelect in [false, true]) {
            final dialogType = multiSelect ? 'MultiSelect' : 'SingleSelect';
            test('$dialogType - ${inputCombo.join(', ')}', () async {
              final future =
                  multiSelect
                      ? showMultiSelectDialog(options, inputController.stream)
                      : showSingleSelectDialog(options, inputController.stream);
              await pumpEventQueue();
              expect(mockStdin.lineMode, isFalse);
              expect(mockStdin.echoMode, isFalse);

              inputCombo.forEach(inputController.add);
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
      inputController = StreamController();
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
      if (mockStdout.buffer.isNotEmpty) {
        // First, we should have disabled the visible cursor.
        expect(mockStdout.buffer.first, '\x1b[?25l');
        // Then we should have re-enabled it at the end.
        expect(mockStdout.buffer.last, '\x1b[?25h\x1b[0m');
      }
      // Should no longer be listening to the input stream.
      expect(inputController.hasListener, isFalse);
    });

    testInputSequence(
      'basic navigation',
      [
        KeyVariants.down,
        KeyVariants.space,
        KeyVariants.down,
        KeyVariants.space,
        KeyVariants.enter,
      ],
      singleSelectOutput: 2,
      multiSelectOutput: {1, 2},
    );

    testInputSequence(
      'home key',
      [
        KeyVariants.down,
        KeyVariants.home,
        KeyVariants.space,
        KeyVariants.enter,
      ],
      singleSelectOutput: 0,
      multiSelectOutput: {0},
    );

    testInputSequence(
      'end key',
      [KeyVariants.end, KeyVariants.space, KeyVariants.enter],
      singleSelectOutput: 2,
      multiSelectOutput: {2},
    );

    testInputSequence(
      'boundary conditions - top',
      [KeyVariants.up, KeyVariants.space, KeyVariants.enter],
      singleSelectOutput: 0,
      multiSelectOutput: {0},
    );

    testInputSequence(
      'boundary conditions - bottom',
      [
        KeyVariants.down,
        KeyVariants.down,
        KeyVariants.down,
        KeyVariants.space,
        KeyVariants.enter,
      ],
      singleSelectOutput: 2,
      multiSelectOutput: {2},
    );

    testInputSequence(
      'page down',
      [KeyVariants.pageDown, KeyVariants.space, KeyVariants.enter],
      singleSelectOutput: 2,
      multiSelectOutput: {2},
    );

    testInputSequence(
      'page up',
      [
        KeyVariants.end,
        KeyVariants.pageUp,
        KeyVariants.space,
        KeyVariants.enter,
      ],
      singleSelectOutput: 0,
      multiSelectOutput: {0},
    );

    testInputSequence(
      'page down with many items',
      [KeyVariants.pageDown, KeyVariants.space, KeyVariants.enter],
      options: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
      singleSelectOutput: 5,
      multiSelectOutput: {5},
    );

    testInputSequence(
      'select and unselect',
      [
        KeyVariants.down,
        KeyVariants.space,
        KeyVariants.space,
        KeyVariants.enter,
      ],
      singleSelectOutput: 1,
      multiSelectOutput: <int>{},
    );

    testInputSequence(
      'select, unselect, select',
      [
        KeyVariants.down,
        KeyVariants.space,
        KeyVariants.space,
        KeyVariants.space,
        KeyVariants.enter,
      ],
      singleSelectOutput: 1,
      multiSelectOutput: {1},
    );

    testInputSequence(
      'select multiple items with movement',
      [
        KeyVariants.down,
        KeyVariants.space,
        KeyVariants.up,
        KeyVariants.space,
        KeyVariants.enter,
      ],
      singleSelectOutput: 0,
      multiSelectOutput: {0, 1},
    );

    testInputSequence(
      'unselect one of multiple',
      [
        KeyVariants.down,
        KeyVariants.space,
        KeyVariants.down,
        KeyVariants.space,
        KeyVariants.up,
        KeyVariants.space,
        KeyVariants.up,
        KeyVariants.space,
        KeyVariants.enter,
      ],
      singleSelectOutput: 0,
      multiSelectOutput: {0, 2},
    );

    testInputSequence(
      'Cancelling dialog',
      [KeyVariants.quit],
      singleSelectOutput: null,
      multiSelectOutput: null,
    );

    group('UI tests', () {
      for (final multiSelect in [true, false]) {
        group(multiSelect ? 'multi-select' : 'single-select', () {
          final uBox = multiSelect ? ' [ ]' : '';
          final sBox = multiSelect ? ' [x]' : '';
          final renderer =
              multiSelect ? showMultiSelectDialog : showSingleSelectDialog;

          test('renders UI state correctly', () async {
            final future = renderer([
              'apple',
              'banana',
              'cherry',
            ], inputController.stream);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
>$uBox apple
 $uBox banana
 $uBox cherry
''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox apple
>$uBox banana
 $uBox cherry
''');

            inputController.addKey(KeyVariants.space);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox apple
>$sBox banana
 $uBox cherry
''');

            inputController.addKey(KeyVariants.enter);
            expect(await future, multiSelect ? {1} : 1);
          });

          test('renders scrollbar correctly at top and bottom', () async {
            final future = renderer(
              ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
              inputController.stream,
              maxVisibleItems: 5, // ignore: avoid_redundant_argument_values
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox a      █
 $uBox b      █
 $uBox c      █
 $uBox d      █
 $uBox e      │
''');
            inputController.addKeys(List.filled(2, KeyVariants.down));
            inputController.addKey(KeyVariants.space);
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
 $uBox a      █
 $uBox b      █
>$sBox c      █
 $uBox d      █
 $uBox e      │
''');

            inputController.addKeys(List.filled(4, KeyVariants.down));
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
 $sBox c      │
 $uBox d      █
 $uBox e      █
 $uBox f      █
>$uBox g      █
''');

            inputController.addKey(KeyVariants.enter);
            expect(await future, multiSelect ? {2} : 6);
          });

          test('renders scrollbar correctly with 24 items', () async {
            final options = List.generate(25, (i) => '$i');
            final future = renderer(
              options,
              inputController.stream,
              maxVisibleItems: 5, // ignore: avoid_redundant_argument_values
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox 0       █
 $uBox 1       │
 $uBox 2       │
 $uBox 3       │
 $uBox 4       │
''');

            inputController.addKeys(List.filled(2, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 0       █
 $uBox 1       │
>$uBox 2       │
 $uBox 3       │
 $uBox 4       │
''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 1       │
 $uBox 2       █
>$uBox 3       │
 $uBox 4       │
 $uBox 5       │
''');

            inputController.addKeys(List.filled(6, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 7       │
 $uBox 8       █
>$uBox 9       │
 $uBox 10      │
 $uBox 11      │
''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 8       │
 $uBox 9       │
>$uBox 10      █
 $uBox 11      │
 $uBox 12      │
''');

            inputController.addKeys(List.filled(5, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 13      │
 $uBox 14      │
>$uBox 15      █
 $uBox 16      │
 $uBox 17      │
''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 14      │
 $uBox 15      │
>$uBox 16      │
 $uBox 17      █
 $uBox 18      │
''');

            inputController.addKeys(List.filled(5, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 19      │
 $uBox 20      │
>$uBox 21      │
 $uBox 22      █
 $uBox 23      │
''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 20      │
 $uBox 21      │
>$uBox 22      │
 $uBox 23      │
 $uBox 24      █
''');

            inputController.addKeys(List.filled(2, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 20      │
 $uBox 21      │
 $uBox 22      │
 $uBox 23      │
>$uBox 24      █
''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {24} : 24);
          });

          test('renders scrollbar correctly for small lists', () async {
            final options = List.generate(6, (i) => '$i');
            final future = renderer(
              options,
              inputController.stream,
              maxVisibleItems: 5,
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox 0      █
 $uBox 1      █
 $uBox 2      █
 $uBox 3      █
 $uBox 4      │
''');

            inputController.addKeys(List.filled(4, KeyVariants.down));
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
 $uBox 1      │
 $uBox 2      █
 $uBox 3      █
>$uBox 4      █
 $uBox 5      █
''');

            inputController.addKey(KeyVariants.enter);
            expect(await future, multiSelect ? <int>{} : 4);
          });

          test('truncates long items', () async {
            mockStdout.terminalColumns = 20 + uBox.length;
            final future = renderer([
              'a very long option that should be truncated',
              'short',
            ], inputController.stream);
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox a very long opt...
 $uBox short
''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {0} : 0);
          });

          test('truncates long items when scrollable', () async {
            mockStdout.terminalColumns = 20 + uBox.length;
            final future = renderer([
              'a very long option that should be truncated',
              'b',
              'c',
              'd',
              'e',
              'f',
            ], inputController.stream);
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox a very l...      █
 $uBox b                █
 $uBox c                █
 $uBox d                █
 $uBox e                │
''');

            if (multiSelect) {
              inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
              expect(await future, {0});
            } else {
              inputController.addKey(KeyVariants.enter);
              expect(await future, 0);
            }
          });
        });
      }
    });

    group('Terminal support edge cases', () {
      for (final multiselect in [true, false]) {
        group(multiselect ? 'multiselect' : 'single select', () {
          final renderer =
              multiselect ? showMultiSelectDialog : showSingleSelectDialog;

          test('returns null if no stdout terminal', () async {
            mockStdout.hasTerminal = false;
            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            final result = await renderer(['a', 'b'], inputController.stream);
            expect(result, isNull);
          });

          test('returns null if terminal too small (no scrollbar)', () async {
            mockStdout.terminalColumns =
                '> '.length +
                6 /* 3 chars + '...'*/ +
                (multiselect ? 4 : 0) -
                1;
            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            final result = await renderer(['a', 'b'], inputController.stream);
            expect(result, isNull);
          });

          test(
            'works if the terminal is exactly sized (no scrollbar)',
            () async {
              mockStdout.terminalColumns =
                  '> '.length + 6 /* 3 chars + '...'*/ + (multiselect ? 4 : 0);
              inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
              expect(
                await renderer(['a', 'b'], inputController.stream),
                multiselect ? {0} : 0,
              );
            },
          );

          test('returns null if terminal too small (scrollbar)', () async {
            mockStdout.terminalColumns =
                '> '.length +
                6 /* 3 chars + '...'*/ +
                '      █'.length +
                (multiselect ? 4 : 0) -
                1;
            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            final result = await renderer(
              ['a', 'b'],
              inputController.stream,
              maxVisibleItems: 1,
            );
            expect(result, isNull);
          });

          test('works if the terminal is exactly sized (scrollbar)', () async {
            mockStdout.terminalColumns =
                '> '.length +
                6 /* 3 chars + '...'*/ +
                '      █'.length +
                (multiselect ? 4 : 0);
            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(
              await renderer(
                ['a', 'b'],
                inputController.stream,
                maxVisibleItems: 1,
              ),
              multiselect ? {0} : 0,
            );
          });
        });
      }
    });
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
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStdout implements Stdout {
  // Catches the raw output of writes, used just for validating certain control
  // sequences right now.
  final buffer = <String>[];
  final terminal = FakeTerminal();

  @override
  bool hasTerminal = true;

  @override
  int terminalColumns = 80;

  @override
  void write(Object? object) {
    buffer.add(object as String);
    terminal.write(object);
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

/// Nice type to use around a list of bytes that represents ascii characters
/// or ansii escape codes.
extension type const ByteSequence(List<int> bytes) implements List<int> {}

/// All the variants of [ByteSequence]s for each key that we support.
extension type const KeyVariants(List<ByteSequence> variants)
    implements List<ByteSequence> {
  // Normal-ish ascii characters
  static const space = KeyVariants([
    ByteSequence([32]), // space
  ]);
  static const enter = KeyVariants([
    ByteSequence([10]), // newline
    ByteSequence([13]), // carraige return
  ]);
  static const quit = KeyVariants([
    ByteSequence([3]), // end of text
    ByteSequence([4]), // end of transmission
    ByteSequence([27]), // escape
  ]);

  // Escape sequences
  static const up = KeyVariants([
    ByteSequence([27, 91, 65 /* A */]),
  ]);
  static const down = KeyVariants([
    ByteSequence([27, 91, 66 /* B */]),
  ]);
  static const pageUp = KeyVariants([
    ByteSequence([27, 91, 53 /* 5 */, 126 /* ~ */]),
  ]);
  static const pageDown = KeyVariants([
    ByteSequence([27, 91, 54 /* 6 */, 126 /* ~ */]),
  ]);
  static const home = KeyVariants([
    ByteSequence([27, 91, 49 /* 1 */]),
    ByteSequence([27, 91, 72 /* H */]),
  ]);
  static const end = KeyVariants([
    ByteSequence([27, 91, 52 /* 4 */]),
    ByteSequence([27, 91, 70 /* F */]),
  ]);
}

extension on StreamController<ByteSequence> {
  /// Adds the first [ByteSequence] in a [KeyVariants] to the stream.
  void addKey(KeyVariants key) {
    add(key.first);
  }

  /// Calls [addKey] for each key in [keys].
  void addKeys(List<KeyVariants> keys) {
    keys.forEach(addKey);
  }
}
