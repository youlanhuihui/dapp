/// Solana 钱包导入 Profile（与 Web wallet-profiles.ts 同步）

enum WalletProfileId {
  phantom,
  solflare,
  backpack,
  tokenpocket,
  okx,
}

class DerivationPathOption {
  const DerivationPathOption({
    required this.id,
    required this.label,
    required this.labelEn,
    required this.path,
  });

  final String id;
  final String label;
  final String labelEn;
  final String path;
}

class WalletProfile {
  const WalletProfile({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.logoAsset,
    required this.derivationPaths,
    required this.exportSteps,
    required this.exportStepsEn,
  });

  final WalletProfileId id;
  final String name;
  final String nameEn;
  final String logoAsset;
  final List<DerivationPathOption> derivationPaths;
  final List<String> exportSteps;
  final List<String> exportStepsEn;
}

const _phantomPath = DerivationPathOption(
  id: 'default',
  label: '默认路径（与 Phantom 一致）',
  labelEn: 'Default (Phantom standard)',
  path: "m/44'/501'/0'/0'",
);

const walletProfiles = <WalletProfile>[
  WalletProfile(
    id: WalletProfileId.phantom,
    name: 'Phantom',
    nameEn: 'Phantom',
    logoAsset: 'assets/wallets/phantom.svg',
    derivationPaths: [_phantomPath],
    exportSteps: [
      '打开 Phantom，确认当前为 Solana 网络',
      '设置 → 安全与隐私 → 显示助记词 / 导出私钥',
      '复制完整助记词或 base58 私钥，勿复制钱包地址',
      '粘贴到下一步，并与预览地址核对一致',
    ],
    exportStepsEn: [
      'Open Phantom on Solana network',
      'Settings → Security → Show Secret Recovery Phrase / Export Private Key',
      'Copy the full mnemonic or base58 private key (not your public address)',
      'Paste below and verify the preview address matches',
    ],
  ),
  WalletProfile(
    id: WalletProfileId.solflare,
    name: 'Solflare',
    nameEn: 'Solflare',
    logoAsset: 'assets/wallets/solflare.svg',
    derivationPaths: [_phantomPath],
    exportSteps: [
      '打开 Solflare，切换到 Solana 主网/测试网',
      '设置 → 恢复短语 / Export Private Key',
      '复制 12/24 词助记词或私钥',
      '粘贴后核对预览地址与原钱包一致',
    ],
    exportStepsEn: [
      'Open Solflare on Solana',
      'Settings → Recovery Phrase / Export Private Key',
      'Copy mnemonic or private key',
      'Verify preview address matches your Solflare wallet',
    ],
  ),
  WalletProfile(
    id: WalletProfileId.backpack,
    name: 'Backpack',
    nameEn: 'Backpack',
    logoAsset: 'assets/wallets/backpack.svg',
    derivationPaths: [_phantomPath],
    exportSteps: [
      '打开 Backpack，选择 Solana 账户',
      'Settings → Security → Show Secret Recovery Phrase / Export Key',
      '复制助记词或私钥（非地址）',
      '粘贴并核对预览地址',
    ],
    exportStepsEn: [
      'Open Backpack Solana account',
      'Settings → Security → export phrase or key',
      'Copy mnemonic or private key',
      'Verify preview address',
    ],
  ),
  WalletProfile(
    id: WalletProfileId.tokenpocket,
    name: 'TokenPocket',
    nameEn: 'TokenPocket',
    logoAsset: 'assets/wallets/tokenpocket.svg',
    derivationPaths: [
      _phantomPath,
      const DerivationPathOption(
        id: 'tp-alt',
        label: 'TokenPocket 备选路径',
        labelEn: 'TokenPocket alternate path',
        path: "m/44'/501'/0'/0'/0'",
      ),
    ],
    exportSteps: [
      '打开 TokenPocket，务必切换到 Solana（非 ETH/BSC/TRX）',
      '钱包管理 → 选择 Solana 钱包 → 导出助记词 或 导出私钥',
      '私钥可能是 base58、hex 或数字数组格式，均可粘贴',
      '若预览地址与原钱包不一致，请切换「备选路径」后重试',
    ],
    exportStepsEn: [
      'Open TokenPocket on Solana (not EVM chains)',
      'Wallet → Solana wallet → Export mnemonic or private key',
      'Private key may be base58, hex, or JSON array — all supported',
      'If preview address mismatches, try the alternate derivation path',
    ],
  ),
  WalletProfile(
    id: WalletProfileId.okx,
    name: 'OKX Web3',
    nameEn: 'OKX Web3',
    logoAsset: 'assets/wallets/okx.svg',
    derivationPaths: [
      _phantomPath,
      const DerivationPathOption(
        id: 'okx-acct1',
        label: 'OKX 账户索引 1',
        labelEn: 'OKX account index 1',
        path: "m/44'/501'/1'/0'",
      ),
    ],
    exportSteps: [
      '打开 OKX Web3 钱包，选择 Solana 网络',
      '资产 → Solana 钱包 → 备份助记词 / 导出私钥',
      '复制完整内容，避免多余空格或换行',
      '核对预览地址；不一致时切换账户路径选项',
    ],
    exportStepsEn: [
      'Open OKX Web3 on Solana',
      'Assets → Solana wallet → backup or export key',
      'Copy without extra spaces or line breaks',
      'Verify preview; try alternate path if mismatch',
    ],
  ),
];

WalletProfile getWalletProfile(WalletProfileId id) {
  return walletProfiles.firstWhere((p) => p.id == id);
}

DerivationPathOption getDerivationPath(WalletProfileId walletId, {String? pathId}) {
  final profile = getWalletProfile(walletId);
  if (pathId != null) {
    for (final p in profile.derivationPaths) {
      if (p.id == pathId) return p;
    }
  }
  return profile.derivationPaths.first;
}

String walletProfileIdToString(WalletProfileId id) {
  switch (id) {
    case WalletProfileId.phantom:
      return 'phantom';
    case WalletProfileId.solflare:
      return 'solflare';
    case WalletProfileId.backpack:
      return 'backpack';
    case WalletProfileId.tokenpocket:
      return 'tokenpocket';
    case WalletProfileId.okx:
      return 'okx';
  }
}

WalletProfileId? walletProfileIdFromString(String? raw) {
  switch (raw) {
    case 'phantom':
      return WalletProfileId.phantom;
    case 'solflare':
      return WalletProfileId.solflare;
    case 'backpack':
      return WalletProfileId.backpack;
    case 'tokenpocket':
      return WalletProfileId.tokenpocket;
    case 'okx':
      return WalletProfileId.okx;
    default:
      return null;
  }
}
