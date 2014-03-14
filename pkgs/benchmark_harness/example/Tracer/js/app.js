(function() {

  var button = document.getElementById('render');
  var canvas = document.getElementById('canvas');
  var time = document.getElementById('time');

  var run = function(e) {
    canvas.width = parseInt(document.getElementById('imageWidth').value);
    canvas.height = parseInt(document.getElementById('imageHeight').value);
    canvas.getContext("2d").clearRect(0,0,canvas.width,canvas.height)
    var start = performance.now();
    renderScene(e);
    var stop = performance.now();
    time.innerHTML = Number(stop - start).toFixed(2).toString();
  };
  button.addEventListener('click', run);
})();
