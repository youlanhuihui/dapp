import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/config/app_config.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/wallet/fund_red_packet.dart';
import 'package:sinpra_app/core/wallet/wallet_token_balances.dart';
import 'package:sinpra_app/shared/services/wallet_api_service.dart';

/// 聊天发红包面板：币种选择 + 拼手气/普通 + PIN 确认 + 上链注资。
class RedPacketSheet extends StatefulWidget {
  final String conversationId;
  final Future<void> Function() onSent;

  const RedPacketSheet({
    super.key,
    required this.conversationId,
    required this.onSent,
  });

  @override
  State<RedPacketSheet> createState() => _RedPacketSheetState();
}

class _RedPacketSheetState extends State<RedPacketSheet> {
  final _amount = TextEditingController();
  final _count = TextEditingController(text: '1');
  final _greeting = TextEditingController(text: '恭喜发财，大吉大利');
  final _pin = TextEditingController();
  String _type = 'random';
  String _mint = 'SOL';
  List<TokenBalance> _balances = [];
  bool _loadingBal = true;
  bool _busy = false;
  String _phase = '';

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  @override
  void dispose() {
    _amount.dispose();
    _count.dispose();
    _greeting.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    final w = context.read<EmbeddedWalletStore>();
    final addr = w.activeAddress;
    if (addr == null) return;
    setState(() => _loadingBal = true);
    try {
      final known = await WalletApiService(context.read()).getMyTokens();
      _balances = await WalletTokenBalances().listBalances(addr, known);
      if (_balances.isNotEmpty && !_balances.any((b) => b.mint == null)) {
        _mint = _balances.first.mint ?? 'SOL';
      }
    } catch (_) {
      _balances = [];
    } finally {
      if (mounted) setState(() => _loadingBal = false);
    }
  }

  TokenBalance? get _selected => _mint == 'SOL'
      ? _balances.where((b) => b.mint == null).firstOrNull
      : _balances.where((b) => b.mint == _mint).firstOrNull;

  Future<void> _send() async {
    final amt = _amount.text.trim();
    final cnt = int.tryParse(_count.text.trim()) ?? 0;
    final t = double.tryParse(amt);
    if (t == null || t <= 0) {
      AppSnackBar.showErrorText(context, context.tr('withdrawEnterAmount'));
      return;
    }
    if (cnt < 1 || cnt > 100) {
      AppSnackBar.showErrorText(context, '红包个数 1-100');
      return;
    }
    if (_mint == 'SOL') {
      final rentErr = validateSolRedPacketAmount(t);
      if (rentErr != null) {
        AppSnackBar.showErrorText(context, rentErr);
        return;
      }
    }
    final sel = _selected;
    if (sel != null && t > sel.uiAmount) {
      AppSnackBar.showErrorText(context, '余额不足（含手续费需预留少量 SOL）');
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
      setState(() => _phase = '创建红包…');
      final api = context.read<ApiClient>();
      final created = await api.post(ApiEndpoints.redPackets, data: {
        'mint': _mint == 'SOL' ? null : _mint,
        'symbol': sel?.symbol ?? 'SOL',
        'decimals': sel?.decimals ?? 9,
        'network': AppConfig.isDevnet ? 'devnet' : 'mainnet-beta',
        'sender_address': from,
        'total_amount': amt,
        'count': cnt,
        'mode': _type,
        'greeting': _greeting.text.trim(),
      });
      final data = created.data as Map<String, dynamic>;

      setState(() => _phase = '链上注资…');
      final fundSig = await fundRedPacket(
        wallet: w,
        fromAddress: from,
        escrowAddress: data['escrow_address'] as String,
        mint: _mint == 'SOL' ? null : _mint,
        decimals: sel?.decimals ?? 9,
        totalBase: data['total_base'] as String,
        solBuffer: (data['sol_buffer'] as num).toInt(),
      );

      setState(() => _phase = '确认激活…');
      await api.post(
        ApiEndpoints.redPacketFund(data['id'] as String),
        data: {'fund_tx': fundSig},
      );

      setState(() => _phase = '发送消息…');
      await api.post(
        ApiEndpoints.conversationMessages(widget.conversationId),
        data: {
          'message_type': 'red_packet_card',
          'content_json': {
            'packet_id': data['id'],
            'token_symbol': sel?.symbol ?? 'SOL',
            'total_amount': amt,
            'packet_count': cnt,
            'packet_type': _type,
            'greeting': _greeting.text.trim(),
            'network': AppConfig.isDevnet ? 'devnet' : 'mainnet-beta',
          },
        },
      );

      await widget.onSent();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final friendly = friendlyRedPacketError(e);
      if (mounted) {
        AppSnackBar.showErrorText(context, friendly ?? e.toString());
      }
    } finally {
      if (mounted) setState(() { _busy = false; _phase = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🧧 ${context.tr('redPacket')}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE53935))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              if (_loadingBal)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: _balances.any((b) => (_mint == 'SOL' ? b.mint == null : b.mint == _mint))
                      ? _mint
                      : (_balances.any((b) => b.mint == null) ? 'SOL' : _balances.first.mint ?? 'SOL'),
                  decoration: const InputDecoration(labelText: '红包币种'),
                  items: [
                    if (_balances.any((b) => b.mint == null))
                      const DropdownMenuItem(value: 'SOL', child: Text('SOL')),
                    ..._balances.where((b) => b.mint != null).map((b) => DropdownMenuItem(
                          value: b.mint!,
                          child: Text('${b.symbol} (余额 ${b.uiAmount})'),
                        )),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _mint = v ?? 'SOL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '总金额 (${_selected?.symbol ?? 'SOL'})',
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _count,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '红包个数',
                    prefixIcon: Icon(Icons.card_giftcard),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _greeting,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: '祝福语'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('拼手气'),
                        selected: _type == 'random',
                        onSelected: _busy ? null : (_) => setState(() => _type = 'random'),
                        selectedColor: const Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('普通'),
                        selected: _type == 'equal',
                        onSelected: _busy ? null : (_) => setState(() => _type = 'equal'),
                        selectedColor: const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pin,
                  enabled: !_busy,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.tr('unlockPinLabel')),
                ),
              ],
              if (_phase.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_phase, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                  onPressed: _busy || _loadingBal ? null : _send,
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('塞钱进红包', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
