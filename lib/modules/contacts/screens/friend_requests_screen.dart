import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/shared/services/friends_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  late final FriendsService _friends;
  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _sent = [];
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
      final res = await _friends.listRequests();
      _inbox = res['inbox'] ?? [];
      _sent = res['sent'] ?? [];
    } catch (e) {
      AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('friendRequests')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.tr('friendRequestsInbox')),
              Tab(text: context.tr('friendRequestsSent')),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _inbox.isEmpty
                      ? _empty(context.tr('friendRequestsEmpty'))
                      : ListView(children: _inbox.map(_inboxTile).toList()),
                  _sent.isEmpty
                      ? _empty(context.tr('friendRequestsEmpty'))
                      : ListView(children: _sent.map(_sentTile).toList()),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showSearchDialog(context),
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }

  Widget _empty(String text) => Center(
        child: Text(text, style: TextStyle(color: Colors.grey.shade500)),
      );

  ListTile _inboxTile(Map<String, dynamic> r) {
    final from = (r['from_user'] ?? r['requester'] ?? {}) as Map;
    final name = (from['nickname'] ?? from['email'] ?? '用户') as String;
    final id = r['id']?.toString() ?? '';
    return ListTile(
      leading: CircleAvatar(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?')),
      title: Text(name),
      subtitle: Text((r['message'] ?? '') as String, style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              try {
                await _friends.accept(id);
                AppSnackBar.showInfo(context, context.tr('requestAccepted'));
                _load();
              } catch (e) {
                AppSnackBar.showError(context, e);
              }
            },
            child: Text(context.tr('accept')),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _friends.reject(id);
                AppSnackBar.showInfo(context, context.tr('requestRejected'));
                _load();
              } catch (e) {
                AppSnackBar.showError(context, e);
              }
            },
            child: Text(context.tr('reject')),
          ),
        ],
      ),
    );
  }

  ListTile _sentTile(Map<String, dynamic> r) {
    final to = (r['to_user'] ?? r['target'] ?? {}) as Map;
    final name = (to['nickname'] ?? to['email'] ?? '用户') as String;
    final status = (r['status'] ?? 'pending') as String;
    final id = r['id']?.toString() ?? '';
    return ListTile(
      leading: CircleAvatar(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?')),
      title: Text(name),
      subtitle: Text(status, style: const TextStyle(fontSize: 12)),
      trailing: status == 'pending'
          ? TextButton(
              onPressed: () async {
                try {
                  await _friends.cancel(id);
                  _load();
                } catch (e) {
                  AppSnackBar.showError(context, e);
                }
              },
              child: Text(context.tr('cancel')),
            )
          : null,
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final emailCtl = TextEditingController();
    final msgCtl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('addFriend')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtl,
              decoration: InputDecoration(
                labelText: context.tr('authEmail'),
                hintText: context.tr('searchByEmail'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtl,
              decoration: InputDecoration(
                labelText: context.tr('friendRequestMessageLabel'),
                hintText: context.tr('friendRequestMessageHint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: Text(context.tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtl.text.trim();
              if (email.isEmpty) return;
              try {
                final user = await _friends.searchExact(email);
                if (user == null) {
                  AppSnackBar.showErrorText(context, context.tr('userNotFound'));
                  return;
                }
                final state = (user['relation_state'] ?? 'none') as String;
                if (state == 'friend') {
                  AppSnackBar.showInfo(context, context.tr('alreadyFriend'));
                  return;
                }
                final userId = (user['id'] ?? user['user_id']) as String?;
                if (userId == null) return;
                await _friends.sendRequest(
                  toUserId: userId,
                  message: msgCtl.text.trim().isEmpty ? null : msgCtl.text.trim(),
                  source: 'email',
                );
                if (context.mounted) {
                  AppSnackBar.showInfo(context, context.tr('requestSent'));
                  Navigator.pop(_);
                  _load();
                }
              } catch (e) {
                AppSnackBar.showError(context, e);
              }
            },
            child: Text(context.tr('sendRequest')),
          ),
        ],
      ),
    );
  }
}
