import 'dart:html';

import 'package:sse/client/sse_client.dart';

main() {
  var channel = SseClient('/test');

  document.querySelector('button').onClick.listen((_) {
    channel.sink.close();
  });

  channel.stream.listen((s) {
    channel.sink.add(s);
  });
}
