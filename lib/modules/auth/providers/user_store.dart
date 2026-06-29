import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/shared/models/user.dart';

/// 当前用户昵称编辑（与 Web settings 一致：每 UTC 天可改一次）。
class UserStore {
  final ApiClient _api;
  UserStore(this._api);

  bool isSameUtcDay(DateTime a, DateTime b) =>
      a.toIso8601String().substring(0, 10) == b.toIso8601String().substring(0, 10);

  bool canChangeNicknameToday(String? updatedAt) {
    if (updatedAt == null || updatedAt.isEmpty) return true;
    return !isSameUtcDay(DateTime.parse(updatedAt), DateTime.now());
  }

  Future<User> updateNickname(String nickname) async {
    final res = await _api.put('/users/me', data: {'nickname': nickname.trim()});
    return User.fromMe(res.data as Map<String, dynamic>);
  }
}
