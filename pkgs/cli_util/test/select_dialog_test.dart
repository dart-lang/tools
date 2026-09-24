// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_components.dart';
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
              final sizing = SelectComponentSizing.fixed(
                totalHeight: 5 + (multiSelect ? 1 : 0),
              );
              final future =
                  multiSelect
                      ? showMultiSelectDialog(
                        options,
                        inputController.stream,
                        sizing: sizing,
                      )
                      : showSingleSelectDialog(
                        options,
                        inputController.stream,
                        sizing: sizing,
                      );
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
          final fiveItemSizing = SelectComponentSizing.fixed(
            totalHeight: 5 + (multiSelect ? 1 : 0),
          );
          String maybeLegend() => multiSelect ? '\n$multiSelectLegend' : '';

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
 $uBox cherry${maybeLegend()}''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox apple
>$uBox banana
 $uBox cherry${maybeLegend()}''');

            inputController.addKey(KeyVariants.space);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox apple
>$sBox banana
 $uBox cherry${maybeLegend()}''');

            inputController.addKey(KeyVariants.enter);
            expect(await future, multiSelect ? {1} : 1);
          });

          test('renders scrollbar correctly at top and bottom', () async {
            final future = renderer(
              ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
              inputController.stream,
              sizing: fiveItemSizing,
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox a      █
 $uBox b      █
 $uBox c      █
 $uBox d      █
 $uBox e      │${maybeLegend()}''');
            inputController.addKeys(List.filled(2, KeyVariants.down));
            inputController.addKey(KeyVariants.space);
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
 $uBox a      █
 $uBox b      █
>$sBox c      █
 $uBox d      █
 $uBox e      │${maybeLegend()}''');

            inputController.addKeys(List.filled(4, KeyVariants.down));
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
 $sBox c      │
 $uBox d      █
 $uBox e      █
 $uBox f      █
>$uBox g      █${maybeLegend()}''');

            inputController.addKey(KeyVariants.enter);
            expect(await future, multiSelect ? {2} : 6);
          });

          test('renders scrollbar correctly with 24 items', () async {
            final options = List.generate(25, (i) => '$i');
            final future = renderer(
              options,
              inputController.stream,
              sizing: fiveItemSizing,
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox 0       █
 $uBox 1       │
 $uBox 2       │
 $uBox 3       │
 $uBox 4       │${maybeLegend()}''');

            inputController.addKeys(List.filled(2, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 0       █
 $uBox 1       │
>$uBox 2       │
 $uBox 3       │
 $uBox 4       │${maybeLegend()}''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 1       │
 $uBox 2       █
>$uBox 3       │
 $uBox 4       │
 $uBox 5       │${maybeLegend()}''');

            inputController.addKeys(List.filled(6, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 7       │
 $uBox 8       █
>$uBox 9       │
 $uBox 10      │
 $uBox 11      │${maybeLegend()}''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 8       │
 $uBox 9       │
>$uBox 10      █
 $uBox 11      │
 $uBox 12      │${maybeLegend()}''');

            inputController.addKeys(List.filled(5, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 13      │
 $uBox 14      │
>$uBox 15      █
 $uBox 16      │
 $uBox 17      │${maybeLegend()}''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 14      │
 $uBox 15      │
>$uBox 16      │
 $uBox 17      █
 $uBox 18      │${maybeLegend()}''');

            inputController.addKeys(List.filled(5, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 19      │
 $uBox 20      │
>$uBox 21      │
 $uBox 22      █
 $uBox 23      │${maybeLegend()}''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 20      │
 $uBox 21      │
>$uBox 22      │
 $uBox 23      │
 $uBox 24      █${maybeLegend()}''');

            inputController.addKeys(List.filled(2, KeyVariants.down));
            await pumpEventQueue();
            expect(mockStdout.terminal.content, '''
 $uBox 20      │
 $uBox 21      │
 $uBox 22      │
 $uBox 23      │
>$uBox 24      █${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {24} : 24);
          });

          test('renders scrollbar correctly for small lists', () async {
            final options = List.generate(6, (i) => '$i');
            final future = renderer(
              options,
              inputController.stream,
              sizing: fiveItemSizing,
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox 0      █
 $uBox 1      █
 $uBox 2      █
 $uBox 3      █
 $uBox 4      │${maybeLegend()}''');

            inputController.addKeys(List.filled(4, KeyVariants.down));
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
 $uBox 1      │
 $uBox 2      █
 $uBox 3      █
>$uBox 4      █
 $uBox 5      █${maybeLegend()}''');

            inputController.addKey(KeyVariants.enter);
            expect(await future, multiSelect ? <int>{} : 4);
          });

          test('does not truncate exactly sized items', () async {
            mockStdout.terminalColumns = '> abcdefg'.length + uBox.length;
            final future = renderer([
              'abcdefg',
              'hijklmn',
            ], inputController.stream);
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox abcdefg
 $uBox hijklmn${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? <int>{0} : 0);
          });

          test('truncates items exactly one character too long', () async {
            mockStdout.terminalColumns = '> abcdefg'.length + uBox.length;
            final future = renderer([
              'abcdefg',
              'hijklmno',
            ], inputController.stream);
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox abcdefg
 $uBox hijk...${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? <int>{0} : 0);
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
 $uBox short${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {0} : 0);
          });

          test('truncates long items when scrollable', () async {
            mockStdout.terminalColumns = 20 + uBox.length;
            final future = renderer(
              [
                'a very long option that should be truncated',
                'b',
                'c',
                'd',
                'e',
                'f',
              ],
              inputController.stream,
              sizing: fiveItemSizing,
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox a very l...      █
 $uBox b                █
 $uBox c                █
 $uBox d                █
 $uBox e                │${maybeLegend()}''');

            if (multiSelect) {
              inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
              expect(await future, {0});
            } else {
              inputController.addKey(KeyVariants.enter);
              expect(await future, 0);
            }
          });
        });

        test('multi-select respects initialSelected', () async {
          final future = showMultiSelectDialog(
            ['apple', 'banana', 'cherry'],
            inputController.stream,
            initialSelected: {1, 2},
          );
          await pumpEventQueue();
          expect(mockStdout.terminal.content, '''
> [ ] apple
  [x] banana
  [x] cherry
$multiSelectLegend''');
          inputController.addKey(KeyVariants.enter);
          expect(await future, {1, 2});
        });

        test('multi-select Ctrl+A toggles all', () async {
          final future = showMultiSelectDialog([
            'apple',
            'banana',
            'cherry',
          ], inputController.stream);
          await pumpEventQueue();
          expect(mockStdout.terminal.content, '''
> [ ] apple
  [ ] banana
  [ ] cherry
$multiSelectLegend''');

          inputController.addKey(KeyVariants.selectAll);
          await pumpEventQueue();
          expect(mockStdout.terminal.content, '''
> [x] apple
  [x] banana
  [x] cherry
$multiSelectLegend''');

          inputController.addKey(KeyVariants.selectAll);
          await pumpEventQueue();
          expect(mockStdout.terminal.content, '''
> [ ] apple
  [ ] banana
  [ ] cherry
$multiSelectLegend''');

          inputController.addKey(KeyVariants.enter);
          expect(await future, <int>{});
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

          test(
            'throws AssertionError for non-ASCII options at start',
            () async {
              expect(
                () => renderer(['\u00FF'], inputController.stream),
                throwsA(isA<AssertionError>()),
              );
            },
          );

          test(
            'throws AssertionError for non-ASCII options in middle',
            () async {
              expect(
                () => renderer(['abc\u00FF'], inputController.stream),
                throwsA(isA<AssertionError>()),
              );
            },
          );

          test('throws AssertionError for non-ASCII description', () async {
            expect(
              () => renderer([
                const SelectOption('abc', description: 'line1\n\u00FF'),
              ], inputController.stream),
              throwsA(isA<AssertionError>()),
            );
          });

          test('throws ArgumentError for invalid option type', () async {
            expect(
              () => renderer([123], inputController.stream),
              throwsA(isA<ArgumentError>()),
            );
          });

          test('throws AssertionError for invalid sizing values', () async {
            expect(
              () => SelectComponentSizing.fixed(maxDescriptionHeight: -1),
              throwsA(isA<AssertionError>()),
            );
            expect(
              () => SelectComponentSizing.fit(maxDescriptionHeight: -1),
              throwsA(isA<AssertionError>()),
            );
            expect(
              () => renderer(
                ['a'],
                inputController.stream,
                // ignore: deprecated_member_use_from_same_package
                maxVisibleItems: 0,
              ),
              throwsA(isA<AssertionError>()),
            );
          });
        });

        test('multiselect throws AssertionError for invalid initialSelected '
            'indices', () async {
          expect(
            () => showMultiSelectDialog(
              ['a', 'b'],
              inputController.stream,
              initialSelected: {2},
            ),
            throwsA(isA<AssertionError>()),
          );
        });
      }
    });

    group('descriptions and ANSI sequences', () {
      for (final multiSelect in [true, false]) {
        group(multiSelect ? 'multi-select' : 'single-select', () {
          final uBox = multiSelect ? ' [ ]' : '';
          final sBox = multiSelect ? ' [x]' : '';
          final descIndent = multiSelect ? '      ' : '  ';
          final renderer =
              multiSelect ? showMultiSelectDialog : showSingleSelectDialog;
          String maybeLegend() => multiSelect ? '\n$multiSelectLegend' : '';

          test(
            'renders hovered descriptions dynamically without dead space',
            () async {
              final future = renderer([
                const SelectOption('apple', description: 'A crisp red fruit'),
                const SelectOption(
                  'banana',
                  description: 'Line 1\nLine 2\r\nLine 3',
                ),
                'cherry',
              ], inputController.stream);
              await pumpEventQueue();

              expect(mockStdout.terminal.content, '''
>$uBox apple
$descIndent${'A crisp red fruit'}
 $uBox banana
 $uBox cherry${maybeLegend()}''');

              inputController.addKey(KeyVariants.down);
              await pumpEventQueue();
              expect(mockStdout.terminal.content, '''
 $uBox apple
>$uBox banana
$descIndent${'Line 1'}
$descIndent${'Line 2'}
$descIndent${'Line 3'}
 $uBox cherry${maybeLegend()}''');

              inputController.addKey(KeyVariants.down);
              await pumpEventQueue();
              expect(mockStdout.terminal.content, '''
 $uBox apple
 $uBox banana
>$uBox cherry${maybeLegend()}''');

              inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
              expect(await future, multiSelect ? {2} : 2);
            },
          );

          test('truncates descriptions exceeding maxDescriptionHeight with '
              'ellipsis', () async {
            final future = renderer(
              [
                const SelectOption(
                  'item1',
                  description: 'L1\nL2\nL3\nL4\nL5\nL6\nL7',
                ),
                const SelectOption('item2', description: 'Short'),
              ],
              inputController.stream,
              sizing: const SelectComponentSizing.fixed(),
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox item1
$descIndent${'L1'}
$descIndent${'L2'}
$descIndent${'L3'}
$descIndent${'L4'}
$descIndent${'L5...'}
 $uBox item2${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {0} : 0);
          });

          test('respects custom SelectComponentSizing.fixed', () async {
            final future = renderer(
              [
                const SelectOption(
                  'item1',
                  description: 'First\nSecond\nThird',
                ),
              ],
              inputController.stream,
              sizing: const SelectComponentSizing.fixed(
                totalHeight: 8,
                maxDescriptionHeight: 2,
              ),
            );
            await pumpEventQueue();

            expect(mockStdout.terminal.content, '''
>$uBox item1
$descIndent${'First'}
$descIndent${'Second...'}${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {0} : 0);
          });

          test('word-wraps long description lines, respects newlines, and adds '
              'ellipsis when exceeding maxDescriptionHeight', () async {
            mockStdout.terminalColumns = 15 + uBox.length;
            final future = renderer(
              [
                const SelectOption(
                  'short',
                  description:
                      'this description line is too long\n'
                      'short line',
                ),
              ],
              inputController.stream,
              sizing: const SelectComponentSizing.fixed(
                maxDescriptionHeight: 3,
              ),
            );
            await pumpEventQueue();

            // Available width is 15 - 2 ('> ') = 13 chars.
            // 'this description line is too long' wraps to:
            //   'this'
            //   'description'
            //   'line is...'
            expect(mockStdout.terminal.content, '''
>$uBox short
$descIndent${'this'}
$descIndent${'description'}
$descIndent${'line is...'}${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {0} : 0);
          });

          test(
            'renders scrollbar spanning items and description lines',
            () async {
              final future = renderer(
                [
                  const SelectOption('a', description: 'desc line 1\ndesc 2'),
                  'b',
                  'c',
                  'd',
                  'e',
                  'f',
                ],
                inputController.stream,
                sizing: SelectComponentSizing.fixed(
                  totalHeight: 5 + (multiSelect ? 1 : 0),
                ),
              );
              await pumpEventQueue();

              // maxItemLength is 'desc line 1'.length (11).
              // With 5 item/desc lines and 2 description lines on 'a',
              // visibleCount = 3, hoveredDescriptions.length = 2 ->
              // itemAndDescLines = 5.
              // thumbHeight = (3 * 5 / 6).round().clamp(1, 4) = 3.
              expect(mockStdout.terminal.content, '''
>$uBox a                █
$descIndent${'desc line 1'}      █
$descIndent${'desc 2'}           █
 $uBox b                │
 $uBox c                │${maybeLegend()}''');

              inputController.addKeys(List.filled(5, KeyVariants.down));
              inputController.addKey(KeyVariants.space);
              await pumpEventQueue();

              // On 'f' (no description), visibleCount = 5,
              // itemAndDescLines = 5,
              // thumbHeight = (5 * 5 / 6).round().clamp(1, 4) = 4.
              expect(mockStdout.terminal.content, '''
 $uBox b                │
 $uBox c                █
 $uBox d                █
 $uBox e                █
>$sBox f                █${maybeLegend()}''');

              inputController.addKey(KeyVariants.enter);
              expect(await future, multiSelect ? {5} : 5);
            },
          );

          test('deprecated maxVisibleItems computes maxTotalHeight by adding '
              'max description height', () async {
            final options = [
              const SelectOption('a', description: 'desc line 1\ndesc 2'),
              'b',
              'c',
              'd',
              'e',
              'f',
            ];
            final future =
                multiSelect
                    ? showMultiSelectDialog(
                      options,
                      inputController.stream,
                      // ignore: deprecated_member_use_from_same_package
                      maxVisibleItems: 3,
                    )
                    : showSingleSelectDialog(
                      options,
                      inputController.stream,
                      // ignore: deprecated_member_use_from_same_package
                      maxVisibleItems: 3,
                    );
            await pumpEventQueue();

            // maxVisibleItems: 3 + maxDescriptionHeight (2) = maxTotalHeight
            // of 5. On 'a' (2 description lines), 3 items + 2 description
            // lines are rendered (5 item/desc lines).
            expect(mockStdout.terminal.content, '''
>$uBox a                █
$descIndent${'desc line 1'}      █
$descIndent${'desc 2'}           █
 $uBox b                │
 $uBox c                │${maybeLegend()}''');

            inputController.addKey(KeyVariants.down);
            await pumpEventQueue();

            // On 'b' (0 description lines), maxTotalHeight is still 5 so 5
            // items ('a' through 'e') are rendered rather than strictly 3.
            expect(mockStdout.terminal.content, '''
 $uBox a                █
>$uBox b                █
 $uBox c                █
 $uBox d                █
 $uBox e                │${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {1} : 1);
          });

          test('allows ANSI SGR escape sequences and ignores them for '
              'width/wrapping', () async {
            mockStdout.terminalColumns = '> abcdefg'.length + uBox.length;
            final future = renderer([
              const SelectOption(
                '\x1b[31mabcdefg\x1b[0m',
                description: '\x1b[2m1234567\x1b[0m\n\x1b[32mhi there\x1b[0m',
              ),
            ], inputController.stream);
            await pumpEventQueue();

            // 'abcdefg' and '1234567' are 7 visible chars (exact fit),
            // while 'hi there' (8 visible chars) word-wraps to 'hi' and
            // 'there'.
            expect(mockStdout.terminal.content, '''
>$uBox abcdefg
$descIndent${'1234567'}
$descIndent${'hi'}
$descIndent${'there'}${maybeLegend()}''');

            inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
            expect(await future, multiSelect ? {0} : 0);
          });

          test(
            'clamps visible items and descriptions to fit terminalLines',
            () async {
              // 6 terminal lines means at most 5 rendered lines fit (including
              // the legend in multi-select) without scrolling the top item off
              // the viewport even when Sizing.fixed requests a larger
              // totalHeight.
              mockStdout.terminalLines = 6;
              final future = renderer(
                [
                  const SelectOption(
                    'item0',
                    description: 'D1\nD2\nD3\nD4\nD5',
                  ),
                  'item1',
                  'item2',
                  'item3',
                  'item4',
                ],
                inputController.stream,
                sizing: const SelectComponentSizing.fixed(),
              );
              await pumpEventQueue();

              expect(mockStdout.terminal.content.split('\n'), hasLength(5));
              if (multiSelect) {
                // 4 item/desc lines (2 items + 2 description lines) + 1 legend
                // line = 5 total lines.
                expect(mockStdout.terminal.content, '''
>$uBox item0      █
$descIndent${'D1'}         █
$descIndent${'D2...'}      │
 $uBox item1      │
$multiSelectLegend''');
              } else {
                // 5 item/desc lines (3 items + 2 description lines) = 5 total
                // lines.
                expect(mockStdout.terminal.content, '''
>$uBox item0      █
$descIndent${'D1'}         █
$descIndent${'D2...'}      █
 $uBox item1      │
 $uBox item2      │''');
              }

              inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
              expect(await future, multiSelect ? {0} : 0);
            },
          );

          test('SelectComponentSizing.fit sizes dialog from stdout', () async {
            final customStdout =
                MockStdout()
                  ..terminalLines = 7
                  ..terminalColumns = 80;
            await IOOverrides.runZoned(
              () async {
                const fit = SelectComponentSizing.fit();
                // terminalLines (7) - 2 = 5 totalHeight, 5 ~/ 2 = 2
                // maxDescriptionHeight.
                expect(fit.totalHeight, 5);
                expect(fit.maxDescriptionHeight, 2);

                final future = renderer([
                  const SelectOption(
                    'item0',
                    description: 'D1\nD2\nD3\nD4\nD5',
                  ),
                  'item1',
                  'item2',
                  'item3',
                  'item4',
                ], inputController.stream);
                await pumpEventQueue();

                expect(customStdout.terminal.content.split('\n'), hasLength(5));
                if (multiSelect) {
                  // totalHeight (5) includes the legend: 4 item/desc lines +
                  // 1 legend line = 5 total lines.
                  expect(customStdout.terminal.content, '''
>$uBox item0      █
$descIndent${'D1'}         █
$descIndent${'D2...'}      │
 $uBox item1      │
$multiSelectLegend''');
                } else {
                  expect(customStdout.terminal.content, '''
>$uBox item0      █
$descIndent${'D1'}         █
$descIndent${'D2...'}      █
 $uBox item1      │
 $uBox item2      │''');
                }

                inputController.addKeys([KeyVariants.space, KeyVariants.enter]);
                expect(await future, multiSelect ? {0} : 0);

                customStdout.hasTerminal = false;
                expect(fit.totalHeight, 10);
                expect(fit.maxDescriptionHeight, 5);
              },
              stdout: () => customStdout,
              stdin: () => mockStdin,
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
  int terminalLines = 24;

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
  static const selectAll = KeyVariants([
    ByteSequence([1]), // Ctrl+A
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
