import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';

void main() {
  final errors = <Message>[];
  final sheet = parse('''
.a { color: red; }
@media (width <= 480px) { .b { color: green; } }
.c { color: blue; }
''', errors: errors);

  for (final node in sheet.topLevels) {
    print(node is RuleSet ? 'RuleSet ${node.selectorGroup?.span?.text}' : node);
  }
  for (final error in errors) {
    print(error.message);
  }
}
