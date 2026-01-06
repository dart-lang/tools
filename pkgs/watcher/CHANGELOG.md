## 1.2.1

- Bug fix: versions before 1.2.0 would allow and ignore a trailing path
  separator passed to `DirectoryWatcher` or `FileWatcher` constructors, restore
  that behavior.
- In paths passed to `DirectoryWatcher` or `FileWatcher` constructors, remove
  multiple adjacent separators and `.` and `..`, so they will not be returned in
  events.
- Bug fix: on Mac, stop issuing `assert(false)` when a `modifyDirectory` event
  is ignored, so the unused events are silently ignored instead of throwing in
  debug builds.

## 1.2.0

- Polling watchers now check file sizes as well as "last modified" times, so
  they are less likely to miss changes on platforms with low resolution
  timestamps.
- `DirectoryWatcher` on Windows performance: reduce 100ms buffering of events
  before reporting to 5ms, the larger buffer isn't needed for correctness after
  the various fixes.
- `DirectoryWatcher` on Windows watches in a separate Isolate to make buffer
  exhaustion, "Directory watcher closed unexpectedly", much less likely. The old
  implementation which does not use a separate Isolate is available as
  `DirectoryWatcher(path, runInIsolateOnWindows: false)`.
- `DirectoryWatcher` on Windows: if buffer exhaustion does happen, emit a
  "modify" event for all know files instead of an exception.
- Document behavior on Linux if the system watcher limit is hit.
- Require Dart SDK `^3.4.0`.
- Bug fix: native `DirectoryWatcher` implementations now consistently handle
  links as files, instead of sometimes reading through them and sometimes
  reporting them as files. The polling `DirectoryWatcher` still reads through
  links.
- Bug fix: with the polling `DirectoryWatcher`, fix spurious modify event
  emitted because of a file delete during polling.
- Bug fix: due to the link handling change, native `DirectoryWatcher` on Linux
  and MacOS is no longer affected by a severe performance regression if there
  are symlink loops in the watched directory. The polling `DirectoryWatcher`
  is fixed to skip already-visited directories to prevent the performance issue
  while still reading through links.
- Bug fix: with `DirectoryWatcher` on Windows, the last of a rapid sequence of
  modifications in a newly-created directory was sometimes dropped. Make it
  reliably report the last modification.
- Bug fix: with `DirectoryWatcher` on Windows, a move over an existing file was
  reported incorrectly. For example, if `a` and `b` already exist, then `a` is
  moved onto `b`, it would be reported as three events: delete `a`, delete `b`,
  create `b`. Now it's reported as two events: delete `a`, modify `b`. This
  matches the behavior of the Linux and MacOS watchers.
- Bug fix: with `DirectoryWatcher` on Windows, new links to directories were
  sometimes incorrectly handled as actual directories. Now they are reported
  as files, matching the behavior of the Linux and MacOS watchers.
- Bug fix: unify `DirectoryWatcher` implementation on Windows with the MacOS
  implementation, addressing various race conditions around directory renames.
- Bug fix: new `DirectoryWatcher` implementation on Linux that fixes various
  issues: tracking failure following subdirectory move, incorrect events when
  there are changes in a recently-moved subdirectory, incorrect events due to
  various situations involving subdirectory moves.
- Bug fix: new `DirectoryWatcher` implementation on MacOS that fixes various
  issues including duplicate events for changes in new directories, incorrect
  events when close together directory renames have overlapping names.
- Bug fix: with `FileWatcher` on MacOS, a modify event was sometimes reported if
  the file was created immediately before the watcher was created. Now, if the
  file exists when the watcher is created then this modify event is not sent.
  This matches the Linux native and polling (Windows) watchers.

## 1.1.4

- Improve handling of subdirectories: ignore `PathNotFoundException` due to
  subdirectory deletion racing with watcher internals, instead of raising
  it on the event stream.
- Improve handling of watcher overflow on Windows: prepare for future versions
  of SDK, which will properly forward `FileSystemException` into the stream
  returned by the watcher.

## 1.1.3

- Improve handling of
  `FileSystemException: Directory watcher closed unexpectedly` on Windows. The
  watcher was already attempting to restart after this error and resume sending
  events. But, the restart would sometimes silently fail. Now, it is more
  reliable.
- Improving handling of directories that are created then immediately deleted on
  Windows. Previously, that could cause a `PathNotFoundException` to be thrown.

## 1.1.2

- Fix a bug on Windows where a file creation event could be reported twice when creating
  a file recursively in a non-existent directory.

## 1.1.1

- Ensure `PollingFileWatcher.ready` completes for files that do not exist.
- Require Dart SDK `^3.1.0`
- Move to `dart-lang/tools` monorepo.

## 1.1.0

- Require Dart SDK >= 3.0.0
- Remove usage of redundant ConstructableFileSystemEvent classes.

## 1.0.3-dev

- Require Dart SDK >= 2.19

## 1.0.2

- Require Dart SDK >= 2.14
- Ensure `DirectoryWatcher.ready` completes even when errors occur that close the watcher.
- Add markdown badges to the readme.

## 1.0.1

* Drop package:pedantic and use package:lints instead.

## 1.0.0

* Require Dart SDK >= 2.12
* Add the ability to create custom Watcher types for specific file paths.

## 0.9.7+15

* Fix a bug on Mac where modifying a directory with a path exactly matching a
  prefix of a modified file would suppress change events for that file.

## 0.9.7+14

* Prepare for breaking change in SDK where modified times for not found files
  becomes meaningless instead of null.

## 0.9.7+13

* Catch & forward `FileSystemException` from unexpectedly closed file watchers
  on windows; the watcher will also be automatically restarted when this occurs.

## 0.9.7+12

* Catch `FileSystemException` during `existsSync()` on Windows.
* Internal cleanup.

## 0.9.7+11

* Fix an analysis hint.

## 0.9.7+10

* Set max SDK version to `<3.0.0`, and adjust other dependencies.

## 0.9.7+9

* Internal changes only.

## 0.9.7+8

* Fix Dart 2.0 type issues on Mac and Windows.

## 0.9.7+7

* Updates to support Dart 2.0 core library changes (wave 2.2).
  See [issue 31847][sdk#31847] for details.

  [sdk#31847]: https://github.com/dart-lang/sdk/issues/31847


## 0.9.7+6

* Internal changes only, namely removing dep on scheduled test.

## 0.9.7+5

* Fix an analysis warning.

## 0.9.7+4

* Declare support for `async` 2.0.0.

## 0.9.7+3

* Fix a crashing bug on Linux.

## 0.9.7+2

* Narrow the constraint on `async` to reflect the APIs this package is actually
  using.

## 0.9.7+1

* Fix all strong-mode warnings.

## 0.9.7

* Fix a bug in `FileWatcher` where events could be added after watchers were
  closed.

## 0.9.6

* Add a `Watcher` interface that encompasses watching both files and
  directories.

* Add `FileWatcher` and `PollingFileWatcher` classes for watching changes to
  individual files.

* Deprecate `DirectoryWatcher.directory`. Use `DirectoryWatcher.path` instead.

## 0.9.5

* Fix bugs where events could be added after watchers were closed.

## 0.9.4

* Treat add events for known files as modifications instead of discarding them
  on Mac OS.

## 0.9.3

* Improved support for Windows via `WindowsDirectoryWatcher`.

* Simplified `PollingDirectoryWatcher`.

* Fixed bugs in `MacOSDirectoryWatcher`
