import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/wallet/wallet_token_balances.dart';
import 'package:sinpra_app/core/wallet/wallet_transfer.dart';
import 'package:sinpra_app/shared/services/wallet_api_service.dart';

class WalletTransferScreen extends StatefulWidget {
  const WalletTransferScreen({super.key});

  @override
  State<WalletTransferScreen> createState() => _WalletTransferScreenState();
}

class _WalletTransferScreenState extends State<WalletTransferScreen> {
  final _to = TextEditingController();
  final _amount = TextEditingController();
  final _memo = TextEditingController();
  final _pin = TextEditingController();
  String _mint = 'SOL';
  List<TokenBalance> _balances = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    _memo.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final w = context.read<EmbeddedWalletStore>();
    final addr = w.activeAddress;
    if (addr == null) return;
    setState(() => _loading = true);
    try {
      final known = await WalletApiService(context.read()).getMyTokens();
      _balances = await WalletTokenBalances().listBalances(addr, known);
    } catch (_) {
      _balances = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TokenBalance? get _selected => _mint == 'SOL'
      ? _balances.where((b) => b.mint == null).firstOrNull
      : _balances.where((b) => b.mint == _mint).firstOrNull;

  Future<void> _submit() async {
    final to = _to.text.trim();
    final amt = _amount.text.trim();
    if (to.length < 32) {
      AppSnackBar.showErrorText(context, '收款地址格式不正确');
      return;
    }
    if (double.tryParse(amt) == null || double.parse(amt) <= 0) {
      AppSnackBar.showErrorText(context, context.tr('withdrawEnterAmount'));
      return;
    }
    if (_pin.text.length < 6) {
      AppSnackBar.showErrorText(context, context.tr('pinErrorLength'));
      return;
    }
    final w = context.read<EmbeddedWalletStore>();
    if (!await w.verifyPin(_pin.text)) {
      AppSnackBar.showErrorText(context, 'PIN 码错误');
      return;
    }
    final from = w.activeAddress;
    if (from == null) return;
    setState(() => _busy = true);
    try {
      final sig = await sendWalletTransfer(
        wallet: w,
        fromAddress: from,
        toAddress: to,
        mint: _mint == 'SOL' ? null : _mint,
        decimals: _selected?.decimals ?? 9,
        uiAmount: amt,
        memo: _memo.text.trim().isEmpty ? null : _memo.text,
      );
      if (!mounted) return;
      AppSnackBar.showInfo(context, '转账成功：${sig.substring(0, 8)}…');
      context.pop();
    } catch (e) {
      AppSnackBar.showErrorText(context, formatTransferError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<EmbeddedWalletStore>();
    if (!w.isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('transferOut'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('钱包已锁定，请先解锁'),
              TextButton(onPressed: () => context.go('/settings/wallet'), child: const Text('前往我的钱包')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(context.tr('transferOut')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<String>(
                  value: _mint,
                  decoration: const InputDecoration(labelText: '转账币种'),
                  items: [
                    if (_balances.any((b) => b.mint == null))
                      const DropdownMenuItem(value: 'SOL', child: Text('SOL')),
                    ..._balances.where((b) => b.mint != null).map((b) => DropdownMenuItem(
                          value: b.mint!,
                          child: Text('${b.symbol} (${b.uiAmount})'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _mint = v ?? 'SOL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _to,
                  decoration: const InputDecoration(labelText: '收款地址'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '金额',
                    suffixText: _selected?.symbol,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _memo,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.tr('unlockPinLabel')),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: SinpraTheme.brand600),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(context.tr('transferOut'), style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
    );
  }
}
