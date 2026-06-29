import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/wallet/wallet_profiles.dart';
import 'package:sinpra_app/modules/wallet/widgets/wallet_source_grid.dart';
import 'package:sinpra_app/shared/utils/format.dart';

enum WalletImportMode { wallet, account }

enum _SecretTab { mnemonic, privateKey }

class WalletImportWizard extends StatefulWidget {
  const WalletImportWizard({
    super.key,
    required this.mode,
    required this.onBack,
    this.onSuccess,
    this.replaceCloud = false,
  });

  final WalletImportMode mode;
  final VoidCallback onBack;
  final VoidCallback? onSuccess;
  final bool replaceCloud;

  @override
  State<WalletImportWizard> createState() => _WalletImportWizardState();
}

class _WalletImportWizardState extends State<WalletImportWizard> {
  int _step = 0;
  WalletProfileId? _walletId;
  String? _pathId;
  _SecretTab _secretTab = _SecretTab.mnemonic;
  final _mnemonic = TextEditingController();
  final _privateKey = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _previewAddress;
  List<String> _warnings = [];
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _mnemonic.dispose();
    _privateKey.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  WalletProfile? get _profile =>
      _walletId != null ? getWalletProfile(_walletId!) : null;

  String get _activeSecret =>
      _secretTab == _SecretTab.mnemonic ? _mnemonic.text : _privateKey.text;

  int _countMnemonicWords(String input) =>
      input.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  Future<void> _preview() async {
    if (_walletId == null) return;

    final input = _activeSecret.trim();
    if (input.isEmpty) {
      setState(() => _error = context.tr(
            _secretTab == _SecretTab.mnemonic
                ? 'importMnemonicEmpty'
                : 'importPrivateKeyEmpty',
          ));
      return;
    }

    if (_secretTab == _SecretTab.mnemonic) {
      final wordCount = _countMnemonicWords(input);
      if (wordCount != 12 && wordCount != 24) {
        setState(() => _error =
            '${context.tr('importMnemonicWordCount')}（$wordCount）');
        return;
      }
    } else if (_countMnemonicWords(input) >= 12) {
      setState(() => _error = context.tr('importSwitchToMnemonicTab'));
      return;
    }

    setState(() { _busy = true; _error = null; });
    final store = context.read<EmbeddedWalletStore>();
    try {
      final result = await store.previewWalletImport(
        input: input,
        walletId: _walletId!,
        pathId: _secretTab == _SecretTab.mnemonic ? _pathId : null,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _error = result.message;
          _previewAddress = null;
        });
        return;
      }
      if (_secretTab == _SecretTab.privateKey && result.secretType == 'mnemonic') {
        setState(() => _error = context.tr('importSwitchToMnemonicTabPaste'));
        return;
      }
      if (_secretTab == _SecretTab.mnemonic && result.secretType == 'secret') {
        setState(() => _error = context.tr('importSwitchToPrivateKeyTab'));
        return;
      }
      setState(() {
        _error = null;
        _previewAddress = result.address;
        _warnings = result.warnings ?? [];
        _step = 3;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = '预览失败：${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_walletId == null) return;
    final store = context.read<EmbeddedWalletStore>();
    if (widget.mode == WalletImportMode.wallet) {
      if (_pin.text.length < 6) {
        setState(() => _error = context.tr('pinErrorLength'));
        return;
      }
      if (_pin.text != _confirm.text) {
        setState(() => _error = context.tr('pinErrorMismatch'));
        return;
      }
    }
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.mode == WalletImportMode.wallet) {
        await store.importWallet(
          _activeSecret,
          _pin.text,
          replaceCloud: widget.replaceCloud,
          walletId: _walletId!,
          pathId: _secretTab == _SecretTab.mnemonic ? _pathId : null,
        );
      } else {
        await store.importAccount(
          _activeSecret,
          walletId: _walletId!,
          pathId: _secretTab == _SecretTab.mnemonic ? _pathId : null,
        );
      }
      widget.onSuccess?.call();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _secretTabBar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _tabButton(
                label: context.tr('importTabMnemonic'),
                selected: _secretTab == _SecretTab.mnemonic,
                onTap: () => setState(() {
                  _secretTab = _SecretTab.mnemonic;
                  _error = null;
                }),
              ),
            ),
            Expanded(
              child: _tabButton(
                label: context.tr('importTabPrivateKey'),
                selected: _secretTab == _SecretTab.privateKey,
                onTap: () => setState(() {
                  _secretTab = _SecretTab.privateKey;
                  _error = null;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      elevation: selected ? 1 : 0,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('选择来源钱包', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('请选择您要导入的 Solana 钱包', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 16),
          WalletSourceGrid(
            selected: _walletId,
            onSelect: (id) => setState(() {
              _walletId = id;
              _pathId = null;
              _step = 1;
            }),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: widget.onBack, child: Text(context.tr('back'))),
        ],
      );
    }

    final profile = _profile!;
    if (_step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('从 ${profile.name} 导出', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...profile.exportSteps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(s, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: Text(context.tr('back')))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => setState(() => _step = 2), child: Text(context.tr('next')))),
          ]),
        ],
      );
    }

    if (_step == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('粘贴 ${profile.name} 导出内容', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            context.tr(_secretTab == _SecretTab.mnemonic
                ? 'importMnemonicDesc'
                : 'importPrivateKeyDesc'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 12),
          _secretTabBar(),
          const SizedBox(height: 12),
          if (_secretTab == _SecretTab.mnemonic && profile.derivationPaths.length > 1)
            DropdownButtonFormField<String>(
              value: _pathId ?? profile.derivationPaths.first.id,
              decoration: const InputDecoration(labelText: '派生路径', border: OutlineInputBorder()),
              items: [
                for (final p in profile.derivationPaths)
                  DropdownMenuItem(value: p.id, child: Text(p.label)),
              ],
              onChanged: (v) => setState(() => _pathId = v),
            ),
          if (_secretTab == _SecretTab.mnemonic && profile.derivationPaths.length > 1)
            const SizedBox(height: 12),
          TextField(
            controller: _secretTab == _SecretTab.mnemonic ? _mnemonic : _privateKey,
            maxLines: _secretTab == _SecretTab.mnemonic ? 4 : 3,
            style: _secretTab == _SecretTab.privateKey
                ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
                : null,
            decoration: InputDecoration(
              hintText: context.tr(_secretTab == _SecretTab.mnemonic
                  ? 'importMnemonicHint'
                  : 'importPrivateKeyHint'),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: Text(context.tr('back')))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _busy ? null : _preview, child: Text(_busy ? '解析中…' : '预览地址'))),
          ]),
        ],
      );
    }

    if (_step == 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('核对钱包地址', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              const Text('将导入地址', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              SelectableText(_previewAddress ?? '', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              Text(shortenAddress(_previewAddress ?? '', 8), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ),
          for (final w in _warnings)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(w, style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 2), child: const Text('重新输入'))),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (widget.mode == WalletImportMode.wallet) {
                          setState(() => _step = 4);
                        } else {
                          _import();
                        }
                      },
                child: Text(widget.mode == WalletImportMode.wallet ? '设置 PIN' : (_busy ? context.tr('importing') : '确认导入')),
              ),
            ),
          ]),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('设置 PIN 并导入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.tr('pinSetLabel'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.tr('pinConfirmLabel'), border: const OutlineInputBorder()),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 3), child: Text(context.tr('back')))),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _busy ? null : _import,
              child: Text(_busy ? context.tr('importing') : '完成导入'),
            ),
          ),
        ]),
      ],
    );
  }
}
