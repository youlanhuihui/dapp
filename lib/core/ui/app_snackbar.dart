import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';

class AppSnackBar {
  AppSnackBar._();

  static void showError(BuildContext context, Object error) =>
      _show(context, _extract(context, error), isError: true);

  static void showErrorText(BuildContext context, String text) =>
      _show(context, text, isError: true);

  static void showInfo(BuildContext context, String text) =>
      _show(context, text, isError: false);

  static void _show(BuildContext context, String text,
      {required bool isError}) {
    if (!context.mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isError ? theme.colorScheme.error : null,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static String _extract(BuildContext context, Object error) {
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) return first['msg'] as String;
        }
      }
      final code = error.response?.statusCode;
      if (code != null) return '${context.tr('requestFailed')} ($code)';
      return context.tr('networkError');
    }
    return error.toString();
  }
}
