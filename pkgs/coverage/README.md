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

The `--pin-isolates` flag is used to prevent isolates from being cleaned up
until coverage has been collected.

#### Collecting coverage from Dartium

    dartium --remote-debugging-port=NNNN
    # execute code in Dartium
    dart bin/collect_coverage.dart --port=NNNN -o coverage.json

#### Formatting coverage data

    dart bin/format_coverage.dart --package-root=app_package_root -i coverage.json

where `app_package_root` is the package-root of the code whose coverage is being
collected. If `--sdk-root` is set, Dart SDK coverage will also be output.
