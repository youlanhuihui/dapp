import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/brand.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/i18n/locale_controller.dart';
import 'package:sinpra_app/modules/auth/providers/auth_store.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthStore>();
      if (auth.user == null) await auth.fetchMe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final user = auth.user;
    final name = user?.displayName ?? '';
    final email = user?.email ?? '';
    final isNodeVip = user?.nodeVip ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('meTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _profileCard(name, email, isNodeVip),
          const SizedBox(height: 16),
          _menuTile(
            icon: Icons.account_balance_wallet_outlined,
            title: context.tr('menuWallet'),
            subtitle: context.tr('menuWalletDesc'),
            onTap: () => context.push('/settings/wallet'),
          ),
          _menuTile(
            icon: Icons.link,
            title: context.tr('menuReferral'),
            subtitle: context.tr('menuReferralDesc'),
            onTap: () => context.push('/settings/referral'),
          ),
          const SizedBox(height: 16),
          _languageTile(),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout, color: SinpraTheme.brand600),
            title: Text(context.tr('logout')),
            onTap: () => _logout(context),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('SINPRA · v0.1.0',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(String name, String email, bool isVip) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SinpraTheme.brand600, SinpraTheme.brand800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : AppBrand.logoLetter,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (isVip) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: SinpraTheme.gold400.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SinpraTheme.gold400),
                  ),
                  child: Text('👑 ${context.tr('nodeVipBadge')}',
                      style: const TextStyle(color: SinpraTheme.gold300, fontSize: 11)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(email,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFF1F5)),
      ),
      child: ListTile(
        leading: Icon(icon, color: SinpraTheme.brand600),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _languageTile() {
    final locale = context.watch<LocaleController>().locale;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFF1F5)),
      ),
      child: ListTile(
        leading: const Icon(Icons.language, color: SinpraTheme.brand600),
        title: Text(context.tr('language')),
        trailing: DropdownButton<String>(
          value: locale.languageCode,
          underline: const SizedBox(),
          items: [
            DropdownMenuItem(value: 'zh', child: Text(context.tr('languageChinese'))),
            DropdownMenuItem(value: 'en', child: Text(context.tr('languageEnglish'))),
          ],
          onChanged: (v) {
            if (v == null) return;
            context.read<LocaleController>().setLocale(v);
          },
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('logout')),
        content: Text(context.tr('logoutConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: Text(context.tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(_, true), child: Text(context.tr('logout'))),
        ],
      ),
    );
    if (ok != true) return;
    final auth = context.read<AuthStore>();
    final chat = context.read<ChatProvider>();
    chat.stop();
    await auth.logout();
    if (mounted) context.go('/login');
  }
}
