import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants/app_constants.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final bool hasUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.hasUpdate,
  });
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _httpTimeout = Duration(seconds: 10);

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http
          .get(
            Uri.parse(AppConstants.githubReleasesUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = data['tag_name'] as String? ?? AppConstants.appVersion;
        // Tags are published as `v1.1.0`; only a leading `v` is a prefix.
        // Stripping every `v` would corrupt a word such as `preview`.
        final latestVersion = tagName.startsWith('v')
            ? tagName.substring(1)
            : tagName;
        final downloadUrl =
            (data['assets'] as List<dynamic>?)?.isNotEmpty == true
            ? (data['assets'] as List<dynamic>).first['browser_download_url']
                  as String
            : '${AppConstants.downloadBaseUrl}/app-release.apk';

        final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;

        return UpdateInfo(
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          hasUpdate: hasUpdate,
        );
      }
    } catch (_) {}

    return UpdateInfo(
      latestVersion: AppConstants.appVersion,
      downloadUrl: '',
      hasUpdate: false,
    );
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.');
    final parts2 = v2.split('.');

    const len = 3;
    for (int i = 0; i < len; i++) {
      final p1 = i < parts1.length ? int.tryParse(parts1[i]) ?? 0 : 0;
      final p2 = i < parts2.length ? int.tryParse(parts2[i]) ?? 0 : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }
}
