import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:sinpra_app/core/auth/token_manager.dart';

class MiniAppScreen extends StatefulWidget {
  final String title;
  final String url;

  const MiniAppScreen({super.key, required this.title, required this.url});

  @override
  State<MiniAppScreen> createState() => _MiniAppScreenState();
}

class _MiniAppScreenState extends State<MiniAppScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _injected = false;
  String? _token;
  String? _refresh;

  bool get _shouldInject {
    final host = Uri.tryParse(widget.url)?.host ?? '';
    return host.endsWith('sinpra.co');
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_shouldInject) {
      try {
        final tm = TokenManager();
        _token = await tm.getAccessToken();
        _refresh = await tm.getRefreshToken();
      } catch (_) {
        _token = null;
        _refresh = null;
      }
    }

    final controller = WebViewController();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) async {
          if (_token != null && _token!.isNotEmpty && !_injected) {
            _injected = true;
            try {
              final r = (_refresh != null && _refresh!.isNotEmpty)
                  ? "localStorage.setItem('refresh_token', ${_jsString(_refresh!)});"
                  : '';
              await controller.runJavaScript(
                "localStorage.setItem('auth_token', ${_jsString(_token!)});$r",
              );
            } catch (_) {}
            try {
              await controller.loadRequest(Uri.parse(widget.url));
            } catch (_) {}
            return;
          }
          if (mounted) setState(() => _loading = false);
        },
      ),
    );

    final initial = (_token != null && _token!.isNotEmpty)
        ? _originOf(widget.url)
        : widget.url;
    await controller.loadRequest(Uri.parse(initial));
    if (mounted) setState(() => _controller = controller);
  }

  String _originOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port/';
  }

  String _jsString(String v) {
    final escaped = v.replaceAll('\\', r'\\').replaceAll("'", r"\'");
    return "'$escaped'";
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller == null
                ? null
                : () {
                    _injected = false;
                    setState(() => _loading = true);
                    controller.loadRequest(Uri.parse(widget.url));
                  },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (controller != null) WebViewWidget(controller: controller),
          if (_loading || controller == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
