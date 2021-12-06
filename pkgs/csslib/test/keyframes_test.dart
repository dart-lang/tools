library extend_test;

import 'package:csslib/src/messages.dart';
import 'package:test/test.dart';

import 'testing.dart';

void compileAndValidate(String input, String generated) {
  var errors = <Message>[];
  var stylesheet = compileCss(input, errors: errors, opts: options);
  expect(errors.isEmpty, true, reason: errors.toString());
  expect(prettyPrint(stylesheet), generated);
}

void singleKeyframesList() {
  compileAndValidate(r'''
@keyframes ping {
  75%, 100% {
    transform: scale(2);
    opacity: 0;
  }
}''', r'''
@keyframes ping {
  75%, 100% {
  transform: scale(2);
  opacity: 0;
  }
}''');
}

void keyframesList() {
  compileAndValidate(r'''
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
@-webkit-keyframes ping {
  75%, 100% {
    transform: scale(2);
    opacity: 0;
  }
}
@keyframes ping {
  75%, 100% {
    transform: scale(2);
    opacity: 0;
  }
}
@-webkit-keyframes pulse {
  50% {
    opacity: 0.5;
  }
}
@keyframes pulse {
  50% {
    opacity: 0.5;
  }
}
@-webkit-keyframes bounce {
  0%, 100% {
    transform: translateY(-25%);
    -webkit-animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
    animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
  }
  50% {
    transform: none;
    -webkit-animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
    animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
  }
}
@keyframes bounce {
  0%, 100% {
    transform: translateY(-25%);
    -webkit-animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
    animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
  }
  50% {
    transform: none;
    -webkit-animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
    animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
  }
}
''', r'''
@keyframes spin {
  to {
  transform: rotate(360deg);
  }
}
@-webkit-keyframes ping {
  75%, 100% {
  transform: scale(2);
  opacity: 0;
  }
}
@keyframes ping {
  75%, 100% {
  transform: scale(2);
  opacity: 0;
  }
}
@-webkit-keyframes pulse {
  50% {
  opacity: 0.5;
  }
}
@keyframes pulse {
  50% {
  opacity: 0.5;
  }
}
@-webkit-keyframes bounce {
  0%, 100% {
  transform: translateY(-25%);
  -webkit-animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
  animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
  }
  50% {
  transform: none;
  -webkit-animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
  animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
  }
}
@keyframes bounce {
  0%, 100% {
  transform: translateY(-25%);
  -webkit-animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
  animation-timing-function: cubic-bezier(0.8, 0, 1, 1);
  }
  50% {
  transform: none;
  -webkit-animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
  animation-timing-function: cubic-bezier(0, 0, 0.2, 1);
  }
}''');
}

void main() {
  test('Single Keyframes List', singleKeyframesList);
  test('Keyframes List', keyframesList);
}
