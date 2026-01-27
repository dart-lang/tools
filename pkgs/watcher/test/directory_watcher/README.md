# End to end testing

The `DirectoryWatcher` implementations combine information from OS events and
filesystem polling, which leads to plenty of opportunities for data races
between the two. There are also various data races related to OS event
ordering and batching.

The tests in `end_to_end_tests.dart` protect against both logical errors and
races.

All the tests work the same way: `ClientSimulator` uses a directory watcher to
track the state of a directory, a series of filesystem changes are made in that
directory using `FileChanger`, then `ClientSimulator` compares its inferred
state with the actual state on disk.

File contents vary only by length, so the file contents can be given as a single
number in the logs.

There are three types of error possible:

 - `ClientSimulator` thinks a file exists on disk, but it doesn't; "missing delete event"
 - `ClientSimulator` does not know about a file that exists on disk; "missing add event"
 - `ClientSimulator` knows about a file that exists on disk, but has not read
   it after it was updated, meaning it has a wrong value for its
   contents/length; "missing modify event"

## Example data race

An example sequence of file operations that can cause a data race is moving a
directory then making further modifications inside it. The OS events report the
"new" directory but not its contents, so `DirectoryWatcher` has to list the
contents. The list results and the OS events from subsequent operations can
give contradictory information about the same file, with no way to know which
is more recent and so correct. The implementations created with the help of
these tests aim to detect such ambiguity and resolve it by polling again after
the event arrives.

## Standalone tests

The end to end tests that run on CI include a series of seeded pseudorandom file
operation batches and a set of hardcoded tests that were derived from
interesting random runs. These guard against common data races.

But, they don't run for long enough on CI to give high confidence that there are
no data races.

So, when making changes that might affect data races it is recommended to run
a longer "standalone" end to end test run. This should be done on whichever
platform(s) are affected, Windows, Mac and/or Linux, by running the end to end
test multiple times in parallel and overnight.

```
# Launch in multiple terminals, enough to use 100% CPU.
dart test/directory_watcher/end_to_end_test_runner.dart random

# Or on Linux, install `parallel` and use that to run any number in parallel.
parallel --ungroup --halt now,done=1 \
    -j 100 ::: \
    $(for i in (seq 1 100); do echo 'dart test/directory_watcher/end_to_end_test_runner.dart'; end)
```

Run in this way the test runs until it hits a failure. If it does, it prints
a link to a log which shows a combination of file operations `F`, watcher
internals `W` and the events seen by the `ClientSimulator` marked `C`.
It also prints the seed of the failure, which can be used to run the same
pseudorandom batch of file operations to see if the exact same failure can
be reproduced:

```
dart test/directory_watcher/end_to_end_test_runner.dart seed 42
```

Another way to rerun the exact same sequence of operations that failed is to
copy the failure log into `end_to_end_tests.dart` as a test case. Only the lines
that are file operations marked with `F` are needed. Then run:

```
dart test/directory_watcher/end_to_end_test_runner.dart replay <test name>
```

If a failure can be reproduced in this way then you can try removing
irrelevant-seeming parts of the log until you have a minimal repro case. Note
that a file operation that can't be carried out, for example a move into a
directory that does not exist, is silently skipped over and does nothing.

## False negatives

The standalone end to end tests have one known "false negative" issue, which
is that very occasionally and under heavy load the test might not wait long
enough before deciding that `ClientWatcher` has incorrect state. This can be
noticed in the failure log if all the wrong tracking is about file events at the
end of the run, and with no watcher log entries afterwards. Such failures can
be ignored.

TODO(davidmorgan): detect this automatically and wait longer instead of failing
the test.