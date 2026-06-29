import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/wallet/solana_rpc_service.dart';
import 'package:sinpra_app/shared/models/staking.dart';
import 'package:sinpra_app/shared/utils/format.dart';

/// 业务页链上操作：质押转账、购买节点转账。
/// 用内置钱包签名并广播 SPL Token 转账到金库。
class StakingOnChain {
  final EmbeddedWalletStore _wallet;
  StakingOnChain(this._wallet);

  SolanaClient get _rpc {
    final url =
        SolanaRpcService.instance.activeUrl ?? SolanaRpcService.instance.defaultUrl;
    return SolanaRpcService.createClient(url);
  }

  /// 向金库转入 amount 个代币（质押 / 买节点通用）。
  /// 返回交易签名。
  Future<String> transferToPool({
    required StakingConfig? config,
    required NodeConfig? nodeConfig,
    required double amount,
    required int decimals,
    required String mintStr,
    required String poolAddress,
    void Function(String phase)? onProgress,
  }) async {
    final kp = _wallet.getActiveKeypair();
    if (kp == null) throw Exception('钱包已锁定，请先解锁');
    final mint = Ed25519HDPublicKey.fromBase58(mintStr);
    final owner = kp.publicKey;
    final pool = Ed25519HDPublicKey.fromBase58(poolAddress);

    final sourceAta = await findAssociatedTokenAddress(
        owner: owner, mint: mint);
    final destAta = await findAssociatedTokenAddress(
        owner: pool, mint: mint);

    final units = parseAmountToUnits(amount.toStringAsFixed(decimals), decimals);

    onProgress?.call('prepare');
    // 检查目标 ATA 是否存在，不存在则加创建指令
    final instructions = <Instruction>[];
    final rpc = _rpc;
    final destInfo = await rpc.rpcClient
        .getAccountInfo(destAta.toBase58(), commitment: Commitment.confirmed);
    if (destInfo == null) {
      instructions.add(AssociatedTokenAccountInstruction.createAccount(
        funder: owner,
        address: destAta,
        owner: pool,
        mint: mint,
      ));
    }
    instructions.add(TokenInstruction.transferChecked(
      amount: units.toInt(),
      decimals: decimals,
      source: sourceAta,
      mint: mint,
      destination: destAta,
      owner: owner,
    ));

    return _wallet.signAndSend(
      (feePayer, blockhash) async => instructions,
      onProgress: onProgress,
    );
  }
}
