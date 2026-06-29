/// 服务端下发的 APP 版本策略。
class AppVersionInfo {
  final String platform;
  final String latestVersion;
  final int latestVersionCode;
  final int minVersionCode;
  final bool forceUpdate;
  final String downloadUrl;
  final String releaseNotes;

  const AppVersionInfo({
    required this.platform,
    required this.latestVersion,
    required this.latestVersionCode,
    required this.minVersionCode,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> j) => AppVersionInfo(
        platform: j['platform'] as String? ?? 'android',
        latestVersion: j['latest_version'] as String? ?? '0.0.0',
        latestVersionCode: (j['latest_version_code'] as num?)?.toInt() ?? 0,
        minVersionCode: (j['min_version_code'] as num?)?.toInt() ?? 0,
        forceUpdate: j['force_update'] as bool? ?? false,
        downloadUrl: j['download_url'] as String? ?? '',
        releaseNotes: j['release_notes'] as String? ?? '',
      );

  /// 当前 build 号低于服务端最低要求 → 必须更新。
  bool requiresForceUpdate(int currentVersionCode) =>
      minVersionCode > 0 && currentVersionCode < minVersionCode;

  /// 有新版但尚未到强制线 → 可提示可选更新。
  bool hasOptionalUpdate(int currentVersionCode) =>
      latestVersionCode > currentVersionCode &&
      !requiresForceUpdate(currentVersionCode);
}
