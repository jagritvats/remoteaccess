import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectWebSocket(String url) async {
  final uri = Uri.parse(url);
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return channel;
}
