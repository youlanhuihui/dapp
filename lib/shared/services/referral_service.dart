import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';

/// 推荐关系服务。
class ReferralService {
  final ApiClient _api;
  ReferralService(this._api);

  /// 我的邀请码与推荐人
  Future<Map<String, dynamic>> getMyReferral() async {
    final res = await _api.get(ApiEndpoints.userReferral);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 直推列表
  Future<Map<String, dynamic>> getReferralDetail() async {
    final res = await _api.get(ApiEndpoints.userReferralDetail);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// 绑定推荐人
  Future<void> bindReferrer(String inviteCode) async {
    await _api.post(
      ApiEndpoints.userReferralAttribution,
      data: {'ref': inviteCode, 'biz': 'contract'},
    );
  }
}
