Coverage
========

Coverage provides coverage data collection, manipulation, and formatting for
Dart.

Tools
-----
`format_coverage.dart` formats coverage JSON collected from the Dart VM. It
supports [LCOV](http://ltp.sourceforge.net/coverage/lcov.php) and pretty-print
output. Coverage can be obtained from Dart VM using the VM's
`--coverage-dir=/output/dir` flag, or from Dartium using `collect_coverage.dart`
from this package.

`collect_coverage.dart` collects coverage JSON from Dartium running with the
`--remote-debugging-port=NNNN` flag.
