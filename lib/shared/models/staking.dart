/// 业务页数据模型：质押 / 节点 / 提现 / 模拟器。
/// 字段口径与 Web `/business` 页一致。

class StakingConfig {
  final bool enabled;
  final String network;
  final String? mint;
  final String symbol;
  final int decimals;
  final String poolAddress;
  final int dailyRateBps;
  final num withdrawFeePercent;
  final String minStake;

  const StakingConfig({
    required this.enabled,
    required this.network,
    this.mint,
    required this.symbol,
    required this.decimals,
    required this.poolAddress,
    required this.dailyRateBps,
    required this.withdrawFeePercent,
    required this.minStake,
  });

  factory StakingConfig.fromJson(Map<String, dynamic> j) => StakingConfig(
        enabled: j['enabled'] as bool? ?? false,
        network: j['network'] as String? ?? 'mainnet-beta',
        mint: j['mint'] as String?,
        symbol: j['symbol'] as String? ?? 'USTD',
        decimals: j['decimals'] as int? ?? 6,
        poolAddress: j['pool_address'] as String? ?? '',
        dailyRateBps: (j['daily_rate_bps'] as num?)?.toInt() ?? 100,
        withdrawFeePercent: j['withdraw_fee_percent'] as num? ?? 0,
        minStake: j['min_stake'] as String? ?? '100',
      );
}

class StakeItem {
  final String id;
  final String principal;
  final num multiplier;
  final String contractTotal;
  final String dailyRelease;
  final String released;
  final num progress;
  final String status;
  final DateTime createdAt;

  const StakeItem({
    required this.id,
    required this.principal,
    required this.multiplier,
    required this.contractTotal,
    required this.dailyRelease,
    required this.released,
    required this.progress,
    required this.status,
    required this.createdAt,
  });

