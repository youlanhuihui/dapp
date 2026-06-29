import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/auth/auth_session.dart';
import 'package:sinpra_app/core/auth/token_manager.dart';
import 'package:sinpra_app/modules/auth/providers/auth_store.dart';
import 'package:sinpra_app/modules/auth/screens/force_update_screen.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';
import 'package:sinpra_app/shared/services/app_version_service.dart';

/// 启动闪屏：版本检查 → 恢复会话 → 根据登录态跳转。
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final versionSvc = AppVersionService(context.read<ApiClient>());
    final local = await versionSvc.getLocalVersion();
    final forceInfo = await versionSvc.checkForceUpdate();
    if (!mounted) return;

    if (forceInfo != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ForceUpdateScreen(
            info: forceInfo,
            currentVersion: local.versionName,
            currentVersionCode: local.versionCode,
          ),
        ),
      );
      return;
    }

    final auth = context.read<AuthStore>();
    await auth.tryRestoreSession();
    if (!mounted) return;
    if (AuthSession.isAuthenticated.value && auth.isLoggedIn) {
      final token = await context.read<TokenManager>().getAccessToken();
      final chat = context.read<ChatProvider>();
      if (token != null && auth.user != null) {
        chat.start(token, auth.user!.userId);
        chat.loadConversations();
      }
      context.go('/conversations');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
