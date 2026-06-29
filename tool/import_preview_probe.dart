// Diagnostic: reproduce WalletKeys.previewImport with 64-byte Solana secret
import 'dart:convert';
import 'dart:typed_data';

import 'package:solana/base58.dart';
import 'package:solana/solana.dart';

import 'package:sinpra_app/core/wallet/wallet_keys.dart';
import 'package:sinpra_app/core/wallet/wallet_profiles.dart';

Future<void> main() async {
  final kp = await Ed25519HDKeyPair.random();
  final seed = Uint8List.fromList((await kp.extract()).bytes);
  final pub = (await kp.extractPublicKey()).bytes;
  final secret64 = Uint8List.fromList([...seed, ...pub]);
  final b58 = base58encode(secret64);
  print('Known address: ${kp.address}');
  print('64-byte base58 len: ${b58.length}');

  for (final label in ['32-byte b58', '64-byte b58']) {
    final input = label.startsWith('32') ? base58encode(seed) : b58;
    try {
      final r = await WalletKeys.previewImport(
        secret: input,
        walletId: WalletProfileId.tokenpocket,
      );
      print('$label => ok=${r.ok} addr=${r.address} msg=${r.message}');
    } catch (e, st) {
      print('$label => THREW: $e');
    }
  }

  // JSON 64-array (TP/CLI export style)
  final kp2 = await Ed25519HDKeyPair.random();
  final s2 = Uint8List.fromList((await kp2.extract()).bytes);
  final p2 = (await kp2.extractPublicKey()).bytes;
  final jsonStr = jsonEncode([...s2, ...p2]);
  try {
    final r = await WalletKeys.previewImport(
      secret: jsonStr,
      walletId: WalletProfileId.tokenpocket,
    );
    print('json64 => ok=${r.ok} addr=${r.address} expected=${kp2.address}');
  } catch (e) {
    print('json64 => THREW: $e (expected ${kp2.address})');
  }
}
