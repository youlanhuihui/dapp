import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';

/// Solana 系统账户租金豁免最低余额（lamports）。
const int solRentExemptLamports = 890880;
const double minSolRedPacketUi = solRentExemptLamports / 1e9;

String? validateSolRedPacketAmount(double uiAmount) {
  if (uiAmount < minSolRedPacketUi) {
    return 'SOL 红包最低约 ${minSolRedPacketUi.toStringAsFixed(6)} SOL（链上托管账户租金要求）';
  }
  return null;
}

String? friendlyRedPacketError(Object err) {
  final msg = err.toString();
  if (msg.toLowerCase().contains('insufficient funds for rent')) {
    return 'SOL 红包金额过低，托管账户需满足链上租金（最低约 ${minSolRedPacketUi.toStringAsFixed(6)} SOL）';
  }
  return null;
}

/// 把红包资金转入托管地址（与 Web fundRedPacket 一致）。
Future<String> fundRedPacket({
  required EmbeddedWalletStore wallet,
  required String fromAddress,
  required String escrowAddress,
  required String? mint,
  required int decimals,
  required String totalBase,
  required int solBuffer,
}) async {
  final from = Ed25519HDPublicKey.fromBase58(fromAddress);
  final escrow = Ed25519HDPublicKey.fromBase58(escrowAddress);
  final total = BigInt.parse(totalBase);
  final buffer = BigInt.from(solBuffer);

  return wallet.signAndSend(
    (feePayer, blockhash) async {
      final instructions = <Instruction>[];
      if (mint == null) {
        instructions.add(SystemInstruction.transfer(
          fundingAccount: from,
          recipientAccount: escrow,
          lamports: (total + buffer).toInt(),
        ));
      } else {
        final mintPk = Ed25519HDPublicKey.fromBase58(mint);
        instructions.add(SystemInstruction.transfer(
          fundingAccount: from,
          recipientAccount: escrow,
          lamports: solBuffer,
        ));
        final fromAta = await findAssociatedTokenAddress(owner: from, mint: mintPk);
        final escrowAta = await findAssociatedTokenAddress(owner: escrow, mint: mintPk);
        instructions.add(AssociatedTokenAccountInstruction.createAccount(
          funder: from,
          address: escrowAta,
          owner: escrow,
          mint: mintPk,
        ));
        instructions.add(TokenInstruction.transferChecked(
          amount: total.toInt(),
          decimals: decimals,
          source: fromAta,
          mint: mintPk,
          destination: escrowAta,
          owner: from,
        ));
      }
      return instructions;
    },
    from: fromAddress,
    onProgress: (_) {},
  );
}
