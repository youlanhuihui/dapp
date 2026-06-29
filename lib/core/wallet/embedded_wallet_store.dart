import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/wallet/solana_rpc_service.dart';
import 'wallet_crypto.dart';
import 'wallet_keys.dart';
import 'wallet_profiles.dart';

/// 钱包账户
class WalletAccount {
  final String address;
  final String label;
  final String type; // hd | imported
  final int? index;

  const WalletAccount({
    required this.address,
    required this.label,
    required this.type,
    this.index,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'label': label,
        'type': type,
        if (index != null) 'index': index,
      };

  factory WalletAccount.fromJson(Map<String, dynamic> j) => WalletAccount(
        address: j['address'] as String,
        label: j['label'] as String? ?? '',
        type: j['type'] as String? ?? 'hd',
        index: j['index'] as int?,
      );
}

/// 解密后的金库（仅在解锁期间存于内存）。
class VaultData {
  final String mnemonic;
  final List<int> hdIndices;
  final List<String> importedSecrets;
  final Map<String, String>? hdPathOverrides;
  final String? importedFrom;

  const VaultData({
    required this.mnemonic,
    required this.hdIndices,
    required this.importedSecrets,
    this.hdPathOverrides,
    this.importedFrom,
  });

  Map<String, dynamic> toJson() => {
        'mnemonic': mnemonic,
        'hdIndices': hdIndices,
        'imported': importedSecrets.map((s) => {'secret': s}).toList(),
        if (hdPathOverrides != null && hdPathOverrides!.isNotEmpty)
          'hdPathOverrides': hdPathOverrides,
        if (importedFrom != null) 'importedFrom': importedFrom,
      };

