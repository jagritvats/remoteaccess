import 'dart:io' as io;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectWebSocket(String url) async {
  final httpClient = io.HttpClient()
    ..badCertificateCallback = (cert, host, port) => true;
  final ws = await io.WebSocket.connect(url, customClient: httpClient);
  return IOWebSocketChannel(ws);
}
