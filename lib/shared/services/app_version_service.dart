import 'package:package_info_plus/package_info_plus.dart';

import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/shared/models/app_version_info.dart';

/// 启动时版本检查：对比本机 versionCode 与服务端 min_version_code。
class AppVersionService {
  final ApiClient _api;
  AppVersionService(this._api);

  Future<({int versionCode, String versionName})> getLocalVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (
      versionCode: int.tryParse(info.buildNumber) ?? 0,
      versionName: info.version,
    );
  }

  Future<AppVersionInfo?> fetchRemote({String platform = 'android'}) async {
    try {
      final res = await _api.get(
        ApiEndpoints.appVersion,
        params: {'platform': platform},
      );
      return AppVersionInfo.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 返回强制更新信息；无需强制时返回 null。网络失败时放行（返回 null）。
  Future<AppVersionInfo?> checkForceUpdate({String platform = 'android'}) async {
    final local = await getLocalVersion();
    final remote = await fetchRemote(platform: platform);
    if (remote == null) return null;
    if (remote.requiresForceUpdate(local.versionCode)) return remote;
    return null;
  }
}
