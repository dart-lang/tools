[![Build Status](https://github.com/dart-lang/tools/actions/workflows/timing.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/timing.yaml)
[![pub package](https://img.shields.io/pub/v/timing.svg)](https://pub.dev/packages/timing)
[![package publisher](https://img.shields.io/pub/publisher/timing.svg)](https://pub.dev/packages/timing/publisher)

Timing is a simple package for tracking performance of both async and sync actions

## Usage

```dart
var tracker = AsyncTimeTracker();
await tracker.track(() async {
  // some async code here
});

// Use results
print('${tracker.duration} ${tracker.innerDuration} ${tracker.slices}');
```

## Building

Use the following command to re-generate `lib/src/timing.g.dart` file:

```bash
dart run build_runner build
```

## Publishing automation

For information about our publishing automation and release process, see
https://github.com/dart-lang/ecosystem/wiki/Publishing-automation.
