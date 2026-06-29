import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/shared/models/app_version_info.dart';

/// 强制更新全屏页：不可关闭，只能跳转下载 APK。
class ForceUpdateScreen extends StatelessWidget {
  final AppVersionInfo info;
  final String currentVersion;
  final int currentVersionCode;

  const ForceUpdateScreen({
    super.key,
    required this.info,
    required this.currentVersion,
    required this.currentVersionCode,
  });

  Future<void> _openDownload() async {
    var url = info.downloadUrl;
    if (url.isEmpty) return;
    // 防 CDN/浏览器缓存旧包
    final sep = url.contains('?') ? '&' : '?';
    url = '$url${sep}v=${info.latestVersionCode}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(Icons.system_update, size: 72, color: SinpraTheme.brand600),
                const SizedBox(height: 24),
                const Text(
                  '发现新版本',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  '当前版本 v$currentVersion ($currentVersionCode)\n'
                  '最低要求 v${info.latestVersion} (${info.minVersionCode})',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                ),
                if (info.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SinpraTheme.brand50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('更新内容',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: SinpraTheme.brand800)),
                        const SizedBox(height: 8),
                        Text(info.releaseNotes,
                            style: const TextStyle(fontSize: 14, height: 1.5)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _openDownload,
                    child: const Text('立即下载更新'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '安装 APK 后请重新打开应用',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
