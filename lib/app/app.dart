import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'routes.dart';
import 'theme.dart';
import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/auth/token_manager.dart';
import 'package:sinpra_app/core/config/app_config.dart';
import 'package:sinpra_app/core/i18n/locale_controller.dart';
import 'package:sinpra_app/core/ui/global_messenger.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/websocket/ws_client.dart';
import 'package:sinpra_app/modules/auth/providers/auth_store.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';

class SinpraApp extends StatelessWidget {
  const SinpraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenManager>(create: (_) => TokenManager()),
        Provider<ApiClient>(create: (_) => ApiClient(baseUrl: AppConfig.apiBaseUrl)),
        Provider<WSClient>(
          create: (_) => WSClient(url: AppConfig.wsUrl),
          dispose: (_, ws) => ws.disconnect(),
        ),
        ChangeNotifierProvider<LocaleController>(create: (_) => LocaleController()),
        ChangeNotifierProvider<EmbeddedWalletStore>(
          create: (ctx) => EmbeddedWalletStore(api: ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<AuthStore>(
          create: (ctx) => AuthStore(
            api: ctx.read<ApiClient>(),
            tokenManager: ctx.read<TokenManager>(),
          ),
        ),
        ChangeNotifierProxyProvider4<ApiClient, WSClient, AuthStore, EmbeddedWalletStore, ChatProvider>(
          create: (ctx) {
            final p = ChatProvider(
              apiClient: ctx.read<ApiClient>(),
              wsClient: ctx.read<WSClient>(),
            );
            p.bindWallet(ctx.read<EmbeddedWalletStore>());
            return p;
          },
          update: (ctx, api, ws, auth, wallet, prev) {
            final p = prev ?? ChatProvider(apiClient: api, wsClient: ws);
            p.bindWallet(wallet);
            return p;
          },
        ),
      ],
      child: Consumer<LocaleController>(
        builder: (context, locale, _) => MaterialApp.router(
          title: 'SINPRA',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          theme: SinpraTheme.lightTheme,
          locale: locale.locale,
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
