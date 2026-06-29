import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/shared/services/referral_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late final ReferralService _svc;
  Map<String, dynamic>? _referral;
  Map<String, dynamic>? _detail;
  bool _loading = true;
  final _bindCtl = TextEditingController();
  bool _binding = false;

  @override
  void initState() {
    super.initState();
    _svc = ReferralService(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() { _bindCtl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _referral = await _svc.getMyReferral();
      _detail = await _svc.getReferralDetail();
    } catch (e) {
      AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bind() async {
    final code = _bindCtl.text.trim();
    if (code.isEmpty) return;
    setState(() => _binding = true);
    try {
      await _svc.bindReferrer(code);
      AppSnackBar.showInfo(context, context.tr('referralBindSuccess'));
      _bindCtl.clear();
      _load();
    } catch (e) {
      AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteCode = (_referral?['invite_code'] ?? _referral?['code'] ?? '') as String;
    final referrer = (_referral?['referrer_nickname'] ?? _referral?['referrer_email']) as String?;
    final directList = (_detail?['direct_referrals'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('referralTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _inviteCard(inviteCode),
                  const SizedBox(height: 16),
                  _referrerCard(referrer),
                  const SizedBox(height: 16),
                  _directListCard(directList),
                ],
              ),
            ),
    );
  }

  Widget _inviteCard(String code) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [SinpraTheme.brand600, SinpraTheme.brand800]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('referralInviteCode'),
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(code,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              AppSnackBar.showInfo(context, context.tr('copied'));
            },
          ),
        ]),
      ]),
    );
  }

  Widget _referrerCard(String? referrer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('referralReferrer'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (referrer != null && referrer.isNotEmpty)
          Text(referrer, style: const TextStyle(color: SinpraTheme.brand700))
        else ...[
          Text(context.tr('referralNoReferrer'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _bindCtl,
                decoration: InputDecoration(
                  hintText: context.tr('referralBindHint'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _binding ? null : _bind,
              child: _binding
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(context.tr('referralBindReferrer')),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _directListCard(List<dynamic> list) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('referralDirectList'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(context.tr('referralEmpty'), style: const TextStyle(color: Colors.grey, fontSize: 13))),
          )
        else
          ...list.map((e) {
            final m = e as Map<String, dynamic>;
            final name = (m['nickname'] ?? m['email'] ?? '用户') as String;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?')),
              title: Text(name, style: const TextStyle(fontSize: 14)),
              subtitle: Text((m['created_at'] ?? '') as String, style: const TextStyle(fontSize: 11)),
            );
          }),
      ]),
    );
  }
}
