import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sinpra_app/core/config/app_config.dart';
import 'interceptors.dart';

/// HTTP 客户端：封装 dio + JWT 鉴权拦截器。
/// 机制层复用自已跑通的 IM 工程。
class ApiClient {
  late final Dio _dio;

  ApiClient({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _dio.interceptors.add(AuthInterceptor());
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path,
          {dynamic data, Map<String, dynamic>? params, Options? options}) =>
      _dio.post(path, data: data, queryParameters: params, options: options);

  Future<Response> put(String path,
          {dynamic data, Map<String, dynamic>? params}) =>
      _dio.put(path, data: data, queryParameters: params);

  Future<Response> delete(String path, {Map<String, dynamic>? params}) =>
      _dio.delete(path, queryParameters: params);

  Future<Response> patch(String path,
          {dynamic data, Map<String, dynamic>? params}) =>
      _dio.patch(path, data: data, queryParameters: params);
}

/// 解析后端错误体，返回可读文案（兼容 {detail: ...} 与 FastAPI 校验错误）。
String apiErrorMessage(Object error, {String fallback = '请求失败'}) {
  if (error is DioException) {
    final payload = error.response?.data;
    if (payload is Map) {
      final detail = payload['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return first['msg'] as String;
        }
      }
    }
    final code = error.response?.statusCode;
    if (code != null) return '$fallback ($code)';
    return '网络异常：无法连接服务器';
  }
  return error.toString();
}
