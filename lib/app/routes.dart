import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sinpra_app/core/auth/auth_session.dart';
import 'package:sinpra_app/modules/auth/screens/login_screen.dart';
import 'package:sinpra_app/modules/auth/screens/register_screen.dart';
import 'package:sinpra_app/modules/auth/screens/startup_screen.dart';
import 'package:sinpra_app/modules/chat/screens/chat_screen.dart';
import 'package:sinpra_app/modules/chat/screens/conversation_list_screen.dart';
import 'package:sinpra_app/modules/contacts/screens/contacts_screen.dart';
import 'package:sinpra_app/modules/contacts/screens/friend_requests_screen.dart';
import 'package:sinpra_app/modules/contacts/screens/my_qr_screen.dart';
import 'package:sinpra_app/modules/contacts/screens/scan_qr_screen.dart';
import 'package:sinpra_app/modules/business/screens/business_screen.dart';
import 'package:sinpra_app/modules/settings/screens/settings_screen.dart';
import 'package:sinpra_app/modules/settings/screens/referral_screen.dart';
import 'package:sinpra_app/modules/wallet/screens/wallet_screen.dart';
import 'package:sinpra_app/modules/wallet/screens/wallet_receive_screen.dart';
import 'package:sinpra_app/modules/wallet/screens/wallet_accounts_screen.dart';
import 'package:sinpra_app/modules/wallet/screens/wallet_transfer_screen.dart';
import 'package:sinpra_app/modules/wallet/screens/wallet_history_screen.dart';
import 'package:sinpra_app/modules/mini_app/screens/mini_app_screen.dart';
import 'package:sinpra_app/modules/chat/screens/red_packet_detail_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/startup',
  refreshListenable: AuthSession.isAuthenticated,
  redirect: (context, state) {
    final path = state.uri.path;
    const authPaths = {'/startup', '/login', '/register'};
    final isLoggedIn = AuthSession.isAuthenticated.value;
    if (!isLoggedIn && !authPaths.contains(path)) return '/login';
    if (isLoggedIn && authPaths.contains(path) && path != '/startup') {
      return '/conversations';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/startup', builder: (c, s) => const StartupScreen()),
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
    // 全屏页面（跳出底部 Tab）
    GoRoute(
      path: '/friends/requests',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => const FriendRequestsScreen(),
    ),
    GoRoute(
      path: '/friends/my-qr',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => const MyQrScreen(),
    ),
    GoRoute(
      path: '/friends/scan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => const ScanQrScreen(),
    ),
    GoRoute(
      path: '/settings/wallet',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => const WalletScreen(),
      routes: [
        GoRoute(
          path: 'receive',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (c, s) => const WalletReceiveScreen(),
        ),
        GoRoute(
          path: 'transfer',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (c, s) => const WalletTransferScreen(),
        ),
        GoRoute(
          path: 'accounts',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (c, s) => const WalletAccountsScreen(),
        ),
        GoRoute(
          path: 'history',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (c, s) => const WalletHistoryScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/red-packets/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => RedPacketDetailScreen(
        packetId: s.pathParameters['id'] ?? '',
        conversationId: s.uri.queryParameters['conv'],
      ),
    ),
    GoRoute(
      path: '/mini-app',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => MiniAppScreen(
        title: s.uri.queryParameters['title'] ?? 'SINPRA',
        url: s.uri.queryParameters['url'] ?? '',
      ),
    ),
    GoRoute(
      path: '/settings/referral',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (c, s) => const ReferralScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (c, s, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/conversations',
          builder: (c, s) => const ConversationListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (c, s) => ChatScreen(
                conversationId: s.pathParameters['id'] ?? '',
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/contacts',
          builder: (c, s) => const ContactsScreen(),
        ),
        GoRoute(
          path: '/business',
          builder: (c, s) => const BusinessScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (c, s) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

/// 4 Tab 底部导航：聊天 / 联系人 / 业务 / 我的
class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNavBar({super.key, required this.child});

  static int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/conversations')) return 0;
    if (loc.startsWith('/contacts')) return 1;
    if (loc.startsWith('/business')) return 2;
    if (loc.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: '聊天'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: '联系人'),
          BottomNavigationBarItem(icon: Icon(Icons.diamond_outlined), activeIcon: Icon(Icons.diamond), label: '业务'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '我的'),
        ],
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/conversations');
              break;
            case 1:
              context.go('/contacts');
              break;
            case 2:
              context.go('/business');
              break;
            case 3:
              context.go('/settings');
              break;
          }
        },
      ),
    );
  }
}
