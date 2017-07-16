import 'dart:async';

import 'package:coverage/src/run_and_collect.dart';

Future<Null> main(List<String> args) async {
  Map results = await runAndCollect(args[0], packageRoot: args[1]);
  print(results);
}
