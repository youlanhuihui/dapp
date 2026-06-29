import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';

import '../config/app_config.dart';

class RpcPreset {
  final String label;
  final String url;
  final bool recommended;
  const RpcPreset(this.label, this.url, {this.recommended = false});
}

class RpcTestResult {
  final bool ok;
  final int ms;
  final String detail;
  const RpcTestResult({required this.ok, required this.ms, required this.detail});
}

class KnownToken {
  final String mint;
  final String symbol;
  final String name;
  final int decimals;
  const KnownToken({
    required this.mint,
    required this.symbol,
    required this.name,
    required this.decimals,
  });
}

class TokenBalanceItem {
  final String? mint;
  final String symbol;
  final String name;
  final double uiAmount;
  final String rawAmount;
  final int decimals;
  const TokenBalanceItem({
    required this.mint,
    required this.symbol,
    required this.name,
    required this.uiAmount,
    required this.rawAmount,
    required this.decimals,
  });
}

/// 轻量 Solana JSON-RPC：多节点 failover + 余额读取（与 Web rpc-selector 对齐）。
class SolanaRpcService extends ChangeNotifier {
  SolanaRpcService._();
  static final SolanaRpcService instance = SolanaRpcService._();

  static const _tokenProgramId =
      'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  static const _storage = FlutterSecureStorage();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'content-type': 'application/json'},
  ));

  static String get _network =>
      AppConfig.isDevnet ? 'devnet' : 'mainnet-beta';

  static String get _storageKey => 'sinpra_rpc_url_$_network';

  static String get proxyUrl =>
      '${AppConfig.apiBaseUrl}/solana/rpc?network=$_network';

  /// App 专用代理（服务端上游可配 Alchemy，Key 不暴露给客户端）。
  static String get appProxyUrl =>
      '${AppConfig.apiBaseUrl}/solana/rpc/app?network=$_network';

  static bool isSinpraProxy(String url) => url.contains('/solana/rpc');

  /// 构建 SolanaClient；SINPRA 代理仅走 HTTP JSON-RPC，不尝试 WSS。
  static SolanaClient createClient(String url) {
    final uri = Uri.parse(url);
    final ws = isSinpraProxy(url)
        ? uri
        : Uri.parse(
            url.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://'),
          );
    return SolanaClient(rpcUrl: uri, websocketUrl: ws);
  }

  static List<RpcPreset> get presets {
    if (AppConfig.isDevnet) {
      return [
        RpcPreset('SINPRA App 节点（推荐）', appProxyUrl, recommended: true),
        RpcPreset('SINPRA Web 节点', proxyUrl),
        const RpcPreset('Solana 官方 Devnet', 'https://api.devnet.solana.com'),
      ];
    }
    return [
      RpcPreset('SINPRA App 节点（推荐）', appProxyUrl, recommended: true),
      RpcPreset('SINPRA Web 节点', proxyUrl),
      const RpcPreset(
          'PublicNode（公共 · 免 Key）', 'https://solana-rpc.publicnode.com'),
      const RpcPreset('Solana 官方节点', 'https://api.mainnet-beta.solana.com'),
    ];
  }

  String? _selectedUrl;
  String? _activeUrl;

  String? get selectedUrl => _selectedUrl;
  String? get activeUrl => _activeUrl;

  String get defaultUrl {
    if (_selectedUrl?.trim().isNotEmpty == true) return _selectedUrl!.trim();
    return presets
        .firstWhere((p) => p.recommended, orElse: () => presets.first)
        .url;
  }

  String labelForUrl(String url) {
    for (final p in presets) {
      if (p.url == url) return p.label.split('（').first.trim();
    }
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url.length > 24 ? url.substring(0, 24) : url;
    }
  }

  Future<void> loadSelected() async {
    _selectedUrl = await _storage.read(key: _storageKey);
    notifyListeners();
  }

  Future<void> saveSelected(String url) async {
    final trimmed = url.trim();
    _selectedUrl = trimmed.isEmpty ? null : trimmed;
    if (_selectedUrl == null) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: _selectedUrl);
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> _rpcCall(
    String url,
    String method,
    List<dynamic> params,
  ) async {
    final res = await _dio.post(url, data: {
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params,
    });
    final body = res.data;
    if (body is Map<String, dynamic>) {
      if (body['error'] != null) throw Exception(body['error'].toString());
      return body;
    }
    throw Exception('Unexpected RPC response');
  }

  Future<RpcTestResult> testRpc(String url, {String? ownerAddress}) async {
    final start = DateTime.now();
    try {
      await _rpcCall(url, 'getLatestBlockhash', [
        {'commitment': 'confirmed'}
      ]);
    } catch (_) {
      return RpcTestResult(
        ok: false,
        ms: DateTime.now().difference(start).inMilliseconds,
        detail: '无法连接节点（限流或网络不通）',
      );
    }
    if (ownerAddress != null && ownerAddress.isNotEmpty) {
      try {
        await _rpcCall(url, 'getBalance', [
          ownerAddress,
          {'commitment': 'confirmed'}
        ]);
      } catch (_) {
        return RpcTestResult(
          ok: false,
          ms: DateTime.now().difference(start).inMilliseconds,
          detail: '节点连通，但无法读取余额',
        );
      }
    }
    final ms = DateTime.now().difference(start).inMilliseconds;
    return RpcTestResult(
      ok: true,
      ms: ms,
      detail: '连接正常 · ${ms}ms',
    );
  }

  List<String> _candidates(String? preferred) {
    final out = <String>[];
    void add(String? u) {
      final t = u?.trim();
      if (t != null && t.isNotEmpty && !out.contains(t)) out.add(t);
    }

    add(preferred);
    add(_selectedUrl);
    for (final p in presets) {
      add(p.url);
    }
    return out;
  }

  Future<List<TokenBalanceItem>> listBalances(
    String owner, {
    String? preferredUrl,
    List<KnownToken> known = const [],
  }) async {
    final knownMap = {for (final k in known) k.mint: k};
    Object? lastErr;

    for (final url in _candidates(preferredUrl)) {
      try {
        final out = <TokenBalanceItem>[];
        final seen = <String>{};

        final balRes = await _rpcCall(url, 'getBalance', [
          owner,
          {'commitment': 'confirmed'}
        ]);
        final lamports = (balRes['result']?['value'] as num?)?.toInt() ?? 0;
        out.add(TokenBalanceItem(
          mint: null,
          symbol: 'SOL',
          name: 'Solana',
          uiAmount: lamports / 1e9,
          rawAmount: lamports.toString(),
          decimals: 9,
        ));

        final resp = await _rpcCall(url, 'getTokenAccountsByOwner', [
          owner,
          {'programId': _tokenProgramId},
          {'encoding': 'jsonParsed', 'commitment': 'confirmed'}
        ]);
        final list = (resp['result']?['value'] as List?) ?? [];
        for (final acc in list) {
          final item = _parseTokenAccount(acc, knownMap);
          if (item != null) {
            out.add(item);
            seen.add(item.mint!);
          }
        }

        for (final k in known) {
          if (seen.contains(k.mint)) continue;
          try {
            final r = await _rpcCall(url, 'getTokenAccountsByOwner', [
              owner,
              {'mint': k.mint},
              {'encoding': 'jsonParsed', 'commitment': 'confirmed'}
            ]);
            final l = (r['result']?['value'] as List?) ?? [];
            for (final acc in l) {
              final item = _parseTokenAccount(acc, knownMap);
              if (item != null) out.add(item);
            }
          } catch (_) {}
        }

        _activeUrl = url;
        notifyListeners();
        return out;
      } catch (e) {
        lastErr = e;
      }
    }
    throw Exception(lastErr?.toString() ?? '所有节点均不可用');
  }

  TokenBalanceItem? _parseTokenAccount(
    dynamic acc,
    Map<String, KnownToken> knownMap,
  ) {
    try {
      final info =
          acc['account']?['data']?['parsed']?['info'] as Map<String, dynamic>?;
      if (info == null) return null;
      final mint = info['mint'] as String?;
      if (mint == null) return null;
      final tokenAmount = info['tokenAmount'] as Map<String, dynamic>?;
      if (tokenAmount == null) return null;
      final ui = (tokenAmount['uiAmount'] as num?)?.toDouble() ?? 0.0;
      final raw = tokenAmount['amount']?.toString() ?? '0';
      final decimals = (tokenAmount['decimals'] as num?)?.toInt() ?? 0;
      final meta = knownMap[mint];
      return TokenBalanceItem(
        mint: mint,
        symbol: meta?.symbol ?? _shortMint(mint),
        name: meta?.name ?? 'SPL Token',
        uiAmount: ui,
        rawAmount: raw,
        decimals: decimals,
      );
    } catch (_) {
      return null;
    }
  }

  String _shortMint(String mint) => mint.length <= 8
      ? mint
      : '${mint.substring(0, 4)}…${mint.substring(mint.length - 4)}';
}
