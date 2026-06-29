import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/shared/models/staking.dart';

/// 业务页服务：质押 / 节点 / 分润提现。
class StakingService {
  final ApiClient _api;
  StakingService(this._api);

  Future<StakingConfig> getConfig() async {
    final res = await _api.get(ApiEndpoints.stakingConfig);
    return StakingConfig.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Overview> getOverview() async {
    final res = await _api.get(ApiEndpoints.stakingOverview);
    return Overview.fromJson(res.data as Map<String, dynamic>);
  }

  /// 提交质押（上链后调用，登记仓位）
  Future<void> submitStake({
    required String address,
    required String amount,
    required String depositTx,
  }) async {
    await _api.post(
      ApiEndpoints.stakingStakes,
      data: {
        'address': address,
        'amount': amount,
        'deposit_tx': depositTx,
      },
    );
  }

  /// 申请合约分润提现
  Future<void> submitWithdraw({
    required String address,
    required String amount,
  }) async {
    await _api.post(
      ApiEndpoints.stakingWithdrawals,
      data: {'address': address, 'amount': amount},
    );
  }

  Future<NodeConfig> getNodeConfig() async {
    final res = await _api.get(ApiEndpoints.nodeStakingConfig);
    return NodeConfig.fromJson(res.data as Map<String, dynamic>);
  }

  Future<NodeMe> getNodeMe() async {
    final res = await _api.get(ApiEndpoints.nodeStakingMe);
    return NodeMe.fromJson(res.data as Map<String, dynamic>);
  }

  /// 购买节点（上链后调用）
  Future<void> purchaseNode({
    required String address,
    required String depositTx,
  }) async {
    await _api.post(
      ApiEndpoints.nodeStakingPurchase,
      data: {'address': address, 'deposit_tx': depositTx},
    );
  }

  Future<List<PayoutBalance>> getPayoutBalances() async {
    final res = await _api.get(ApiEndpoints.payoutBalances);
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];
    return items
        .map((e) => PayoutBalance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 分块提现（合约分红 / 节点持有 / 节点推广）
  Future<void> submitPayoutWithdraw({
    required String business,
    required int slot,
    required String amount,
    required String address,
  }) async {
    await _api.post(
      ApiEndpoints.payoutWithdrawals,
      data: {
        'business': business,
        'slot': slot,
        'amount': amount,
        'address': address,
      },
    );
  }
}
