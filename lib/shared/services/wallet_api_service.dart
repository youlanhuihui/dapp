import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';

/// 钱包页相关查询：代币列表、已知代币、余额、功能开关、水龙头。
class WalletApiService {
  final ApiClient _api;
  WalletApiService(this._api);

  /// 已发行 / 已知代币（mint_address/symbol/name/decimals）
  Future<List<Map<String, dynamic>>> getMyTokens() async {
    final res = await _api.get(ApiEndpoints.userTokens);
    final list = res.data as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 钱包设置（优先币种等）
  Future<Map<String, dynamic>> getWalletSettings() async {
    final res = await _api.get(ApiEndpoints.userWalletSettings);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> setDefaultAddress(String address) async {
    final s = await getWalletSettings();
    await _api.put(
      ApiEndpoints.userWalletSettings,
      data: {
        'default_address': address,
        'favorite_tokens': s['favorite_tokens'] ?? [],
        'receivable_tokens': s['receivable_tokens'] ?? [],
      },
    );
  }

  /// 公开功能开关
  Future<Map<String, bool>> getPublicFeatures() async {
    final res = await _api.get(ApiEndpoints.adminFeaturesPublic);
    final list = res.data as List<dynamic>;
    final map = <String, bool>{};
    for (final e in list) {
      if (e is Map) {
        final key = e['key'] as String?;
        final enabled = e['enabled'] as bool?;
        if (key != null && enabled != null) map[key] = enabled;
      }
    }
    return map;
  }

  /// 交易记录（转账 / 收款 / 红包流水）
  Future<List<Map<String, dynamic>>> getHistory() async {
    final res = await _api.get(ApiEndpoints.walletTx);
    final list = res.data as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 水龙头信息（devnet）
  Future<Map<String, dynamic>?> getFaucet() async {
    try {
      final res = await _api.get(ApiEndpoints.stakingFaucet);
      return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      return null;
    }
  }
}
