import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/brand.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/global_messenger.dart';
import 'package:sinpra_app/core/auth/token_manager.dart';
import 'package:sinpra_app/modules/auth/providers/auth_store.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    final nick = _nickname.text.trim();
    final pwd = _password.text;
    if (email.isEmpty) {
      showGlobalError(context.tr('authEmailHint'));
      return;
    }
    if (pwd.length < 6) {
      showGlobalError(context.tr('authPasswordLength'));
      return;
    }
    if (nick.isEmpty) {
      showGlobalError(context.tr('authNicknameHint'));
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthStore>();
      await auth.register(email: email, password: pwd, nickname: nick);
      // 注册成功 → 直接登录并拉起 WS
      await auth.login(email: email, password: pwd);
      final token = await context.read<TokenManager>().getAccessToken();
      final chat = context.read<ChatProvider>();
      if (token != null && auth.user != null) {
        chat.start(token, auth.user!.userId);
        chat.loadConversations();
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
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/login'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 64,
                width: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: SinpraTheme.brand600,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  AppBrand.logoLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('registerTitle'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('registerSubtitle'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.tr('authEmail'),
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nickname,
                decoration: InputDecoration(
                  labelText: context.tr('authNickname'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: context.tr('authPassword'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _busy ? null : _register,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                        )
                      : Text(context.tr('authSignup')),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(context.tr('authHasAccount')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
