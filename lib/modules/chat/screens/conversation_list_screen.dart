import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('navChats'))),
      body: Consumer<ChatProvider>(
        builder: (context, p, _) {
          if (p.loadingConversations && p.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (p.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(context.tr('noConversations'),
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => p.loadConversations(),
            child: ListView.separated(
              itemCount: p.conversations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 76),
              itemBuilder: (context, i) {
                final c = p.conversations[i];
                final isGroup = c.isGroup;
                final initial = c.displayTitle.isNotEmpty
                    ? c.displayTitle.substring(0, 1)
                    : '?';
                return ListTile(
                  onTap: () {
                    context.go('/conversations/${c.id}');
                  },
                  leading: CircleAvatar(
                    backgroundColor: isGroup
                        ? const Color(0xFF8B5CF6)
                        : SinpraTheme.brand100,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: isGroup ? Colors.white : SinpraTheme.brand700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isGroup) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.group, size: 14, color: Colors.grey),
                      ],
                    ],
                  ),
                  subtitle: c.lastMessage == null
                      ? null
                      : Text(
                          c.lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (c.lastMessageAt != null)
                        Text(
                          _shortTime(c.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      if (c.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SinpraTheme.brand600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${c.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/contacts'),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _shortTime(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}/${t.day}';
  }
}