  factory StakeItem.fromJson(Map<String, dynamic> j) => StakeItem(
        id: j['id'] as String,
        principal: j['principal'] as String? ?? '0',
        multiplier: j['multiplier'] as num? ?? 0,
        contractTotal: j['contract_total'] as String? ?? '0',
        dailyRelease: j['daily_release'] as String? ?? '0',
        released: j['released'] as String? ?? '0',
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? 'releasing',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class WithdrawalItem {
  final String id;
  final String amount;
  final String fee;
  final String net;
  final String status;
  final String? payoutTx;
  final String? note;
  final DateTime createdAt;

  const WithdrawalItem({
    required this.id,
    required this.amount,
    required this.fee,
    required this.net,
    required this.status,
    this.payoutTx,
    this.note,
    required this.createdAt,
  });

  factory WithdrawalItem.fromJson(Map<String, dynamic> j) => WithdrawalItem(
        id: j['id'] as String,
        amount: j['amount'] as String? ?? '0',
        fee: j['fee'] as String? ?? '0',
        net: j['net'] as String? ?? '0',
        status: j['status'] as String? ?? 'pending',
        payoutTx: j['payout_tx'] as String?,
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class Overview {
  final String symbol;
  final int decimals;
  final String totalStaked;
  final String totalReleased;
  final String withdrawable;
  final String totalContract;
  final int referralCount;
  final int maxReferrals;
  final int accelRatioPct;
  final String referralStaked;
  final String accelDaily;
  final String baseDaily;
  final String totalDaily;
  final List<StakeItem> stakes;
  final List<WithdrawalItem> withdrawals;

  const Overview({
    required this.symbol,
    required this.decimals,
    required this.totalStaked,
    required this.totalReleased,
    required this.withdrawable,
    required this.totalContract,
    required this.referralCount,
    required this.maxReferrals,
    required this.accelRatioPct,
    required this.referralStaked,
    required this.accelDaily,
    required this.baseDaily,
    required this.totalDaily,
    required this.stakes,
    required this.withdrawals,
  });

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
        symbol: j['symbol'] as String? ?? 'USTD',
        decimals: j['decimals'] as int? ?? 6,
        totalStaked: j['total_staked'] as String? ?? '0',
        totalReleased: j['total_released'] as String? ?? '0',
        withdrawable: j['withdrawable'] as String? ?? '0',
        totalContract: j['total_contract'] as String? ?? '0',
        referralCount: (j['referral_count'] as num?)?.toInt() ?? 0,
        maxReferrals: (j['max_referrals'] as num?)?.toInt() ?? 5,
        accelRatioPct: (j['accel_ratio_pct'] as num?)?.toInt() ?? 0,
        referralStaked: j['referral_staked'] as String? ?? '0',
        accelDaily: j['accel_daily'] as String? ?? '0',
        baseDaily: j['base_daily'] as String? ?? '0',
        totalDaily: j['total_daily'] as String? ?? '0',
        stakes: ((j['stakes'] as List?) ?? [])
            .map((e) => StakeItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        withdrawals: ((j['withdrawals'] as List?) ?? [])
            .map((e) => WithdrawalItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class NodeConfig {
  final bool enabled;
  final String network;
  final String symbol;
  final int decimals;
  final String? mint;
  final String price;
  final String? poolAddress;
  final int maxNodes;
  final int soldCount;
  final bool soldOut;
  final String descriptionText;

  const NodeConfig({
    required this.enabled,
    required this.network,
    required this.symbol,
    required this.decimals,
    this.mint,
    required this.price,
    this.poolAddress,
    required this.maxNodes,
    required this.soldCount,
    required this.soldOut,
    required this.descriptionText,
  });

  factory NodeConfig.fromJson(Map<String, dynamic> j) => NodeConfig(
        enabled: j['enabled'] as bool? ?? false,
        network: j['network'] as String? ?? 'mainnet-beta',
        symbol: j['symbol'] as String? ?? 'USTD',
        decimals: j['decimals'] as int? ?? 6,
        mint: j['mint'] as String?,
        price: j['price'] as String? ?? '300',
        poolAddress: j['pool_address'] as String?,
        maxNodes: (j['max_nodes'] as num?)?.toInt() ?? 1000,
        soldCount: (j['sold_count'] as num?)?.toInt() ?? 0,
        soldOut: j['sold_out'] as bool? ?? false,
        descriptionText: j['description_text'] as String? ?? '',
      );
}

class NodeDividend {
  final int slot;
  final String symbol;
  final String? mint;
  final String amount;

  const NodeDividend({
    required this.slot,
    required this.symbol,
    this.mint,
    required this.amount,
  });

  factory NodeDividend.fromJson(Map<String, dynamic> j) => NodeDividend(
        slot: (j['slot'] as num?)?.toInt() ?? 0,
        symbol: j['symbol'] as String? ?? '',
        mint: j['mint'] as String?,
        amount: j['amount'] as String? ?? '0',
      );
}

class NodeMe {
  final bool purchased;
  final bool isNodeVip;
  final DateTime? purchasedAt;
  final String? txSignature;
  final List<NodeDividend> dividends;
  final List<NodeDividend> referralDividends;

  const NodeMe({
    required this.purchased,
    required this.isNodeVip,
    this.purchasedAt,
    this.txSignature,
    required this.dividends,
    required this.referralDividends,
  });

  factory NodeMe.fromJson(Map<String, dynamic> j) => NodeMe(
        purchased: j['purchased'] as bool? ?? false,
        isNodeVip: j['is_node_vip'] as bool? ?? false,
        purchasedAt: j['purchased_at'] != null
            ? DateTime.parse(j['purchased_at'] as String)
            : null,
        txSignature: j['tx_signature'] as String?,
        dividends: ((j['dividends'] as List?) ?? [])
            .map((e) => NodeDividend.fromJson(e as Map<String, dynamic>))
            .toList(),
        referralDividends: ((j['referral_dividends'] as List?) ?? [])
            .map((e) => NodeDividend.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PayoutBalance {
  final String business; // contract_admin | node_holder | node_referrer
  final int slot;
  final String symbol;
  final String? mint;
  final String amount;

  const PayoutBalance({
    required this.business,
    required this.slot,
    required this.symbol,
    this.mint,
    required this.amount,
  });

  factory PayoutBalance.fromJson(Map<String, dynamic> j) => PayoutBalance(
        business: j['business'] as String? ?? '',
        slot: (j['slot'] as num?)?.toInt() ?? 0,
        symbol: j['symbol'] as String? ?? '',
        mint: j['mint'] as String?,
        amount: j['amount'] as String? ?? '0',
      );
}
