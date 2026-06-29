import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/shared/services/friends_service.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late final FriendsService _friends;
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _friends = FriendsService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _contacts = await _friends.getContacts();
    } catch (e) {
      AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startChat(Map<String, dynamic> c) async {
    final userId =
        (c['user_id'] ?? c['id'] ?? c['peer_user_id']) as String?;
    if (userId == null) return;
    try {
      final chat = context.read<ChatProvider>();
      final conv = await chat.createPrivateChat(userId);
      if (conv != null && mounted) {
        context.go('/conversations/${conv.id}');
      }
    } catch (e) {
      AppSnackBar.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('contactsTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/friends/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/friends/requests'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(context.tr('contactsEmpty'),
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _contacts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final c = _contacts[i];
                      final name = (c['nickname'] ?? c['email'] ?? '') as String;
                      final email = c['email'] as String? ?? '';
                      final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: SinpraTheme.brand100,
                          child: Text(initial,
                              style: const TextStyle(color: SinpraTheme.brand700, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name),
                        subtitle: email.isNotEmpty ? Text(email, style: const TextStyle(fontSize: 12)) : null,
                        trailing: OutlinedButton(
                          onPressed: () => _startChat(c),
                          child: Text(context.tr('startChat')),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'qr',
            onPressed: () => context.push('/friends/my-qr'),
            child: const Icon(Icons.qr_code),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => context.push('/friends/scan'),
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }
}
