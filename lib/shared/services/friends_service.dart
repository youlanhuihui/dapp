import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';

/// 联系人 / 好友 / 扫码 服务。
class FriendsService {
  final ApiClient _api;
  FriendsService(this._api);

  /// 联系人列表
  Future<List<Map<String, dynamic>>> getContacts() async {
    final res = await _api.get(ApiEndpoints.contacts);
    final list = res.data as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 按邮箱精确搜索（含 relation_state）
  Future<Map<String, dynamic>?> searchExact(String email) async {
    final res = await _api.get(
      ApiEndpoints.userSearchExact,
      params: {'email': email},
    );
    if (res.data == null) return null;
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return null;
  }

  /// 发送好友申请
  Future<void> sendRequest({
    required String toUserId,
    String? message,
    String? source,
  }) async {
    await _api.post(
      ApiEndpoints.friendRequests,
      data: {
        'to_user_id': toUserId,
        if (message != null && message.isNotEmpty) 'message': message,
        if (source != null) 'source': source,
      },
    );
  }

  /// 好友申请列表
  Future<Map<String, List<Map<String, dynamic>>>> listRequests() async {
    final res = await _api.get(ApiEndpoints.friendRequests);
    final data = res.data as Map<String, dynamic>;
    final inbox = ((data['inbox'] ?? data['received']) as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    final sent = (data['sent'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    return {'inbox': inbox, 'sent': sent};
  }

  Future<void> accept(String id) =>
      _api.post(ApiEndpoints.friendRequestAccept(id));
  Future<void> reject(String id) =>
      _api.post(ApiEndpoints.friendRequestReject(id));
  Future<void> cancel(String id) =>
      _api.post(ApiEndpoints.friendRequestCancel(id));

  Future<void> removeContact(String userId) =>
      _api.delete(ApiEndpoints.contactById(userId));

  /// 我的二维码 payload
  Future<String> getMyQrPayload() async {
    final res = await _api.get(ApiEndpoints.userMyQr);
    return (res.data['payload'] as String?) ?? '';
  }

  Future<String> refreshMyQrPayload() async {
    final res = await _api.post(ApiEndpoints.userMyQrRefresh);
    return (res.data['payload'] as String?) ?? '';
  }

  /// 扫码好友二维码（含 relation_state）
  Future<Map<String, dynamic>> scanUserQr(String payload) async {
    final res = await _api.post(
      ApiEndpoints.friendsScanQr,
      data: {'payload': payload},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }
}
