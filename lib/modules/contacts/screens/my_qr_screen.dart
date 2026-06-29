import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/shared/services/friends_service.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  late final FriendsService _friends;
  String? _payload;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _friends = FriendsService(context.read<ApiClient>());
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final api = context.read<ApiClient>();
      final results = await Future.wait([
        api.get(ApiEndpoints.currentUser),
        _friends.getMyQrPayload(),
      ]);
      if (!mounted) return;
      _profile = Map<String, dynamic>.from((results[0] as Response).data as Map);
      _payload = results[1] as String;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      _payload = await _friends.refreshMyQrPayload();
      AppSnackBar.showInfo(context, context.tr('myQrRefreshed'));
    } catch (e) {
      AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile?['nickname'] ?? _profile?['email'] ?? '') as String;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('myQr'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(context.tr('myQrHint'),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16),
                        ],
                      ),
                      child: _payload == null || _payload!.isEmpty
                          ? const Icon(Icons.qr_code, size: 200, color: Colors.grey)
                          : QrImageView(data: _payload!, size: 220),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(context.tr('copy')),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: _payload ?? ''));
                            AppSnackBar.showInfo(context, context.tr('copied'));
                          },
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: _refreshing
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh, size: 18),
                          label: Text(context.tr('refresh')),
                          onPressed: _refreshing ? null : _refresh,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
