import 'package:sinpra_app/core/wallet/solana_rpc_service.dart';

class TokenBalance {
  final String? mint;
  final String symbol;
  final String name;
  final int decimals;
  final double uiAmount;
  final String rawAmount;

  const TokenBalance({
    required this.mint,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.uiAmount,
    required this.rawAmount,
  });
}

/// 查询地址 SOL + SPL 代币余额（经 RPC failover）。
class WalletTokenBalances {
  Future<List<TokenBalance>> listBalances(
    String owner,
    List<Map<String, dynamic>> knownTokens,
  ) async {
    final known = knownTokens
        .map((t) => KnownToken(
              mint: t['mint_address'] as String? ?? '',
              symbol: t['symbol'] as String? ?? '',
              name: t['name'] as String? ?? '',
              decimals: (t['decimals'] as num?)?.toInt() ?? 0,
            ))
        .where((k) => k.mint.isNotEmpty)
        .toList();

    final items = await SolanaRpcService.instance.listBalances(
      owner,
      known: known,
    );

    return items
        .map((i) => TokenBalance(
              mint: i.mint,
              symbol: i.symbol,
              name: i.name,
              decimals: i.decimals,
              uiAmount: i.uiAmount,
              rawAmount: i.rawAmount,
            ))
        .toList();
  }
}
