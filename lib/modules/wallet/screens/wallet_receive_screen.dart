import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/wallet/solana_pay.dart';
import 'package:sinpra_app/shared/services/wallet_api_service.dart';
import 'package:sinpra_app/shared/utils/format.dart';

class WalletReceiveScreen extends StatefulWidget {
  const WalletReceiveScreen({super.key});

  @override
  State<WalletReceiveScreen> createState() => _WalletReceiveScreenState();
}

class _WalletReceiveScreenState extends State<WalletReceiveScreen> {
  List<Map<String, dynamic>> _known = [];
  String _mint = 'SOL';
  final _amount = TextEditingController();
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadTokens() async {
    try {
      _known = await WalletApiService(context.read()).getMyTokens();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<EmbeddedWalletStore>();
    final addr = w.activeAddress ?? '';
    final symbol = _mint == 'SOL'
        ? 'SOL'
        : (_known.where((k) => k['mint_address'] == _mint).firstOrNull?['symbol'] as String? ?? '代币');
    final payUrl = addr.isEmpty
        ? ''
        : buildPayUrl(
            recipient: addr,
            amount: _amount.text.trim().isEmpty ? null : _amount.text.trim(),
            splToken: _mint == 'SOL' ? null : _mint,
            label: w.accounts.where((a) => a.address == addr).firstOrNull?.label,
          );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(context.tr('receive')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                if (payUrl.isNotEmpty)
                  QrImageView(data: payUrl, size: 220, backgroundColor: Colors.white),
                const SizedBox(height: 16),
                Text(
                  _amount.text.trim().isEmpty
                      ? '扫码向我支付 $symbol'
                      : '请向我支付 ${_amount.text.trim()} $symbol',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: addr));
                    setState(() => _copied = true);
                    AppSnackBar.showInfo(context, context.tr('copied'));
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: SinpraTheme.brand50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(shortenAddress(addr, 8),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        const SizedBox(width: 8),
                        Text(_copied ? context.tr('copied') : context.tr('copy'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _mint,
                  decoration: const InputDecoration(labelText: '收款币种'),
                  items: [
                    const DropdownMenuItem(value: 'SOL', child: Text('SOL')),
                    ..._known.map((t) => DropdownMenuItem(
                          value: t['mint_address'] as String,
                          child: Text(t['symbol'] as String? ?? ''),
                        )),
                  ],
                  onChanged: (v) => setState(() => _mint = v ?? 'SOL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '金额（可选）'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
