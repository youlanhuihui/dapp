import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/config/app_config.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/shared/utils/format.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  static const _kindLabel = {
    'send': '转账',
    'receive': '收款',
    'redpacket_send': '发红包',
    'redpacket_claim': '领红包',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<ApiClient>().get(ApiEndpoints.walletTx);
      final list = res.data as List<dynamic>;
      _items = list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      _items = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('txHistory')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Center(
                          child: Text(context.tr('empty'),
                              style: TextStyle(color: Colors.grey.shade500)),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final t = _items[i];
                      final kind = t['kind'] as String? ?? '';
                      final outgoing =
                          kind == 'send' || kind == 'redpacket_send';
                      final symbol = t['symbol'] as String? ?? '';
                      final amount = t['amount'] as String? ?? '';
                      final sig = t['signature'] as String?;
                      final network = t['network'] as String? ??
                          (AppConfig.isDevnet ? 'devnet' : 'mainnet-beta');
                      final from = t['from_address'] as String?;
                      final to = t['to_address'] as String?;
                      final memo = t['memo'] as String?;
                      final created = t['created_at'] as String?;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${_kindLabel[kind] ?? kind}${memo != null && memo.isNotEmpty ? ' · $memo' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${outgoing ? '给 ${shortenAddress(to ?? '', 4)}' : '来自 ${shortenAddress(from ?? '', 4)}'}'
                          '${created != null ? ' · $created' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${outgoing ? '-' : '+'}$amount $symbol',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: outgoing
                                    ? Colors.grey.shade900
                                    : SinpraTheme.emerald500,
                              ),
                            ),
                            if (sig != null && sig.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  final cluster =
                                      network == 'devnet' ? '?cluster=devnet' : '';
                                  launchUrl(
                                    Uri.parse(
                                        'https://solscan.io/tx/$sig$cluster'),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('查看', style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
