import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/config/app_config.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/wallet/solana_rpc_service.dart';
import 'package:sinpra_app/core/wallet/wallet_token_balances.dart';
import 'package:sinpra_app/shared/services/wallet_api_service.dart';
import 'package:sinpra_app/shared/utils/format.dart';
import 'package:sinpra_app/modules/wallet/widgets/wallet_import_wizard.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final w = context.read<EmbeddedWalletStore>();
      if (!w.initialized) await w.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<EmbeddedWalletStore>();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/settings')),
        title: Text(context.tr('walletTitle')),
        actions: [
          if (w.isUnlocked)
            TextButton(
              onPressed: () { w.lock(); setState(() {}); },
              child: Text('🔒 ${context.tr('lockWallet')}',
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: !w.initialized
          ? const Center(child: CircularProgressIndicator())
          : !w.hasWallet
              ? const _SetupView()
              : !w.isUnlocked
                  ? const _UnlockView()
                  : const _WalletHome(),
    );
  }
}

// ── 创建 / 导入 ─────────────────────────────
class _SetupView extends StatefulWidget {
  const _SetupView();

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  String _mode = 'choose'; // choose | create | import | replace

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmbeddedWalletStore>().refreshCloudBackup();
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<EmbeddedWalletStore>();
    if (_mode == 'create' || _mode == 'replace') {
      return _CreateFlow(replaceCloud: _mode == 'replace', onBack: () => setState(() => _mode = 'choose'));
    }
    if (_mode == 'import') {
      return WalletImportWizard(
        mode: WalletImportMode.wallet,
        onBack: () => setState(() => _mode = 'choose'),
        replaceCloud: w.cloudBackupAddress != null,
      );
    }
    if (w.cloudBackupAddress != null) {
      return _restoreCloudView(w.cloudBackupAddress!);
    }
    return _chooseView();
  }

  Widget _chooseView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: SinpraTheme.brand100, shape: BoxShape.circle),
          child: const Icon(Icons.account_balance_wallet, size: 36, color: SinpraTheme.brand600),
        ),
        const SizedBox(height: 16),
        Text(context.tr('walletSetupTitle'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(context.tr('walletSetupDesc'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 13)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: () => setState(() => _mode = 'create'),
            child: Text(context.tr('createWallet')),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton(
            onPressed: () => setState(() => _mode = 'import'),
            child: Text(context.tr('importWallet')),
          ),
        ),
        const SizedBox(height: 16),
        const Text('采用 BIP39 标准助记词，兼容 Phantom 等主流钱包。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }

  Widget _restoreCloudView(String cloudAddr) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: SinpraTheme.brand50, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(context.tr('restoreCloudDesc'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: SinpraTheme.brand900, fontSize: 13, height: 1.5)),
            const SizedBox(height: 10),
            Text(cloudAddr, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: () async {
              try {
                await context.read<EmbeddedWalletStore>().restoreFromCloud();
                if (mounted) AppSnackBar.showInfo(context, context.tr('restoreCloudWallet'));
              } catch (e) {
                AppSnackBar.showError(context, e);
              }
            },
            child: Text(context.tr('restoreCloudWallet')),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton(
            onPressed: () => setState(() => _mode = 'import'),
            child: Text(context.tr('importWallet')),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _mode = 'replace'),
          child: const Text('我确认放弃云端钱包，创建全新钱包', style: TextStyle(fontSize: 12, color: Colors.red)),
        ),
      ]),
    );
  }
}

class _PinFields extends StatelessWidget {
  final TextEditingController pin;
  final TextEditingController confirm;
  const _PinFields({required this.pin, required this.confirm});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: pin,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: context.tr('pinSetLabel'), hintText: context.tr('pinSetHint')),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: confirm,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: context.tr('pinConfirmLabel'), hintText: context.tr('pinConfirmHint')),
      ),
    ]);
  }
}

