import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/wallet/solana_rpc_service.dart';

BigInt uiToBaseUnits(String uiAmount, int decimals) {
  final parts = uiAmount.split('.');
  final intPart = parts[0];
  final frac = (parts.length > 1 ? parts[1] : '').padRight(decimals, '0');
  final trimmed = frac.length > decimals ? frac.substring(0, decimals) : frac;
  return BigInt.parse('$intPart$trimmed');
}

Future<String> sendWalletTransfer({
  required EmbeddedWalletStore wallet,
  required String fromAddress,
  required String toAddress,
  required String? mint,
  required int decimals,
  required String uiAmount,
  String? memo,
}) async {
  final from = Ed25519HDPublicKey.fromBase58(fromAddress);
  final to = Ed25519HDPublicKey.fromBase58(toAddress);
  final amount = uiToBaseUnits(uiAmount, decimals);
  final rpcUrl =
      SolanaRpcService.instance.activeUrl ?? SolanaRpcService.instance.defaultUrl;
  final rpc = SolanaRpcService.createClient(rpcUrl);

  return wallet.signAndSend(
    (feePayer, blockhash) async {
      final instructions = <Instruction>[];
      if (mint == null) {
        instructions.add(SystemInstruction.transfer(
          fundingAccount: from,
          recipientAccount: to,
          lamports: amount.toInt(),
        ));
      } else {
        final mintPk = Ed25519HDPublicKey.fromBase58(mint);
        final fromAta = await findAssociatedTokenAddress(owner: from, mint: mintPk);
        final toAta = await findAssociatedTokenAddress(owner: to, mint: mintPk);
        final destInfo = await rpc.rpcClient.getAccountInfo(toAta.toBase58());
        if (destInfo == null) {
          instructions.add(AssociatedTokenAccountInstruction.createAccount(
            funder: from,
            address: toAta,
            owner: to,
            mint: mintPk,
          ));
        }
        instructions.add(TokenInstruction.transferChecked(
          amount: amount.toInt(),
          decimals: decimals,
          source: fromAta,
          mint: mintPk,
          destination: toAta,
          owner: from,
        ));
      }
      return instructions;
    },
    from: fromAddress,
  );
}

String formatTransferError(Object err) {
  final msg = err.toString();
  if (msg.contains('insufficient lamports')) {
    return 'SOL 余额不足，请减少金额并预留手续费';
  }
  return msg;
}
