var Benchmark = {
  measureFor: function(f, timeMinimum) {
    var elapsed = 0;
    var iterations = 0;
    var start = new Date();
    while (elapsed < timeMinimum) {
      iterations++;
      f();
      elapsed = new Date() - start;
    }
    return 1000 * elapsed / iterations;
  },

  measure: function(warmup, exercise) {
    if (!exercise) {
      exercise = function() {
        for (var i = 0; i < 10; i++) {
          warmup();
        }
      };
    }
    this.measureFor(warmup, 100);
    return this.measureFor(exercise, 2000);
  },

  report: function(name, warmup, exercise) {
    var score = this.measure(warmup, exercise);
    print(name + "(RunTime): " + score + " us.");
  }
};
