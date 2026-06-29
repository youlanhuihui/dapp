import 'package:flutter/foundation.dart';

class AuthSession {
  AuthSession._();

  static final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  /// 当前登录用户 ID，登录成功后从 /users/me 写入
  static String? userId;

  static void clear() {
    isAuthenticated.value = false;
    userId = null;
  }
}
