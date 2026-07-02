# Pub.dev YAML validation tools

A brute force mechanism to assess implications `package:yaml` changes.

1. Fetch and extract all `.yaml` files from all packages on pub.dev:
   ```sh
   dart run tool/pub-validation/fetch_yamls_from_pub_dev.dart
   ```
2. Compare `main` branch against `HEAD` (requires clean git working tree):
   ```sh
   dart run tool/pub-validation/compare_parsers.dart
   ```   

Step (1) will fetch > 80k packages, parse and extract all YAML files, storing
them in `.dart_tool/yaml/pub-dev-yaml-files/<package>.jsonl.gz` (~400 MB).

Step (2) will compile `_jsonl_bulk_parser.dart` from current branch and `main`,
running both on each of the `.jsonl.gz` files comparing the output; writing
differences to `.dart_tool/yaml/comparison/<package_name>.jsonl.gz`, and
printing a summary.

With good internet and decent CPU, step (1) takes 4-5 hours, step (2) 1-2 hours.

------------------------------

If the scripts in this folder breaks horribly in the future, it's fair to simply
delete them.
This is not a super important test, nor one we should run regularly.
