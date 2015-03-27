void main() {
  for (var i = 0; i < 10; i++) {
    for (var j = 0; j < 10; j++) {
      var sum = usedMethod(i, j);
      if (sum != (i + j)) {
        throw 'bad method!';
      }
    }
  }
}

int usedMethod(int a, int b) {
  return a + b;
}

int unusedMethod(int a, int b) {
  return a - b;
}
