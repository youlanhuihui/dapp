import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';

class RedPacketDetailScreen extends StatefulWidget {
  final String packetId;
  final String? conversationId;

  const RedPacketDetailScreen({
    super.key,
    required this.packetId,
    this.conversationId,
  });

  @override
  State<RedPacketDetailScreen> createState() => _RedPacketDetailScreenState();
}

class _RedPacketDetailScreenState extends State<RedPacketDetailScreen> {
  Map<String, dynamic>? _packet;
  bool _loading = true;
  bool _claiming = false;
  String? _error;
  String? _justGot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await context.read<ApiClient>().get('${ApiEndpoints.redPackets}/${widget.packetId}');
      _packet = res.data as Map<String, dynamic>;
      _error = null;
    } catch (_) {
      _packet = null;
      _error = '红包不存在或已失效';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim() async {
    final wallet = context.read<EmbeddedWalletStore>();
    final addr = wallet.activeAddress;
    if (addr == null || !wallet.isUnlocked) {
      AppSnackBar.showErrorText(context, '请先在「我的钱包」解锁钱包后再领取');
      return;
    }

    setState(() => _claiming = true);
    try {
      final amount = await context.read<ChatProvider>().claimRedPacket(
            widget.packetId,
            address: addr,
            conversationId: widget.conversationId,
          );
      if (!mounted) return;
      setState(() => _justGot = amount);
      await _load();
      AppSnackBar.showInfo(context, '领取成功：$amount');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('redPacket')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _packet == null
              ? Center(child: Text(_error ?? '红包不存在'))
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final p = _packet!;
    final symbol = p['symbol'] as String? ?? 'USTD';
    final greeting = p['greeting'] as String? ?? '恭喜发财';
    final status = p['status'] as String? ?? 'active';
    final isSender = p['is_sender'] as bool? ?? false;
    final myClaim = p['my_claim'] as String?;
    final received = myClaim ?? _justGot?.split(' ').first;
    final canClaim =
        status == 'active' && myClaim == null && !isSender && _justGot == null;
    final claims = (p['claims'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFEF5350)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('🧧', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                '${p['sender_nickname'] ?? '好友'} 的红包',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(greeting,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (received != null)
                Text('$received $symbol',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold))
              else if (canClaim)
                GestureDetector(
                  onTap: _claiming ? null : _claim,
                  child: Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD54F),
                      shape: BoxShape.circle,
                    ),
                    child: _claiming
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('開',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC62828))),
                  ),
                )
              else
                Text(
                  isSender
                      ? '这是你发出的红包，请等待好友领取'
                      : status == 'finished'
                          ? '手慢了，红包已被领完'
                          : status == 'refunded'
                              ? '红包已过期退回'
                              : '红包未就绪',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (claims.isNotEmpty) ...[
          const Text('领取记录', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...claims.map((c) {
            final m = c as Map<String, dynamic>;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(m['nickname'] as String? ?? shortenAddr(m['address'])),
              trailing: Text('${m['amount']} $symbol'),
            );
          }),
        ],
      ],
    );
  }

  String shortenAddr(dynamic addr) {
    final s = addr?.toString() ?? '';
    if (s.length <= 10) return s;
    return '${s.substring(0, 4)}…${s.substring(s.length - 4)}';
  }
}
