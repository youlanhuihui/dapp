import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/modules/wallet/widgets/wallet_import_wizard.dart';
import 'package:sinpra_app/shared/utils/format.dart';

/// 账户与备份：多账户管理、导入、导出助记词/私钥、云端同步、移除钱包。
class WalletAccountsScreen extends StatefulWidget {
  const WalletAccountsScreen({super.key});

  @override
  State<WalletAccountsScreen> createState() => _WalletAccountsScreenState();
}

class _WalletAccountsScreenState extends State<WalletAccountsScreen> {
  bool _busy = false;
  bool _syncBusy = false;
  bool _importing = false;
  String? _error;
  final Map<String, TextEditingController> _labelCtrls = {};

  @override
  void dispose() {
    for (final c in _labelCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _labelCtrl(WalletAccount a) {
    return _labelCtrls.putIfAbsent(
      a.address,
      () => TextEditingController(text: a.label),
    );
  }

  Future<void> _addAccount(EmbeddedWalletStore w) async {
    setState(() { _busy = true; _error = null; });
    try {
      await w.addAccount();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove(EmbeddedWalletStore w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除钱包'),
        content: const Text(
          '确定从本机移除钱包？\n\n本机数据会删除，云端备份仍保留。请确保已备份助记词和导入账户私钥。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await w.removeWallet();
    if (mounted) context.go('/settings/wallet');
  }

  void _showSecretDialog({required String mode, String? address}) {
    showDialog(
      context: context,
      builder: (ctx) => _SecretDialog(mode: mode, address: address),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<EmbeddedWalletStore>();

    if (!w.isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('accounts'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('钱包已锁定，请先解锁'),
              TextButton(
                onPressed: () => context.go('/settings/wallet'),
                child: const Text('前往我的钱包 →'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(context.tr('accounts')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('我的账户',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('点击切换默认账户', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                ...w.accounts.map((a) => _accountTile(w, a)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _addAccount(w),
                  child: const Text('+ 新建账户'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _importing = true),
                  child: Text(context.tr('importAccount')),
                ),
              ),
            ],
          ),
          if (_importing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: WalletImportWizard(
                mode: WalletImportMode.account,
                onBack: () => setState(() => _importing = false),
                onSuccess: () => setState(() => _importing = false),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          if (w.cloudBackupAddress != null) ...[
            const SizedBox(height: 12),
            Text(
              '云端备份主地址：${w.cloudBackupAddress}',
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
            ),
          ],
          if (w.cloudSyncOk == false && w.cloudSyncMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SinpraTheme.amber300.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SinpraTheme.amber300.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(w.cloudSyncMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                  ),
                  TextButton(
                    onPressed: _syncBusy
                        ? null
                        : () async {
                            setState(() => _syncBusy = true);
                            await w.retryCloudSync();
                            if (mounted) setState(() => _syncBusy = false);
                          },
                    child: Text(_syncBusy ? '…' : '重试'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('导出助记词', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('恢复主钱包及全部 HD 账户', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _showSecretDialog(mode: 'mnemonic'),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('移除钱包', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
                  subtitle: const Text('仅从本机删除，链上资产不受影响', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _confirmRemove(w),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountTile(EmbeddedWalletStore w, WalletAccount a) {
    final isActive = a.address == w.activeAddress;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? SinpraTheme.brand400 : Colors.grey.shade200,
        ),
        color: isActive ? SinpraTheme.brand50 : null,
      ),
      child: ListTile(
        onTap: () => w.setActive(a.address),
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _labelCtrl(a),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (v) => w.setLabel(a.address, v),
                onTapOutside: (_) => w.setLabel(a.address, _labelCtrl(a).text),
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SinpraTheme.brand600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('默认', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(a.type == 'hd' ? 'HD' : '导入',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
        subtitle: Text(shortenAddress(a.address, 8),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        trailing: TextButton(
          onPressed: () => _showSecretDialog(mode: 'secret', address: a.address),
          child: const Text('导出私钥', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _SecretDialog extends StatefulWidget {
  final String mode;
  final String? address;
  const _SecretDialog({required this.mode, this.address});

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  final _pin = TextEditingController();
  String? _value;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _reveal() async {
    setState(() { _busy = true; _error = null; });
    try {
      final w = context.read<EmbeddedWalletStore>();
      final v = widget.mode == 'mnemonic'
          ? await w.exportMnemonic(_pin.text)
          : await w.exportSecret(widget.address!, _pin.text);
      setState(() => _value = v);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mode == 'mnemonic' ? '导出助记词' : '导出私钥'),
      content: _value == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.tr('unlockPinLabel')),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('请勿截图或分享，任何人获得它都能控制对应资产。',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SelectableText(_value!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(context.tr('copy')),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _value!));
                    AppSnackBar.showInfo(context, context.tr('copied'));
                  },
                ),
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
        if (_value == null)
          ElevatedButton(
            onPressed: _busy ? null : _reveal,
            child: _busy
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('查看'),
          )
        else
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
