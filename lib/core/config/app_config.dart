import 'package:flutter/foundation.dart';

/// 全局配置：API / WebSocket / Solana 网络 / 超时。
/// 可用 `--dart-define=API_BASE_URL=...` 等覆盖。
/// 链上 RPC 请使用 [SolanaRpcService]（App 专用 /solana/rpc/app 代理）。
class AppConfig {
  AppConfig._();

  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kDebugMode) return 'http://10.0.2.2:8000/api/v1';
    return 'https://api.sinpra.co/api/v1';
  }

  static String get wsUrl {
    const fromEnv = String.fromEnvironment('WS_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kDebugMode) return 'ws://10.0.2.2:8000/ws/client';
    return 'wss://api.sinpra.co/ws/client';
  }

  /// Solana 网络：devnet / mainnet-beta
  static const String solanaNetwork = String.fromEnvironment(
    'SOLANA_NETWORK',
    defaultValue: 'mainnet-beta',
  );

  static bool get isDevnet => solanaNetwork != 'mainnet-beta';

  static const Duration connectTimeout = Duration(seconds: 25);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration wsReconnectDelay = Duration(seconds: 3);
  static const int wsMaxReconnectAttempts = 5;
}
