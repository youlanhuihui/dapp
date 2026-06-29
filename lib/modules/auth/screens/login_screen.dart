import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/core/brand.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/ui/global_messenger.dart';
import 'package:sinpra_app/core/auth/token_manager.dart';
import 'package:sinpra_app/core/websocket/ws_client.dart';
import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/modules/auth/providers/auth_store.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pwd = _password.text;
    if (email.isEmpty || pwd.isEmpty) {
      AppSnackBar.showErrorText(context, context.tr('authEmailHint'));
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthStore>();
      await auth.login(email: email, password: pwd);
      // 连接 WS 并启动聊天
      final token = await context.read<TokenManager>().getAccessToken();
      final ws = context.read<WSClient>();
      final chat = context.read<ChatProvider>();
      if (token != null && auth.user != null) {
        chat.start(token, auth.user!.userId);
        await chat.loadConversations();
      }
      if (!mounted) return;
      context.go('/conversations');
    } catch (e) {
      showGlobalError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Container(
                height: 72,
                width: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: SinpraTheme.brand600,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  AppBrand.logoLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('loginTitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('loginSubtitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.tr('authEmail'),
                  hintText: context.tr('authEmailHint'),
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: context.tr('authPassword'),
                  hintText: context.tr('authPasswordHint'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(context.tr('authLogin')),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/register'),
                child: Text(context.tr('authNoAccount')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
