import 'package:bip39/bip39.dart' as bip39;
import 'package:sinpra_app/core/wallet/wallet_keys.dart';
import 'package:sinpra_app/core/wallet/wallet_profiles.dart';

Future<void> main() async {
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  for (final pathId in ['default', 'tp-alt']) {
    final r = await WalletKeys.previewImport(
      secret: mnemonic,
      walletId: WalletProfileId.tokenpocket,
      pathId: pathId,
    );
    print('pathId=$pathId path=${r.pathUsed} addr=${r.address}');
  }
  // std phantom path for compare
  final r2 = await WalletKeys.previewImport(
    secret: mnemonic,
    walletId: WalletProfileId.phantom,
  );
  print('phantom default addr=${r2.address}');
}
