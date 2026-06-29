import 'package:dio/dio.dart';
import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/shared/models/conversation.dart';
import 'package:sinpra_app/shared/models/message.dart';

/// 聊天服务层：封装会话和消息相关 API 调用。
class ChatService {
  final ApiClient _api;
  ChatService({required ApiClient api}) : _api = api;

  Future<List<ConversationModel>> getConversations() async {
    final res = await _api.get(ApiEndpoints.conversations);
    final list = res.data as List<dynamic>;
    return list
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ConversationModel> createConversation({
    required String type,
    List<String> memberIds = const [],
    String? title,
  }) async {
    final res = await _api.post(
      ApiEndpoints.conversations,
      data: {
        'type': type,
        'member_ids': memberIds,
        if (title != null && title.isNotEmpty) 'title': title,
      },
    );
    return ConversationModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<MessageModel>> getMessages(
    String convId, {
    String? before,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (before != null) params['before'] = before;
    final res = await _api.get(
      ApiEndpoints.conversationMessages(convId),
      params: params,
    );
    final list = res.data as List<dynamic>;
    return list
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MessageModel> sendTextMessage(String convId, String text) async {
    final res = await _api.post(
      ApiEndpoints.conversationMessages(convId),
      data: {
        'message_type': 'text',
        'content_json': {'text': text},
      },
    );
    return MessageModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MessageModel> sendRedPacketCard(
    String convId, {
    required String packetId,
    required String tokenSymbol,
    required String totalAmount,
    required int packetCount,
    required String packetType,
    required String greeting,
    required String network,
  }) async {
    final res = await _api.post(
      ApiEndpoints.conversationMessages(convId),
      data: {
        'message_type': 'red_packet_card',
        'content_json': {
          'packet_id': packetId,
          'token_symbol': tokenSymbol,
          'total_amount': totalAmount,
          'packet_count': packetCount,
          'packet_type': packetType,
          'greeting': greeting,
          'network': network,
        },
      },
    );
    return MessageModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> claimRedPacket(
    String packetId, {
    required String address,
  }) async {
    final res = await _api.post(
      '${ApiEndpoints.redPacketClaim(packetId)}?address=${Uri.encodeComponent(address)}',
      data: {'address': address},
      options: Options(
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<MessageModel> sendEcosystemCard(
    String convId, {
    String? miniAppId,
    String? kind,
  }) async {
    final data = <String, dynamic>{};
    if (miniAppId != null) data['mini_app_id'] = miniAppId;
    if (kind != null) data['kind'] = kind;
    final res = await _api.post(
      ApiEndpoints.conversationEcosystemCards(convId),
      data: data,
    );
    return MessageModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getMembers(String convId) async {
    final res = await _api.get(ApiEndpoints.conversationMembers(convId));
    final list = res.data as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }
}
