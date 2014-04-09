Coverage
========

Coverage provides coverage data collection, manipulation, and formatting for
Dart.

Tools
-----
`collect_coverage.dart` collects coverage JSON from the Dart VM Observatory.
`format_coverage.dart` formats JSON coverage data into either
[LCOV](http://ltp.sourceforge.net/coverage/lcov.php) or pretty-printed format.

#### Collecting coverage from the VM

    dart --enable-vm-service:NNNN --pause_isolates_on_exit script.dart
    dart bin/collect_coverage.dart --port=NNNN -o coverage.json --resume-isolates

The `--pause_isolates_on_exit` VM flag is used to pause isolates on exit to
allow coverage to be collected. If `collect_coverage.dart` is invoked before
the script from which coverage is to be collected, it will wait until it
detects a VM observatory port to which it can connect. An optional
`--connect-timeout` may be specified (in seconds). When collecting coverage from
a VM run with the `--pause_isolates_on_exit` flag set, the `--wait-paused` flag
may be enabled, causing `collect_coverage.dart` to wait until all isolates are
paused before collecting coverage.

#### Collecting coverage from Dartium

    dartium --remote-debugging-port=NNNN
    # execute code in Dartium
    dart bin/collect_coverage.dart --port=NNNN -o coverage.json

As noted above, `collect_coverage.dart` may be invoked before Dartium, in which
case it will wait until it detects a Dartium remote debugging port, up to the
(optional) timeout. Note that coverage cannot be run against a Dartium instance
launched from Dart Editor, since the editor makes use of Dartium's remote
debugging port.

#### Formatting coverage data

    dart bin/format_coverage.dart --package-root=app_package_root -i coverage.json

where `app_package_root` is the package-root of the code whose coverage is being
collected. If `--sdk-root` is set, Dart SDK coverage will also be output.
