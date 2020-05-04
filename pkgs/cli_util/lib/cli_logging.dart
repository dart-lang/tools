// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This library contains functionality to help command-line utilities to easily
/// create aesthetic output.
library cli_logging;

import 'dart:async';
import 'dart:io' as io;

/// A small utility class to make it easier to work with common ANSI escape
/// sequences.
class Ansi {
  /// Return whether the current stdout terminal supports ANSI escape sequences.
  static bool get terminalSupportsAnsi {
    return io.stdout.supportsAnsiEscapes &&
        io.stdioType(io.stdout) == io.StdioType.terminal;
  }

  final bool useAnsi;

  Ansi(this.useAnsi);

  String get cyan => _code('\u001b[36m');

  String get green => _code('\u001b[32m');

  String get magenta => _code('\u001b[35m');

  String get red => _code('\u001b[31m');

  String get yellow => _code('\u001b[33m');

  String get blue => _code('\u001b[34m');

  String get gray => _code('\u001b[1;30m');

  String get noColor => _code('\u001b[39m');

  String get none => _code('\u001b[0m');

  String get bold => _code('\u001b[1m');

  String get reversed => _code('\u001b[7m');

  String get backspace => '\b';

  String get bullet => io.stdout.supportsAnsiEscapes ? '•' : '-';

  /// Display [message] in an emphasized format.
  String emphasized(String message) => '$bold$message$none';

  /// Display [message] in an subtle (gray) format.
  String subtle(String message) => '$gray$message$none';

  /// Display [message] in an error (red) format.
  String error(String message) => '$red$message$none';

  String _code(String ansiCode) => useAnsi ? ansiCode : '';
}

/// An abstract representation of a [Logger] - used to pretty print errors,
/// standard status messages, trace level output, and indeterminate progress.
abstract class Logger {
  /// Create a normal [Logger]; this logger will not display trace level output.
  factory Logger.standard({Ansi ansi}) => new StandardLogger(ansi: ansi);

  /// Create a [Logger] that will display trace level output.
  ///
  /// If [logTime] is `true`, this logger will display the time of the message.
  factory Logger.verbose({Ansi ansi, bool logTime: true}) {
    return new VerboseLogger(ansi: ansi, logTime: logTime);
  }

  Ansi get ansi;

  bool get isVerbose;

  /// Print an error message.
  void stderr(String message);

  /// Print a standard status message.
  void stdout(String message);

  /// Print trace output.
  void trace(String message);

  /// Start an indeterminate progress display.
  Progress progress(String message);

  /// Flush any un-written output.
  @Deprecated('This method will be removed in the future')
  void flush();
}

/// A handle to an indeterminate progress display.
abstract class Progress {
  final String message;
  final Stopwatch _stopwatch;

  Progress(this.message) : _stopwatch = new Stopwatch()..start();

  Duration get elapsed => _stopwatch.elapsed;

  /// Finish the indeterminate progress display.
  void finish({String message, bool showTiming});

  /// Cancel the indeterminate progress display.
  void cancel();
}

class StandardLogger implements Logger {
  Ansi ansi;

  StandardLogger({this.ansi}) {
    ansi ??= new Ansi(Ansi.terminalSupportsAnsi);
  }

  bool get isVerbose => false;

  Progress _currentProgress;

  void stderr(String message) {
    if (_currentProgress != null) {
      Progress progress = _currentProgress;
      _currentProgress = null;
      progress.cancel();
    }

    io.stderr.writeln(message);
  }

  void stdout(String message) {
    if (_currentProgress != null) {
      Progress progress = _currentProgress;
      _currentProgress = null;
      progress.cancel();
    }

    print(message);
  }

  void trace(String message) {}

  Progress progress(String message) {
    if (_currentProgress != null) {
      Progress progress = _currentProgress;
      _currentProgress = null;
      progress.cancel();
    }

    Progress progress = ansi.useAnsi
        ? new AnsiProgress(ansi, message)
        : new SimpleProgress(this, message);
    _currentProgress = progress;
    return progress;
  }

  @Deprecated('This method will be removed in the future')
  void flush() {}
}

class SimpleProgress extends Progress {
  final Logger logger;

  SimpleProgress(this.logger, String message) : super(message) {
    logger.stdout('$message...');
  }

  @override
  void cancel() {}

  @override
  void finish({String message, bool showTiming}) {}
}

class AnsiProgress extends Progress {
  static const List<String> kAnimationItems = const ['/', '-', '\\', '|'];

  final Ansi ansi;

  int _index = 0;
  Timer _timer;

  AnsiProgress(this.ansi, String message) : super(message) {
    io.stdout.write('${message}...  '.padRight(40));

    _timer = new Timer.periodic(new Duration(milliseconds: 80), (t) {
      _index++;
      _updateDisplay();
    });

    _updateDisplay();
  }

  @override
  void cancel() {
    if (_timer.isActive) {
      _timer.cancel();
      _updateDisplay(cancelled: true);
    }
  }

  @override
  void finish({String message, bool showTiming: false}) {
    if (_timer.isActive) {
      _timer.cancel();
      _updateDisplay(isFinal: true, message: message, showTiming: showTiming);
    }
  }

  void _updateDisplay(
      {bool isFinal: false,
      bool cancelled: false,
      String message,
      bool showTiming: false}) {
    String char = kAnimationItems[_index % kAnimationItems.length];
    if (isFinal || cancelled) {
      char = '';
    }
    io.stdout.write('${ansi.backspace}${char}');
    if (isFinal || cancelled) {
      if (message != null) {
        io.stdout.write(message.isEmpty ? ' ' : message);
      } else if (showTiming) {
        String time = (elapsed.inMilliseconds / 1000.0).toStringAsFixed(1);
        io.stdout.write('${time}s');
      } else {
        io.stdout.write(' ');
      }
      io.stdout.writeln();
    }
  }
}

class VerboseLogger implements Logger {
  Ansi ansi;
  bool logTime;
  Stopwatch _timer;

  VerboseLogger({this.ansi, this.logTime}) {
    ansi ??= new Ansi(Ansi.terminalSupportsAnsi);
    logTime ??= false;

    _timer = new Stopwatch()..start();
  }

  bool get isVerbose => true;

  void stdout(String message) {
    io.stdout.writeln('${_createPrefix()}$message');
  }

  void stderr(String message) {
    io.stderr.writeln('${_createPrefix()}${ansi.red}$message${ansi.none}');
  }

  void trace(String message) {
    io.stdout.writeln('${_createPrefix()}${ansi.gray}$message${ansi.none}');
  }

  Progress progress(String message) => new SimpleProgress(this, message);

  @Deprecated('This method will be removed in the future')
  void flush() {}

  String _createPrefix() {
    if (!logTime) {
      return '';
    }

    double seconds = _timer.elapsedMilliseconds / 1000.0;
    int minutes = seconds ~/ 60;
    seconds -= minutes * 60.0;

    StringBuffer buf = new StringBuffer();
    if (minutes > 0) {
      buf.write((minutes % 60));
      buf.write('m ');
    }

    buf.write(seconds.toStringAsFixed(3).padLeft(minutes > 0 ? 6 : 1, '0'));
    buf.write('s');

    return '[${buf.toString().padLeft(11)}] ';
  }
}
