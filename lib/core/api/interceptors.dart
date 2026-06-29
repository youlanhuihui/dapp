import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:sinpra_app/core/auth/auth_session.dart';
import 'package:sinpra_app/core/auth/token_manager.dart';
import 'api_endpoints.dart';

/// JWT 鉴权拦截器：
/// 1. onRequest 预检：剩余寿命 < 60s 主动 refresh
/// 2. onError 401：singleflight 共享同一个 refresh future
/// 3. refresh 失败：clearTokens + AuthSession.clear() → 路由自动跳 /login
class AuthInterceptor extends Interceptor {
  final TokenManager _tokenManager = TokenManager();
  static Future<String?>? _refreshing;

  static const _noAuthPaths = <String>{
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/refresh-token',
  };
  static const Duration _preRefreshThreshold = Duration(seconds: 60);

  bool _isNoAuthPath(String path) =>
      _noAuthPaths.any((p) => path.endsWith(p));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isNoAuthPath(options.path)) return handler.next(options);

    String? token = await _tokenManager.getAccessToken();
    if (token == null || token.isEmpty) return handler.next(options);

    if (_isExpiringSoon(token)) {
      final fresh = await _sharedRefresh(options.baseUrl);
      if (fresh != null) token = fresh;
    }
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final isRefreshCall = _isNoAuthPath(req.path);
    final alreadyRetried = req.extra['_retried'] == true;
    if (err.response?.statusCode != 401 ||
        isRefreshCall ||
        alreadyRetried) {
      return handler.next(err);
    }
    final fresh = await _sharedRefresh(req.baseUrl);
    if (fresh == null) return handler.next(err);
    try {
      final retryOptions = req
        ..headers['Authorization'] = 'Bearer $fresh'
        ..extra['_retried'] = true;
      final dio = Dio(BaseOptions(
        baseUrl: retryOptions.baseUrl,
        connectTimeout: retryOptions.connectTimeout,
        receiveTimeout: retryOptions.receiveTimeout,
      ));
      final response = await dio.fetch(retryOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<String?> _sharedRefresh(String baseUrl) {
    _refreshing ??= _doRefresh(baseUrl).whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  Future<String?> _doRefresh(String baseUrl) async {
    final refreshToken = await _tokenManager.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      _onRefreshFailed();
      return null;
    }
    try {
      final dio = Dio();
      final response = await dio.post(
        '$baseUrl${ApiEndpoints.refreshToken}',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      if (data is! Map) {
        _onRefreshFailed();
        return null;
      }
      final newAccess = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;
      if (newAccess == null ||
          newAccess.isEmpty ||
          newRefresh == null ||
          newRefresh.isEmpty) {
        _onRefreshFailed();
        return null;
      }
      await _tokenManager.saveTokens(newAccess, newRefresh);
      return newAccess;
    } catch (_) {
      _onRefreshFailed();
      return null;
    }
  }

  void _onRefreshFailed() {
    _tokenManager.clearTokens();
    AuthSession.clear();
  }

  bool _isExpiringSoon(String token) {
    try {
      final exp = JwtDecoder.getExpirationDate(token);
      return exp.isBefore(DateTime.now().add(_preRefreshThreshold));
    } catch (_) {
      return true;
    }
  }
}

/// 便于在非 widget 处直接构造一个带鉴权的临时 dio（如拦截器内部重放）。
Dio buildAuthedDio(String baseUrl, String token) {
  return Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 25),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  ));
}

// 忽略未使用导入（kDebugMode 仅在调试时用到）
// ignore: unused_element
void _debug(String msg) {
  if (kDebugMode) print('[AuthInterceptor] $msg');
}
