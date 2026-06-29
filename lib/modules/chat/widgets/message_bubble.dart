import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/shared/models/message.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String conversationId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.textContent,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    final bubbleColor = isMe ? SinpraTheme.brand600 : Colors.white;
    final textColor = isMe ? Colors.white : const Color(0xFF111827);

    Widget content;
    switch (message.messageType) {
      case 'red_packet':
      case 'red_packet_card':
        content = _RedPacketBubble(
          content: message.contentJson,
          isMe: isMe,
          conversationId: conversationId,
        );
        break;
      case 'transfer_card':
        content = _TransferBubble(content: message.contentJson, isMe: isMe);
        break;
      case 'ecosystem_card':
        content = _EcosystemBubble(content: message.contentJson, isMe: isMe);
        break;
      default:
        content = Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
            boxShadow: [
              if (!isMe)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Text(
            message.textContent,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
          ),
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: content),
        ],
      ),
    );
  }
}

class _RedPacketBubble extends StatelessWidget {
  final Map<String, dynamic> content;
  final bool isMe;
  final String conversationId;

  const _RedPacketBubble({
    required this.content,
    required this.isMe,
    required this.conversationId,
  });

  void _open(BuildContext context) {
    final packetId = content['packet_id'] as String?;
    if (packetId == null || packetId.isEmpty) return;
    context.push(
      '/red-packets/$packetId?conv=${Uri.encodeComponent(conversationId)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = content['token_symbol'] as String? ?? 'USTD';
    final amount = content['total_amount'] as String? ?? '';
    final greeting = content['greeting'] as String? ?? '恭喜发财，大吉大利';
    final status = content['status'] as String? ?? 'pending';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text('红包',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ]),
              const SizedBox(height: 6),
              Text(greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('$amount $symbol',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                status == 'claimed'
                    ? '已领取'
                    : status == 'expired'
                        ? '已过期'
                        : '点击查看 ›',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferBubble extends StatelessWidget {
  final Map<String, dynamic> content;
  final bool isMe;
  const _TransferBubble({required this.content, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final symbol = content['token_symbol'] as String? ?? 'SOL';
    final amount = content['amount'] as String? ?? '';
    final status = content['status'] as String? ?? 'pending';
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.account_balance_wallet, color: Colors.white, size: 26),
            SizedBox(width: 8),
            Text('转账',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          Text('$amount $symbol',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18)),
          if (status != 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                status == 'claimed'
                    ? '已收款'
                    : status == 'expired'
                        ? '已过期'
                        : status,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _EcosystemBubble extends StatelessWidget {
  final Map<String, dynamic> content;
  final bool isMe;
  const _EcosystemBubble({required this.content, required this.isMe});

  String get _title => content['title'] as String? ?? '生态卡片';
  String get _desc => content['description'] as String? ?? '';
  String get _url => content['url'] as String? ?? '';
  String get _actionLabel => content['action_label'] as String? ?? '打开';
  String get _openMode => content['open_mode'] as String? ?? 'webview';

  Future<void> _open(BuildContext context) async {
    if (_url.isEmpty) return;
    if (_openMode == 'browser') {
      final uri = Uri.parse(_url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (!context.mounted) return;
    context.push(
      '/mini-app?title=${Uri.encodeComponent(_title)}&url=${Uri.encodeComponent(_url)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SinpraTheme.brand50,
            border: Border.all(color: SinpraTheme.brand200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.apps, color: SinpraTheme.brand600, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: SinpraTheme.brand700)),
                ),
              ]),
              if (_desc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: 8),
              Text('$_actionLabel ›',
                  style: const TextStyle(
                      fontSize: 12, color: SinpraTheme.brand600)),
            ],
          ),
        ),
      ),
    );
  }
}
