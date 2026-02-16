// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:io/ansi.dart';

/// Prints a sample of all of the `AnsiCode` values.
void main(List<String> args) {
  final forScript = args.contains('--for-script');

  if (!ansiOutputEnabled) {
    print('`ansiOutputEnabled` is `false`.');
    print("Don't expect pretty output.");
  }
  _preview('Foreground', foregroundColors, forScript);
  _preview('Background', backgroundColors, forScript);
  _preview('Styles', styles, forScript);
  _preview('Rgb', [rgb(255, 0, 0), rgb(0, 255, 0), rgb(0, 0, 255)], forScript);
  _gradient('** Gradient Text Sample **', forScript);
}

void _gradient(String text, bool forScript) {
  final length = text.length;
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    final ratio = i / (length - 1);
    int red, green, blue;
    if (ratio < .5) {
      red = ((1 - (ratio * 2)) * 255).round();
      green = (ratio * 2 * 255).round();
      blue = 0;
    } else {
      red = 0;
      green = ((1 - ((ratio - .5) * 2)) * 255).round();
      blue = (((ratio - .5) * 2) * 255).round();
    }
    buffer.write(rgb(red, green, blue).wrap(text[i], forScript: forScript));
  }
  print(buffer.toString());
}

void _preview(String name, List<AnsiCode> values, bool forScript) {
  print('');
  final longest = values.map((ac) => ac.name.length).reduce(max);

  print(wrapWith('** $name **', [styleBold, styleUnderlined]));
  for (var code in values) {
    final header =
        '${code.name.padRight(longest)} ${code.code.toString().padLeft(3)}';

    print("$header: ${code.wrap('Sample', forScript: forScript)}");
  }
}
