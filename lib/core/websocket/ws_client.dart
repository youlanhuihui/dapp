import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sinpra_app/core/config/app_config.dart';

/// WebSocket 客户端：连接 / 重连 / 事件分发。
/// 机制层复用自已跑通的 IM 工程。
class WSClient {
  WebSocketChannel? _channel;
  final String url;
  String? _token;
  final Map<String, List<Function(Map<String, dynamic>)>> _listeners = {};
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  StreamSubscription? _subscription;

  WSClient({required this.url});

  bool get isConnected => _isConnected;

  void setToken(String token) {
    _token = token;
  }

  void connect() {
    final connectUrl = _token != null ? '$url?token=$_token' : url;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(connectUrl));
      _isConnected = true;
      _reconnectAttempts = 0;
      _subscription = _channel!.stream.listen(
        (data) => _handleMessage(data),
        onDone: () {
          _isConnected = false;
          _attemptReconnect();
        },
        onError: (error) {
          _isConnected = false;
          _attemptReconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
      _attemptReconnect();
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void on(String eventType, Function(Map<String, dynamic>) callback) {
    _listeners.putIfAbsent(eventType, () => []);
    _listeners[eventType]!.add(callback);
  }

  void off(String eventType, Function(Map<String, dynamic>) callback) {
    _listeners[eventType]?.remove(callback);
  }

  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _handleMessage(dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      final eventType = (data['event_type'] ?? data['type']) as String?;
      if (eventType != null && _listeners.containsKey(eventType)) {
        for (final cb in _listeners[eventType]!) {
          cb(data);
        }
      }
      if (_listeners.containsKey('*')) {
        for (final cb in _listeners['*']!) {
          cb(data);
        }
      }
    } catch (_) {}
  }

  void _attemptReconnect() {
    if (_reconnectAttempts >= AppConfig.wsMaxReconnectAttempts) return;
    _reconnectAttempts++;
    _reconnectTimer = Timer(
      AppConfig.wsReconnectDelay * _reconnectAttempts,
      () => connect(),
    );
  }
}
