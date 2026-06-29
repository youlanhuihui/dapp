import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/modules/auth/providers/auth_store.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';
import 'package:sinpra_app/modules/chat/widgets/message_bubble.dart';
import 'package:sinpra_app/modules/chat/widgets/ecosystem_sheet.dart';
import 'package:sinpra_app/modules/chat/widgets/red_packet_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _showActions = false;
  List<Map<String, dynamic>> _ecosystemPresets = [];
  bool _ecoLoading = false;
  String? _title;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ChatProvider>();
      p.openConversation(widget.conversationId);
      _loadTitle(p);
    });
  }

  void _loadTitle(ChatProvider p) {
    final c = p.conversations
        .where((e) => e.id == widget.conversationId)
        .firstOrNull;
    if (c != null) setState(() => _title = c.displayTitle);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      _input.clear();
      await context.read<ChatProvider>().sendText(text);
      _scrollToBottom();
    } catch (e) {
      AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openEcosystem() async {
    setState(() => _ecoLoading = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.get(ApiEndpoints.ecosystemPresets);
      final list = res.data as List<dynamic>;
      _ecosystemPresets =
          list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      _ecosystemPresets = [];
    } finally {
      setState(() => _ecoLoading = false);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EcosystemSheet(
        presets: _ecosystemPresets,
        loading: _ecoLoading,
        onSend: _sendEcosystem,
      ),
    );
  }

  Future<void> _sendEcosystem(Map<String, dynamic> preset) async {
    final p = context.read<ChatProvider>();
    final kind = preset['kind'] as String?;
    final isBuiltin = kind == 'staking' || kind == 'node';
    await p.sendEcosystemCard(
      widget.conversationId,
      kind: kind,
      miniAppId: isBuiltin ? null : preset['mini_app_id'] as String?,
    );
    _scrollToBottom();
  }

  Future<void> _openRedPacket() async {
    final wallet = context.read<EmbeddedWalletStore>();
    if (!wallet.isUnlocked) {
      AppSnackBar.showErrorText(context, context.tr('bizConnectFirst'));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => RedPacketSheet(
        conversationId: widget.conversationId,
        onSent: () async {
          await context.read<ChatProvider>().openConversation(widget.conversationId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title ?? context.tr('navChats'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, p, _) {
                final msgs = p.messagesByConv[widget.conversationId] ?? [];
                if (msgs.isEmpty) {
                  return Center(
                    child: Text(context.tr('empty'),
                        style: TextStyle(color: Colors.grey.shade400)),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    return MessageBubble(
                      message: m,
                      isMe: _isMe(m, context),
                      conversationId: widget.conversationId,
                    );
                  },
                );
              },
            ),
          ),
          _inputBar,
        ],
      ),
    );
  }

  bool _isMe(message, BuildContext context) {
    if (message.isSystem) return false;
    final auth = context.read<AuthStore>();
    return message.senderId == auth.user?.userId;
  }

  Widget get _inputBar => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showActions) _actionRow,
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _showActions = !_showActions),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.tr('messageInputHint'),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: SinpraTheme.brand600,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, size: 20),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget get _actionRow => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _actionTile(Icons.card_giftcard, context.tr('redPacket'),
                const Color(0xFFE53935), _openRedPacket),
            _actionTile(Icons.account_balance_wallet, context.tr('transfer'),
                const Color(0xFFFFB300), () => AppSnackBar.showInfo(context, context.tr('transfer'))),
            _actionTile(Icons.apps, context.tr('ecosystem'),
                SinpraTheme.brand600, _openEcosystem),
          ],
        ),
      );

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
