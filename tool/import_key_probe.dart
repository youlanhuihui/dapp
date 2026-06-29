// One-off diagnostic: 32 vs 64 byte Solana secret key import
import 'dart:typed_data';

import 'package:solana/solana.dart';

import 'package:solana/base58.dart';

Future<void> main() async {
  final kp = await Ed25519HDKeyPair.random();
  final data = await kp.extract();
  final seed32 = Uint8List.fromList(data.bytes);
  print('extracted secret length: ${seed32.length}');
  print('original address: ${kp.address}');

  final k32 = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: seed32);
  print('32-byte import: ${k32.address} match=${k32.address == kp.address}');

  // Simulate Phantom/TP style 64-byte secret (32 seed + 32 pubkey)
  final pub = (await kp.extractPublicKey()).bytes;
  final secret64 = Uint8List.fromList([...seed32, ...pub]);
  final b58_64 = base58encode(secret64);
  print('base58(64) length: ${b58_64.length}');

  final decoded = base58decode(b58_64);
  final k64 = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: decoded);
  print('64-byte import: ${k64.address} match=${k64.address == kp.address}');

  // Test alt TP path
  const alt = "m/44'/501'/0'/0'/0'";
  const std = "m/44'/501'/0'/0'";
  print('paths: std=$std alt=$alt');
}
