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

    dart --enable-vm-service:NNNN --pin-isolates script.dart
    dart bin/collect_coverage.dart --port=NNNN -o coverage.json --unpin-isolates

The `--pin-isolates` VM flag is used to prevent isolates from being cleaned up
until coverage has been collected. `collect_coverage.dart` can be invoked before
the VM from which coverage is to be collected, and will wait until it detects
a VM observatory port. An optional `--connect-timeout` may be specified in
in seconds.

#### Collecting coverage from Dartium

    dartium --remote-debugging-port=NNNN
    # execute code in Dartium
    dart bin/collect_coverage.dart --port=NNNN -o coverage.json

As noted above, `collect_coverage.dart` may be invoked before Dartium, in which
case it will wait until it detects a Dartium remote debugging port, up to the
(optional) timeout.

#### Formatting coverage data

    dart bin/format_coverage.dart --package-root=app_package_root -i coverage.json

where `app_package_root` is the package-root of the code whose coverage is being
collected. If `--sdk-root` is set, Dart SDK coverage will also be output.
