import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

String get _wsBaseUrl {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'ws://10.0.2.2:3000';
  }
  return 'ws://localhost:3000';
}

class SocketClient {
  WebSocketChannel? _channel;
  bool _disconnected = false;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect(String billId, String token) {
    _disconnected = false;
    _channel = WebSocketChannel.connect(
      Uri.parse('$_wsBaseUrl/ws/bills/$billId?token=$token'),
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
    if (_disconnected) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (!_disconnected) connect(billId, token);
    });
  }

  void disconnect() {
    _disconnected = true;
    _channel?.sink.close();
    _channel = null;
  }
}
