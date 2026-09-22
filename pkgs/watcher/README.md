[![Build Status](https://github.com/dart-lang/tools/actions/workflows/watcher.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/watcher.yaml)
[![pub package](https://img.shields.io/pub/v/watcher.svg)](https://pub.dev/packages/watcher)
[![package publisher](https://img.shields.io/pub/publisher/watcher.svg)](https://pub.dev/packages/watcher/publisher)

A file system watcher.

## What's this?

`package:watcher` monitors changes to contents of directories and sends
notifications when files have been added, removed, or modified.

## What you can rely on

Events converge on the state of the filesystem. If you apply them to a model of
the watched paths then, once changes stop, your model matches what is on disk.
That is the guarantee, and it is what the tests check: they apply random series
of file operations and require the state rebuilt from events to match the state
on disk.

There is deliberately no guarantee of one event per change. Platform
notifications are batched, and arrive in an order that often does not determine
what happened, so watchers resolve them by reading the paths involved. A path
that is deleted and written again between reads is reported as a single
modification; a path that is created and deleted may produce no event at all.

So, use an event to learn that a path is worth looking at, and read the path to
learn what it now contains. Code that counts events, pairs them up, or waits for
a particular event to arrive is relying on something this package does not
promise, and will fail intermittently on some platforms.
