import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketClient {
  static const _baseUrl = 'ws://localhost:3000';

  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect(String billId, String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('$_baseUrl/ws/bills/$billId?token=$token'),
    );
    _channel!.stream.listen(
      (data) => _controller.add(jsonDecode(data as String)),
      onDone: () => _reconnect(billId, token),
      onError: (_) => _reconnect(billId, token),
    );
  }

  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void _reconnect(String billId, String token) {
    Future.delayed(const Duration(seconds: 2), () => connect(billId, token));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