class _CreateFlow extends StatefulWidget {
  final bool replaceCloud;
  final VoidCallback onBack;
  const _CreateFlow({required this.replaceCloud, required this.onBack});

  @override
  State<_CreateFlow> createState() => _CreateFlowState();
}

class _CreateFlowState extends State<_CreateFlow> {
  String _step = 'pin'; // pin | backup
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _acked = false;
  String? _mnemonic;
  String? _error;

  @override
  void dispose() { _pin.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _create() async {
    if (_pin.text.length < 6) { setState(() => _error = context.tr('pinErrorLength')); return; }
    if (_pin.text != _confirm.text) { setState(() => _error = context.tr('pinErrorMismatch')); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final res = await context.read<EmbeddedWalletStore>().create(_pin.text, replaceCloud: widget.replaceCloud);
      setState(() { _mnemonic = res.mnemonic; _step = 'backup'; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 'backup') {
      final words = _mnemonic!.split(' ');
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('backupMnemonic'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(context.tr('backupWarn'),
              style: const TextStyle(color: Colors.red, fontSize: 12, height: 1.5)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(words.length, (i) => Container(
              width: 90, padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Text('${i + 1}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(width: 6),
                Text(words[i], style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            )),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: Text(context.tr('copy')),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _mnemonic!));
              AppSnackBar.showInfo(context, context.tr('copied'));
            },
          ),
          CheckboxListTile(
            value: _acked,
            onChanged: (v) => setState(() => _acked = v ?? false),
            title: Text(context.tr('ackedBackup')),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _acked ? () { context.read<EmbeddedWalletStore>().notifyListeners(); setState(() {}); } : null,
              child: Text(context.tr('enterWallet')),
            ),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.replaceCloud ? '创建全新钱包（覆盖云端）' : context.tr('createWallet'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('PIN 用于加密钱包，遗失无法找回，请牢记', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 20),
        _PinFields(pin: _pin, confirm: _confirm),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: widget.onBack, child: Text(context.tr('back')))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(context.tr('next')),
          )),
        ]),
      ]),
    );
  }
}

// ── 解锁 ─────────────────────────────
class _UnlockView extends StatefulWidget {
  const _UnlockView();

  @override
  State<_UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<_UnlockView> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _pin.dispose(); super.dispose(); }

  Future<void> _unlock() async {
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<EmbeddedWalletStore>().unlock(_pin.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<EmbeddedWalletStore>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('unlockWallet'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        if (w.cloudBackupAddress != null) ...[
          const SizedBox(height: 8),
          Text('该账号存在云端钱包备份，请使用原 PIN 解锁', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.tr('unlockPinLabel')),
          onSubmitted: (_) => _unlock(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _busy ? null : _unlock,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(context.tr('unlock')),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            await context.read<EmbeddedWalletStore>().removeWallet();
          },
          child: const Text('从本机移除钱包（云端备份保留）', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ]),
    );
  }
}

// ── 钱包主页 ─────────────────────────────
class _WalletHome extends StatefulWidget {
  const _WalletHome();

