  var button = document.getElementById('render');
  var canvas = document.getElementById('canvas');
  var time = document.getElementById('time');
  
  button.addEventListener('click', function (e) {
    canvas.width = parseInt(document.getElementById('imageWidth').value);
    canvas.height = parseInt(document.getElementById('imageHeight').value);
    var start = new Date();
    renderScene(e);
    var stop = new Date();
    time.innerHTML = (stop - start).toString();
  });