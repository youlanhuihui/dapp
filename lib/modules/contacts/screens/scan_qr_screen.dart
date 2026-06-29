import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/shared/services/friends_service.dart';
import 'package:sinpra_app/modules/chat/providers/chat_provider.dart';

/// 扫一扫：识别好友个人二维码 → 发起好友申请 / 直接聊天。
/// 不含设备绑定（甲方客户端版本不需要）。
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  late final MobileScannerController _scanner;
  late final FriendsService _friends;
  bool _processing = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _friends = FriendsService(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() => _processing = true);
    try {
      await _scanner.stop();
    } catch (_) {}
    await _handlePayload(raw.trim());
  }

  Future<void> _handlePayload(String payload) async {
    // 尝试作为 JWT payload；scanUserQr 直接传 payload
    try {
      final res = await _friends.scanUserQr(payload);
      final user = (res['user'] ?? {}) as Map;
      final state = (res['relation_state'] ?? 'none') as String;
      final userId = (user['id'] ?? user['user_id']) as String?;
      final name = (user['nickname'] ?? user['email'] ?? '用户') as String;
      if (!mounted) return;
      switch (state) {
        case 'self':
          AppSnackBar.showInfo(context, '这是你自己');
          break;
        case 'friend':
          if (userId != null) {
            final chat = context.read<ChatProvider>();
            final conv = await chat.createPrivateChat(userId);
            if (conv != null && mounted) context.go('/conversations/${conv.id}');
          }
          break;
        case 'request_pending':
          AppSnackBar.showInfo(context, context.tr('requestSent'));
          break;
        case 'request_incoming':
          AppSnackBar.showInfo(context, context.tr('friendRequests'));
          break;
        case 'rate_limited':
          AppSnackBar.showErrorText(context, '操作过于频繁，请稍后再试');
          break;
        default:
          // none → 弹出发送申请确认
          if (userId != null) {
            await _confirmSendRequest(userId, name);
          }
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        try {
          _scanner.start();
        } catch (_) {}
      }
    }
  }

  Future<void> _confirmSendRequest(String userId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('sendRequest')),
        content: Text('向 $name ${context.tr('sendRequest')}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: Text(context.tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(_, true), child: Text(context.tr('confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _friends.sendRequest(toUserId: userId, source: 'qr');
      if (mounted) AppSnackBar.showInfo(context, context.tr('requestSent'));
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('scanQr'))),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_processing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(context.tr('scanHint'),
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 24,
            child: IconButton(
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
              onPressed: () {
                _scanner.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
            ),
          ),
        ],
      ),
    );
  }
}
