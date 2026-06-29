import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/auth/auth_session.dart';
import 'package:sinpra_app/core/auth/token_manager.dart';
import 'package:sinpra_app/shared/models/user.dart';

/// 鉴权状态：当前用户、登录/注册/登出。
class AuthStore extends ChangeNotifier {
  final ApiClient _api;
  final TokenManager _tokenManager;
  AuthStore({required ApiClient api, required TokenManager tokenManager})
      : _api = api,
        _tokenManager = tokenManager;

  User? user;
  bool loading = false;

  bool get isLoggedIn => user != null;

  Future<void> login({required String email, required String password}) async {
    final res = await _api.post(ApiEndpoints.login, data: {
      'email': email.trim(),
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || access.isEmpty || refresh == null) {
      throw Exception('登录失败：邮箱或密码错误');
    }
    await _tokenManager.saveTokens(access, refresh);
    AuthSession.isAuthenticated.value = true;
    // 解析 userId
    final decoded = JwtDecoder.decode(access);
    AuthSession.userId = (decoded['sub'] ?? decoded['user_id']) as String?;
    await fetchMe();
  }

  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    await _api.post(ApiEndpoints.register, data: {
      'email': email.trim(),
      'password': password,
      'nickname': nickname.trim(),
    });
  }

  Future<void> fetchMe() async {
    try {
      final res = await _api.get(ApiEndpoints.currentUser);
      user = User.fromMe(res.data as Map<String, dynamic>);
      AuthSession.userId = user!.userId;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[auth] fetchMe err: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.logout);
    } catch (_) {}
    await _tokenManager.clearTokens();
    AuthSession.clear();
    user = null;
    notifyListeners();
  }

  Future<void> tryRestoreSession() async {
    final loggedIn = await _tokenManager.isLoggedIn();
    if (!loggedIn) return;
    AuthSession.isAuthenticated.value = true;
    await fetchMe();
  }
}
