import 'package:flutter/foundation.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/auth/auth_session.dart';
import 'package:sinpra_app/core/auth/token_manager.dart';
import 'package:sinpra_app/core/websocket/ws_client.dart';
import 'package:sinpra_app/shared/models/conversation.dart';
import 'package:sinpra_app/shared/models/message.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/shared/services/chat_service.dart';
import 'package:sinpra_app/shared/services/red_packet_service.dart';

/// 全局聊天状态：会话列表、当前会话消息、WebSocket 实时收发。
/// 不含「智能体模式 / 设备」等甲方不需要的概念。
class ChatProvider extends ChangeNotifier {
  final ApiClient _api;
  final WSClient _ws;
  late final ChatService _chat;
  EmbeddedWalletStore? _wallet;

  ChatProvider({required ApiClient apiClient, required WSClient wsClient})
      : _api = apiClient,
        _ws = wsClient {
    _chat = ChatService(api: _api);
  }

  void bindWallet(EmbeddedWalletStore wallet) => _wallet = wallet;

  List<ConversationModel> conversations = [];
  Map<String, List<MessageModel>> messagesByConv = {};
  String? currentConvId;
  bool loadingConversations = false;
  String? error;

  /// 登录成功后连接 WS 并订阅消息事件
  void start(String token, String userId) {
    AuthSession.userId = userId;
    _ws.setToken(token);
    _ws.connect();
    _ws.on('message.created', _onMessageCreated);
    _ws.on('conversation.created', _onConversationCreated);
  }

  void _onConversationCreated(Map<String, dynamic> data) {
    final conv = data['conversation'] ?? data;
    if (conv is Map<String, dynamic>) {
      conversations.insert(0, ConversationModel.fromJson(conv));
      notifyListeners();
    }
  }

  void _onMessageCreated(Map<String, dynamic> data) {
    final msg = data['message'] ?? data;
    if (msg is! Map<String, dynamic>) return;
    final m = MessageModel.fromJson(msg);
    final list = messagesByConv[m.conversationId];
    if (list != null && !list.any((e) => e.id == m.id)) {
      list.add(m);
      notifyListeners();
    }
    // 更新会话列表的 last_message
    final idx = conversations.indexWhere((c) => c.id == m.conversationId);
    if (idx >= 0) {
      final c = conversations[idx];
      conversations[idx] = ConversationModel(
        id: c.id,
        type: c.type,
        title: c.title,
        createdBy: c.createdBy,
        createdAt: c.createdAt,
        peerUserId: c.peerUserId,
        peerNickname: c.peerNickname,
        lastMessage: m.textContent.isNotEmpty ? m.textContent : m.messageType,
        lastMessageAt: m.createdAt,
        unreadCount: currentConvId == c.id ? 0 : c.unreadCount + 1,
      );
      notifyListeners();
    }
  }

  Future<void> loadConversations() async {
    loadingConversations = true;
    error = null;
    notifyListeners();
    try {
      conversations = await _chat.getConversations();
    } catch (e) {
      if (kDebugMode) print('[chat] loadConversations err: $e');
      error = e.toString();
    } finally {
      loadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> openConversation(String convId) async {
    currentConvId = convId;
    final idx = conversations.indexWhere((c) => c.id == convId);
    if (idx >= 0) {
      final c = conversations[idx];
      conversations[idx] = ConversationModel(
        id: c.id,
        type: c.type,
        title: c.title,
        createdBy: c.createdBy,
        createdAt: c.createdAt,
        peerUserId: c.peerUserId,
        peerNickname: c.peerNickname,
        lastMessage: c.lastMessage,
        lastMessageAt: c.lastMessageAt,
        unreadCount: 0,
      );
    }
    notifyListeners();
    if (!messagesByConv.containsKey(convId)) {
      try {
        final msgs = await _chat.getMessages(convId);
        // 接口返回最新在前，翻转为时间正序
        messagesByConv[convId] = msgs.reversed.toList();
      } catch (e) {
        messagesByConv[convId] = [];
        if (kDebugMode) print('[chat] loadMessages err: $e');
      }
      notifyListeners();
    }
  }

  Future<MessageModel?> sendText(String text) async {
    if (currentConvId == null || text.trim().isEmpty) return null;
    try {
      final msg = await _chat.sendTextMessage(currentConvId!, text.trim());
      final list = messagesByConv.putIfAbsent(currentConvId!, () => []);
      list.add(msg);
      notifyListeners();
      return msg;
    } catch (e) {
      if (kDebugMode) print('[chat] sendText err: $e');
      rethrow;
    }
  }

  Future<MessageModel> sendRedPacket({
    required String convId,
    required String fromAddress,
    required String? mint,
    required String symbol,
    required int decimals,
    required String totalAmount,
    required int packetCount,
    required String mode,
    required String greeting,
    void Function(String phase)? onProgress,
  }) async {
    final wallet = _wallet;
    if (wallet == null) throw Exception('钱包未初始化');
    final svc = RedPacketService(api: _api, wallet: wallet);
    final msg = await svc.sendInConversation(
      convId: convId,
      fromAddress: fromAddress,
      mint: mint,
      symbol: symbol,
      decimals: decimals,
      totalAmount: totalAmount,
      count: packetCount,
      mode: mode,
      greeting: greeting,
      onProgress: onProgress,
    );
    final list = messagesByConv.putIfAbsent(convId, () => []);
    list.add(msg);
    notifyListeners();
    return msg;
  }

  Future<String> claimRedPacket(
    String packetId, {
    required String address,
    String? conversationId,
  }) async {
    final res = await _chat.claimRedPacket(packetId, address: address);
    if (conversationId != null) {
      await openConversation(conversationId);
    }
    final amount = res['amount'];
    final symbol = res['symbol'] as String? ?? '';
    return amount != null ? '$amount $symbol' : '';
  }

  Future<MessageModel> sendEcosystemCard(
    String convId, {
    String? miniAppId,
    String? kind,
  }) async {
    final msg = await _chat.sendEcosystemCard(
      convId,
      miniAppId: miniAppId,
      kind: kind,
    );
    final list = messagesByConv.putIfAbsent(convId, () => []);
    list.add(msg);
    notifyListeners();
    return msg;
  }

  Future<ConversationModel?> createPrivateChat(String peerUserId) async {
    try {
      final conv = await _chat.createConversation(
        type: 'private',
        memberIds: [peerUserId],
      );
      if (!conversations.any((c) => c.id == conv.id)) {
        conversations.insert(0, conv);
        notifyListeners();
      }
      return conv;
    } catch (e) {
      if (kDebugMode) print('[chat] createPrivateChat err: $e');
      rethrow;
    }
  }

  void stop() {
    _ws.off('message.created', _onMessageCreated);
    _ws.off('conversation.created', _onConversationCreated);
    _ws.disconnect();
  }
}
