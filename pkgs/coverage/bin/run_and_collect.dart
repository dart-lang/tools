import 'package:coverage/src/run_and_collect.dart';

main(List<String> args) async {
  Map results = await runAndCollect(args[0], packageRoot: args[1]);
  print(results);
}