  @override
  State<_WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<_WalletHome> {
  final _rpc = SolanaRpcService.instance;
  List<TokenBalance> _balances = [];
  List<Map<String, dynamic>> _tokens = [];
  bool _tokenCreationEnabled = false;
  bool _loadingBal = true;
  bool _copied = false;
  bool _showSwitcher = false;
  bool _rpcExpanded = false;
  String? _balError;
  String _rpcMode = '';
  final _customRpcController = TextEditingController();
  bool _rpcTesting = false;
  String _rpcTestDetail = '';

  static const _customRpc = '__custom__';

  @override
  void initState() {
    super.initState();
    _initRpc();
  }

  @override
  void dispose() {
    _customRpcController.dispose();
    super.dispose();
  }

  Future<void> _initRpc() async {
    await _rpc.loadSelected();
    final saved = _rpc.defaultUrl;
    final isPreset = SolanaRpcService.presets.any((p) => p.url == saved);
    _rpcMode = isPreset ? saved : _customRpc;
    if (!isPreset) _customRpcController.text = saved;
    await _load();
  }

  String get _effectiveRpcUrl {
    if (_rpcMode == _customRpc) return _customRpcController.text.trim();
    return _rpcMode;
  }

  Future<void> _load() async {
    final w = context.read<EmbeddedWalletStore>();
    final api = WalletApiService(context.read());
    setState(() {
      _loadingBal = true;
      _balError = null;
    });
    try { _tokens = await api.getMyTokens(); } catch (_) {}
    try {
      final flags = await api.getPublicFeatures();
      _tokenCreationEnabled = flags['token_creation'] ?? false;
    } catch (_) {}
    if (w.activeAddress != null) {
      try {
        _balances = await WalletTokenBalances()
            .listBalances(w.activeAddress!, _tokens);
      } catch (_) {
        _balances = [];
        _balError = context.mounted ? context.tr('rpcError') : null;
      }
    } else {
      _balances = [];
    }
    if (mounted) setState(() => _loadingBal = false);
  }

  Future<void> _testRpc() async {
    final url = _effectiveRpcUrl;
    if (url.isEmpty) return;
    final addr = context.read<EmbeddedWalletStore>().activeAddress;
    setState(() { _rpcTesting = true; _rpcTestDetail = ''; });
    final result = await _rpc.testRpc(url, ownerAddress: addr);
    if (!mounted) return;
    setState(() {
      _rpcTesting = false;
      _rpcTestDetail = result.detail;
    });
  }

  Future<void> _applyRpc() async {
    final url = _effectiveRpcUrl;
    if (url.isEmpty) return;
    await _rpc.saveSelected(url);
    await _load();
  }

  double get _solBalance =>
      _balances.where((b) => b.mint == null).map((b) => b.uiAmount).firstOrNull ?? 0;

  @override
  Widget build(BuildContext context) {
    final w = context.watch<EmbeddedWalletStore>();
    final active = w.accounts.where((a) => a.address == w.activeAddress).firstOrNull;
    final addr = active?.address ?? '';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 钱包卡
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [SinpraTheme.brand600, SinpraTheme.brand800]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                InkWell(
                  onTap: () => setState(() => _showSwitcher = !_showSwitcher),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(active?.label ?? context.tr('walletTitle'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(_showSwitcher ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white70, size: 18),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/settings/wallet/accounts'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('管理账户', style: TextStyle(fontSize: 12)),
                ),
              ]),
              if (_showSwitcher) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ...w.accounts.map((a) => ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            title: Text(a.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            trailing: Text(shortenAddress(a.address, 4),
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                            tileColor: a.address == w.activeAddress
                                ? Colors.white.withOpacity(0.15)
                                : null,
                            onTap: () {
                              w.setActive(a.address);
                              setState(() { _showSwitcher = false; });
                              _load();
                            },
                          )),
                      TextButton(
                        onPressed: () => context.push('/settings/wallet/accounts'),
                        child: const Text('+ 添加 / 导入账户',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppConfig.isDevnet
                          ? SinpraTheme.amber300.withOpacity(0.2)
                          : SinpraTheme.emerald400.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppConfig.isDevnet ? context.tr('networkDevnet') : context.tr('networkMainnet'),
                      style: TextStyle(
                        color: AppConfig.isDevnet ? SinpraTheme.amber300 : SinpraTheme.emerald400,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _rpcPanel(context),
              if (_balError != null) ...[
                const SizedBox(height: 8),
                Text(_balError!, style: const TextStyle(color: SinpraTheme.amber300, fontSize: 11)),
              ],
              const SizedBox(height: 16),
              Text(context.tr('solBalance'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                Text(_loadingBal ? '…' : _solBalance.toStringAsFixed(4),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                TextButton(
                  style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.15)),
                  onPressed: _loadingBal ? null : _load,
                  child: Text(_loadingBal ? context.tr('refreshing') : context.tr('refresh'),
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: addr));
                  setState(() => _copied = true);
                  Future.delayed(const Duration(seconds: 2), () => setState(() => _copied = false));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(shortenAddress(addr, 6), style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(_copied ? context.tr('copied') : context.tr('copy'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // 快捷操作
          Row(children: [
            _quickAction(Icons.download, context.tr('receive'), () => context.push('/settings/wallet/receive')),
            _quickAction(Icons.upload, context.tr('transferOut'), () => context.push('/settings/wallet/transfer')),
            _quickAction(Icons.qr_code_scanner, context.tr('scan'), () => context.push('/friends/scan')),
            _quickAction(Icons.card_giftcard, context.tr('redPacket'), () {
              AppSnackBar.showInfo(context, '请在聊天会话中点击 + 发红包');
              context.go('/conversations');
            }),
          ]),
          const SizedBox(height: 16),
          // 资产
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('myAssets'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_balances.isEmpty && !_loadingBal)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text(context.tr('noTokenAssets'), style: const TextStyle(color: Colors.grey, fontSize: 13))),
                )
              else
                ..._balances.map((b) => _assetRow(b.symbol, b.name, b.uiAmount)),
            ]),
          ),
          const SizedBox(height: 12),
          // 入口
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _entry(context.tr('inviteBind'), context.tr('inviteBindDesc'), () => context.push('/settings/referral')),
              _entry(context.tr('txHistory'), context.tr('txHistoryDesc'),
                  () => context.push('/settings/wallet/history')),
              _entry(context.tr('myTokens'), '已发行 ${_tokens.length} 个', () {}),
              if (_tokenCreationEnabled)
                _entry(context.tr('createToken'), context.tr('createTokenDesc'), () {}),
              _entry(context.tr('accounts'), context.tr('accountsDesc'),
                  () => context.push('/settings/wallet/accounts')),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _rpcPanel(BuildContext context) {
    final activeUrl = _rpc.activeUrl ?? _rpc.defaultUrl;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _rpcExpanded = !_rpcExpanded),
            child: Row(
              children: [
                const Icon(Icons.hub_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '链上节点 · ${_rpc.labelForUrl(activeUrl)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(_rpcExpanded ? '收起' : '切换',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (_rpcExpanded) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: SolanaRpcService.presets.any((p) => p.url == _rpcMode)
                  ? _rpcMode
                  : _customRpc,
              dropdownColor: SinpraTheme.brand800,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              iconEnabledColor: Colors.white70,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'RPC 节点',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
              ),
              items: [
                ...SolanaRpcService.presets.map((p) => DropdownMenuItem(
                      value: p.url,
                      child: Text(p.label,
                          style: const TextStyle(fontSize: 12, color: Colors.white)),
                    )),
                const DropdownMenuItem(
                  value: _customRpc,
                  child: Text('自定义节点',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
              onChanged: (v) => setState(() => _rpcMode = v ?? _rpcMode),
            ),
            if (_rpcMode == _customRpc) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _customRpcController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'https://your-rpc.example.com',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _rpcTesting ? null : _testRpc,
                  child: Text(_rpcTesting ? '测试中…' : '测试连接',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _applyRpc,
                  child: const Text('应用', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
            if (_rpcTestDetail.isNotEmpty)
              Text(_rpcTestDetail,
                  style: TextStyle(
                      color: _rpcTestDetail.contains('正常')
                          ? SinpraTheme.emerald300
                          : SinpraTheme.amber300,
                      fontSize: 10)),
          ],
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(icon, color: SinpraTheme.brand600),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _assetRow(String symbol, String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(color: SinpraTheme.brand100, shape: BoxShape.circle),
          child: Center(child: Text(symbol.substring(0, symbol.length > 3 ? 3 : symbol.length),
              style: const TextStyle(color: SinpraTheme.brand700, fontWeight: FontWeight.bold, fontSize: 11))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(name, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        Text(formatTokenAmount(amount), style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _entry(String label, String desc, VoidCallback onTap) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