  factory VaultData.fromJson(Map<String, dynamic> j) {
    final imported = (j['imported'] as List?) ?? [];
    final overridesRaw = j['hdPathOverrides'] as Map<String, dynamic>?;
    return VaultData(
      mnemonic: j['mnemonic'] as String,
      hdIndices: ((j['hdIndices'] as List?) ?? []).map((e) => e as int).toList(),
      importedSecrets: imported
          .map((e) => (e as Map<String, dynamic>)['secret'] as String)
          .toList(),
      hdPathOverrides: overridesRaw?.map((k, v) => MapEntry(k, v as String)),
      importedFrom: j['importedFrom'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}

class CloudWalletExistsError implements Exception {
  final String cloudAddress;
  const CloudWalletExistsError(this.cloudAddress);
  @override
  String toString() => '云端已有钱包备份';
}

typedef OnProgress = void Function(String phase);

/// 内置钱包状态管理：与 Web embedded-wallet-store 行为一致。
class EmbeddedWalletStore extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _kVault = 'sinpra_wallet_vault_v2';
  static const _kMeta = 'sinpra_wallet_meta_v2';
  static const _kActivePin = 'sinpra_wallet_pin_tmp';

  final ApiClient _api;

  EmbeddedWalletStore({required ApiClient api}) : _api = api;

  bool initialized = false;
  bool hasWallet = false;
  bool unlocked = false;
  List<WalletAccount> accounts = [];
  String? activeAddress;
  String? cloudBackupAddress;
  bool restoredFromCloud = false;
  bool? cloudSyncOk;
  String? cloudSyncMessage;

  // 仅解锁期间存在于内存
  VaultData? _vault;
  String? _pin;
  final Map<String, Ed25519HDKeyPair> _keypairs = {};
  // HD index → address，解锁加载时建立
  final Map<int, String> _hdIndexAddress = {};
  final List<String> _importedAddresses = [];

  Ed25519HDKeyPair? getActiveKeypair() {
    if (activeAddress == null) return null;
    return _keypairs[activeAddress];
  }

  bool get isUnlocked => unlocked && _vault != null;

  /// 初始化：加载本地金库 + 拉取云端备份（无本地时自动写入云端密文，与 Web 一致）
  Future<void> init() async {
    await refreshCloudBackup();
    var blob = await _readVaultBlob();
    final meta = await _readMeta();
    final serverInfo = await _fetchServerBackup();
    var restored = false;

    if (blob == null && serverInfo != null) {
      final serverBlob = EncryptedBlob.fromServerValue(serverInfo['encrypted_blob']);
      if (serverBlob != null) {
        await _storage.write(key: _kVault, value: serverBlob.toJsonString());
        blob = serverBlob;
        restored = true;
        if (serverInfo['address'] is String) {
          cloudBackupAddress = serverInfo['address'] as String;
        }
      }
    }

    hasWallet = blob != null;
    accounts = meta?['accounts'] != null
        ? (meta!['accounts'] as List)
            .map((e) => WalletAccount.fromJson(e as Map<String, dynamic>))
            .toList()
        : [];
    activeAddress = meta?['activeAddress'] as String?;
    if (!hasWallet && cloudBackupAddress != null) {
      restoredFromCloud = true;
    } else if (restored) {
      restoredFromCloud = true;
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> refreshCloudBackup() async {
    try {
      final res = await _api.get(ApiEndpoints.embeddedWallet);
      final data = res.data;
      if (data is Map<String, dynamic> && data['address'] != null) {
        cloudBackupAddress = data['address'] as String;
      } else {
        cloudBackupAddress = null;
      }
    } catch (_) {
      cloudBackupAddress = null;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _fetchServerBackup() async {
    try {
      final res = await _api.get(ApiEndpoints.embeddedWallet);
      final data = res.data;
      if (data is Map<String, dynamic> && data['encrypted_blob'] != null) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _backupToServer(String address, EncryptedBlob blob) async {
    try {
      await _api.put(
        ApiEndpoints.embeddedWallet,
        data: {
          'address': address,
          'encrypted_blob': blob.toJsonString(),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _registerWalletBinding(String address) async {
    try {
      await _api.post(
        ApiEndpoints.userWallets,
        data: {
          'address': address,
          'provider': 'embedded',
          'chain': 'solana',
          'label': 'APP 内置钱包',
        },
      );
    } catch (_) {}
  }

  /// 从云端恢复：把云端密文写到本地
  Future<void> restoreFromCloud() async {
    final info = await _fetchServerBackup();
    if (info == null) {
      throw Exception('未找到云端钱包备份，请导入助记词或创建新钱包');
    }
    final blob = EncryptedBlob.fromServerValue(info['encrypted_blob']);
    if (blob == null) throw Exception('云端备份格式异常');
    await _storage.write(key: _kVault, value: blob.toJsonString());
    hasWallet = true;
    cloudBackupAddress = info['address'] as String?;
    restoredFromCloud = true;
    cloudSyncOk = null;
    cloudSyncMessage = null;
    notifyListeners();
  }

  Future<bool> retryCloudSync() async {
    final blob = await _readVaultBlob();
    if (blob == null || activeAddress == null) return false;
    final ok = await _backupToServer(activeAddress!, blob);
    cloudSyncOk = ok;
    cloudSyncMessage = ok ? null : '云端备份同步失败，换设备可能无法恢复。请检查网络后重试。';
    if (ok) cloudBackupAddress = activeAddress;
    notifyListeners();
    return ok;
  }

  /// 创建新钱包
  Future<({String mnemonic, String address})> create(
    String pin, {
    bool replaceCloud = false,
  }) async {
    if (!replaceCloud) {
      final remote = await _fetchServerBackup();
      if (remote != null) {
        throw CloudWalletExistsError(remote['address'] as String);
      }
    }
    final mnemonic = WalletKeys.generateMnemonic();
    final vault = VaultData(mnemonic: mnemonic, hdIndices: [0], importedSecrets: []);
    final kp = await WalletKeys.keypairFromMnemonic(mnemonic, account: 0);
    final address = kp.address;
    _keypairs[address] = kp;
    final acc = WalletAccount(address: address, label: '主钱包', type: 'hd', index: 0);
    accounts = [acc];
    activeAddress = address;
    _vault = vault;
    _pin = pin;
    final synced = await _persistVault(vault, pin, address);
    await _writeMeta();
    await _registerWalletBinding(address);
    hasWallet = true;
    unlocked = true;
    cloudBackupAddress = address;
    restoredFromCloud = false;
    cloudSyncOk = synced;
    cloudSyncMessage =
        synced ? null : '钱包已创建，但云端备份失败。请稍后在「账户与备份」重试同步。';
    notifyListeners();
    return (mnemonic: mnemonic, address: address);
  }

  Future<PreviewImportResult> previewWalletImport({
    required String input,
    required WalletProfileId walletId,
    String? pathId,
  }) =>
      WalletKeys.previewImport(secret: input, walletId: walletId, pathId: pathId);

  /// 从其他 Solana 钱包导入
  Future<String> importWallet(
    String input,
    String pin, {
    bool replaceCloud = false,
    WalletProfileId walletId = WalletProfileId.phantom,
    String? pathId,
  }) async {
    if (!replaceCloud) {
      final remote = await _fetchServerBackup();
      if (remote != null) {
        throw CloudWalletExistsError(remote['address'] as String);
      }
    }
    final preview = await WalletKeys.previewImport(
      secret: input,
      walletId: walletId,
      pathId: pathId,
    );
    if (!preview.ok) throw Exception(preview.message ?? '导入失败');

    Ed25519HDKeyPair kp;
    VaultData vault;
    if (preview.secretType == 'mnemonic') {
      final mnemonic = WalletKeys.normalizeSecretInput(input);
      kp = await WalletKeys.keypairFromMnemonicWithPath(mnemonic, preview.pathUsed!);
      final overrides = <String, String>{};
      if (preview.pathUsed != WalletKeys.solanaPath(0)) {
        overrides['0'] = preview.pathUsed!;
      }
      vault = VaultData(
        mnemonic: mnemonic,
        hdIndices: [0],
        importedSecrets: [],
        hdPathOverrides: overrides.isEmpty ? null : overrides,
        importedFrom: walletProfileIdToString(walletId),
      );
    } else {
      kp = await WalletKeys.keypairFromSecret(input);
      final secretB58 = await WalletKeys.secretToBase58(kp);
      vault = VaultData(
        mnemonic: WalletKeys.generateMnemonic(),
        hdIndices: [],
        importedSecrets: [secretB58],
        importedFrom: walletProfileIdToString(walletId),
      );
    }
    final isMnemonic = preview.secretType == 'mnemonic';
    final address = kp.address;
    _keypairs[address] = kp;
    final acc = WalletAccount(
      address: address,
      label: isMnemonic ? '主钱包' : '导入账户 1',
      type: isMnemonic ? 'hd' : 'imported',
      index: isMnemonic ? 0 : null,
    );
    accounts = [acc];
    activeAddress = address;
    _vault = vault;
    _pin = pin;
    final synced = await _persistVault(vault, pin, address);
    await _writeMeta();
    await _registerWalletBinding(address);
    hasWallet = true;
    unlocked = true;
    cloudBackupAddress = address;
    restoredFromCloud = false;
    cloudSyncOk = synced;
    cloudSyncMessage =
        synced ? null : '钱包已导入，但云端备份失败。请稍后在「账户与备份」重试同步。';
    notifyListeners();
    return address;
  }

  /// 用 PIN 解锁
  Future<void> unlock(String pin) async {
    final blob = await _readVaultBlob();
    if (blob == null) throw Exception('未找到钱包');
    String raw;
    try {
      raw = await decryptSecret(blob, pin);
    } catch (_) {
      throw Exception('PIN 码错误');
    }
    final trimmed = raw.trim();
    VaultData vault;
    if (trimmed.startsWith('{')) {
      vault = VaultData.fromJson(jsonDecode(trimmed) as Map<String, dynamic>);
    } else {
      vault = VaultData(mnemonic: trimmed, hdIndices: [0], importedSecrets: []);
    }
    await _loadKeypairs(vault);
    final meta = await _readMeta();
    final prevAccounts = meta?['accounts'] != null
        ? (meta!['accounts'] as List)
            .map((e) => WalletAccount.fromJson(e as Map<String, dynamic>))
            .toList()
        : <WalletAccount>[];
    accounts = _buildAccounts(vault, prevAccounts);

    final savedActive = meta?['activeAddress'] as String?;
    final cloudAddr = cloudBackupAddress;
    if (cloudAddr != null && accounts.any((a) => a.address == cloudAddr)) {
      activeAddress = cloudAddr;
    } else if (savedActive != null && accounts.any((a) => a.address == savedActive)) {
      activeAddress = savedActive;
    } else if (accounts.isNotEmpty) {
      activeAddress = accounts.first.address;
    }

    if (cloudAddr != null &&
        activeAddress != null &&
        cloudAddr != activeAddress &&
        !accounts.any((a) => a.address == cloudAddr)) {
      throw Exception('钱包地址与云端备份不一致，请更新 APP 后重试');
    }

    _vault = vault;
    _pin = pin;
    await _writeMeta();

    final backupAddr = cloudAddr ?? activeAddress!;
    final synced = await _backupToServer(backupAddr, blob);
    hasWallet = true;
    unlocked = true;
    cloudBackupAddress = backupAddr;
    restoredFromCloud = false;
    cloudSyncOk = synced;
    cloudSyncMessage = synced
        ? null
        : '云端备份同步失败，换设备可能无法恢复。请检查网络后在钱包页重试。';
    notifyListeners();
  }

  String _hdPathFor(VaultData vault, int index) =>
      vault.hdPathOverrides?[index.toString()] ?? WalletKeys.solanaPath(index);

  Future<void> _loadKeypairs(VaultData vault) async {
    _keypairs.clear();
    _hdIndexAddress.clear();
    _importedAddresses.clear();
    for (final i in vault.hdIndices) {
      final kp = await WalletKeys.keypairFromMnemonic(
        vault.mnemonic,
        pathOverride: _hdPathFor(vault, i),
      );
      _keypairs[kp.address] = kp;
      _hdIndexAddress[i] = kp.address;
    }
    for (final secret in vault.importedSecrets) {
      final kp = await WalletKeys.keypairFromSecret(secret);
      _keypairs[kp.address] = kp;
      _importedAddresses.add(kp.address);
    }
  }

  List<WalletAccount> _buildAccounts(VaultData vault, List<WalletAccount> prev) {
    final labelOf = (String addr, String fallback) =>
        prev.firstWhere(
          (a) => a.address == addr,
          orElse: () => WalletAccount(address: addr, label: fallback, type: 'hd'),
        ).label;
    final list = <WalletAccount>[];
    for (var n = 0; n < vault.hdIndices.length; n++) {
      final i = vault.hdIndices[n];
      final addr = _hdIndexAddress[i];
      if (addr == null) continue;
      list.add(WalletAccount(
        address: addr,
        label: labelOf(addr, n == 0 ? '主钱包' : '账户 ${i + 1}'),
        type: 'hd',
        index: i,
      ));
    }
    // 导入账户
    for (var n = 0; n < vault.importedSecrets.length; n++) {
      final addr = n < _importedAddresses.length ? _importedAddresses[n] : '';
      if (addr.isEmpty) continue;
      list.add(WalletAccount(
        address: addr,
        label: labelOf(addr, '导入账户 ${n + 1}'),
        type: 'imported',
      ));
    }
    return list;
  }

  void lock() {
    unlocked = false;
    _vault = null;
    _pin = null;
    _keypairs.clear();
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final blob = await _readVaultBlob();
    if (blob == null) return false;
    try {
      await decryptSecret(blob, pin);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> exportMnemonic(String pin) async {
    final blob = await _readVaultBlob();
    if (blob == null) throw Exception('未找到钱包');
    String raw;
    try {
      raw = await decryptSecret(blob, pin);
    } catch (_) {
      throw Exception('PIN 码错误');
    }
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      return VaultData.fromJson(jsonDecode(trimmed) as Map<String, dynamic>).mnemonic;
    }
    return trimmed;
  }

  Future<void> removeWallet() async {
    await _storage.delete(key: _kVault);
    await _storage.delete(key: _kMeta);
    hasWallet = false;
    unlocked = false;
    accounts = [];
    activeAddress = null;
    _vault = null;
    _pin = null;
    _keypairs.clear();
    await refreshCloudBackup();
    notifyListeners();
  }

  void setActive(String address) {
    if (!accounts.any((a) => a.address == address)) return;
    activeAddress = address;
    _writeMeta();
    notifyListeners();
  }

  void setLabel(String address, String label) {
    accounts = accounts
        .map((a) => a.address == address
            ? WalletAccount(
                address: a.address,
                label: label.trim().isEmpty ? a.label : label.trim(),
                type: a.type,
                index: a.index,
              )
            : a)
        .toList();
    _writeMeta();
    notifyListeners();
  }

  /// 在同一助记词下新建 HD 子账户。
  Future<WalletAccount> addAccount({String? label}) async {
    final vault = _vault;
    final pin = _pin;
    if (vault == null || pin == null) throw Exception('钱包已锁定');
    final nextIndex =
        vault.hdIndices.isEmpty ? 0 : vault.hdIndices.reduce((a, b) => a > b ? a : b) + 1;
    final newVault = VaultData(
      mnemonic: vault.mnemonic,
      hdIndices: [...vault.hdIndices, nextIndex],
      importedSecrets: vault.importedSecrets,
      hdPathOverrides: vault.hdPathOverrides,
      importedFrom: vault.importedFrom,
    );
    final kp = await WalletKeys.keypairFromMnemonic(vault.mnemonic, account: nextIndex);
    final addr = kp.address;
    final account = WalletAccount(
      address: addr,
      label: label?.trim().isNotEmpty == true ? label!.trim() : '账户 ${nextIndex + 1}',
      type: 'hd',
      index: nextIndex,
    );
    _keypairs[addr] = kp;
    _hdIndexAddress[nextIndex] = addr;
    final newAccounts = [...accounts, account];
    final backupAddr = activeAddress ?? addr;
    final synced = await _persistVault(newVault, pin, backupAddr);
    accounts = newAccounts;
    _vault = newVault;
    cloudSyncOk = synced;
    cloudSyncMessage = synced ? null : '云端备份同步失败，请稍后重试。';
    await _writeMeta();
    await _registerWalletBinding(addr);
    notifyListeners();
    return account;
  }

  /// 导入额外账户（助记词或私钥）。
  Future<WalletAccount> importAccount(
    String input, {
    String? label,
    WalletProfileId walletId = WalletProfileId.phantom,
    String? pathId,
  }) async {
    final vault = _vault;
    final pin = _pin;
    if (vault == null || pin == null) throw Exception('钱包已锁定');
    final preview = await WalletKeys.previewImport(
      secret: input,
      walletId: walletId,
      pathId: pathId,
    );
    if (!preview.ok) throw Exception(preview.message ?? '助记词或私钥无效');
    final Ed25519HDKeyPair kp;
    if (preview.secretType == 'mnemonic') {
      kp = await WalletKeys.keypairFromMnemonicWithPath(
        WalletKeys.normalizeSecretInput(input),
        preview.pathUsed!,
      );
    } else {
      kp = await WalletKeys.keypairFromSecret(input);
    }
    final addr = kp.address;
    if (accounts.any((a) => a.address == addr)) {
      throw Exception('该账户已存在');
    }
    final secret = await WalletKeys.secretToBase58(kp);
    final newVault = VaultData(
      mnemonic: vault.mnemonic,
      hdIndices: vault.hdIndices,
      importedSecrets: [...vault.importedSecrets, secret],
    );
    final account = WalletAccount(
      address: addr,
      label: label?.trim().isNotEmpty == true
          ? label!.trim()
          : '导入账户 ${vault.importedSecrets.length + 1}',
      type: 'imported',
    );
    _keypairs[addr] = kp;
    _importedAddresses.add(addr);
    final newAccounts = [...accounts, account];
    final backupAddr = activeAddress ?? addr;
    final synced = await _persistVault(newVault, pin, backupAddr);
    accounts = newAccounts;
    _vault = newVault;
    cloudSyncOk = synced;
    cloudSyncMessage = synced ? null : '云端备份同步失败，请稍后重试。';
    await _writeMeta();
    await _registerWalletBinding(addr);
    notifyListeners();
    return account;
  }

  Future<String> exportSecret(String address, String pin) async {
    final blob = await _readVaultBlob();
    if (blob == null) throw Exception('未找到钱包');
    String raw;
    try {
      raw = await decryptSecret(blob, pin);
    } catch (_) {
      throw Exception('PIN 码错误');
    }
    final trimmed = raw.trim();
    VaultData vault;
    if (trimmed.startsWith('{')) {
      vault = VaultData.fromJson(jsonDecode(trimmed) as Map<String, dynamic>);
    } else {
      vault = VaultData(mnemonic: trimmed, hdIndices: [0], importedSecrets: []);
    }
    final temp = <String, Ed25519HDKeyPair>{};
    for (final i in vault.hdIndices) {
      final kp = await WalletKeys.keypairFromMnemonic(vault.mnemonic, account: i);
      temp[kp.address] = kp;
    }
    for (final secret in vault.importedSecrets) {
      final kp = await WalletKeys.keypairFromSecret(secret);
      temp[kp.address] = kp;
    }
    final kp = temp[address];
    if (kp == null) throw Exception('未找到该账户');
    return WalletKeys.secretToBase58(kp);
  }

  // ── 持久化辅助 ──────────────────────────────
  Future<EncryptedBlob?> _readVaultBlob() async {
    final raw = await _storage.read(key: _kVault);
    return EncryptedBlob.fromJsonString(raw);
  }

  Future<Map<String, dynamic>?> _readMeta() async {
    final raw = await _storage.read(key: _kMeta);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMeta() async {
    await _storage.write(
      key: _kMeta,
      value: jsonEncode({
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'activeAddress': activeAddress,
      }),
    );
  }

  Future<bool> _persistVault(VaultData vault, String pin, String address) async {
    final blob = await encryptSecret(vault.toJsonString(), pin);
    await _storage.write(key: _kVault, value: blob.toJsonString());
    return _backupToServer(address, blob);
  }

  // ── 签名与广播 ──────────────────────────────
  /// 用当前活动账户（或指定 from）签名并广播交易，等待确认。
  /// [buildTx] 回调拿到最新 blockhash + feePayer 后组装交易。
  Future<String> signAndSend(
    Future<List<Instruction>> Function(
            Ed25519HDPublicKey feePayer, String blockhash)
        buildInstructions, {
    String? from,
    OnProgress? onProgress,
  }) async {
    final signer = from != null ? _keypairs[from] : getActiveKeypair();
    if (signer == null) throw Exception('钱包已锁定，请先解锁');
    final rpcUrl =
        SolanaRpcService.instance.activeUrl ?? SolanaRpcService.instance.defaultUrl;
    final rpc = SolanaRpcService.createClient(rpcUrl);
    onProgress?.call('prepare');
    final blockhash = await rpc.rpcClient.getLatestBlockhash();
    final recentBlockhash = blockhash.value.blockhash;
    final instructions = await buildInstructions(signer.publicKey, recentBlockhash);
    final msg = Message(instructions: instructions);
    onProgress?.call('sign');
    final signed = await signer.signMessage(
      message: msg,
      recentBlockhash: recentBlockhash,
    );
    onProgress?.call('send');
    final sig = await rpc.rpcClient.sendTransaction(
      signed.encode(),
      preflightCommitment: Commitment.confirmed,
    );
    onProgress?.call('confirm');
    await rpc.waitForSignatureStatus(sig, status: Commitment.confirmed);
    return sig;
  }

  /// 读取 SOL 余额（lamports → SOL）
  Future<double> getSolBalance(String address) async {
    final rpcUrl =
        SolanaRpcService.instance.activeUrl ?? SolanaRpcService.instance.defaultUrl;
    final rpc = SolanaRpcService.createClient(rpcUrl);
    try {
      final res = await rpc.rpcClient.getBalance(address);
      return res.value / 1e9;
    } catch (e) {
      if (kDebugMode) print('[wallet] getBalance err: $e');
      rethrow;
    }
  }
}
