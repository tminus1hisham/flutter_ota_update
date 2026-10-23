import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'flutter_ota_update_platform_interface.dart';

export 'flutter_ota_update_platform_interface.dart' show OtaException;

/// A GitHub release that is newer than the installed app.
class OtaRelease {
  const OtaRelease({
    required this.version,
    required this.notes,
    required this.htmlUrl,
    required this.assetName,
    required this.downloadUrl,
    required this.assetApiUrl,
    required this.size,
    this.sha256,
  });

  /// The release tag, e.g. `v1.2.3`.
  final String version;

  /// The release body (markdown).
  final String notes;

  /// The release page on GitHub.
  final String htmlUrl;

  final String assetName;

  /// Public `browser_download_url` of the APK.
  final String downloadUrl;

  /// API URL of the APK, used for downloads when a token is set.
  final String assetApiUrl;

  /// APK size in bytes.
  final int size;

  /// Expected SHA-256 of the APK (lowercase hex), or null if the release
  /// publishes none.
  final String? sha256;
}

/// Checks GitHub Releases for a newer APK and installs it.
class FlutterOtaUpdate {
  FlutterOtaUpdate({
    required this.owner,
    required this.repo,
    this.token,
    RegExp? assetPattern,
    this.apiBaseUrl = 'https://api.github.com',
  }) : assetPattern = assetPattern ?? RegExp(r'\.apk$');

  final String owner;
  final String repo;

  /// Optional GitHub token, for private repos or higher rate limits.
  /// Anything shipped inside an app can be extracted, so use a read-only,
  /// repo-scoped token.
  final String? token;

  /// Picks the APK among the release assets. Defaults to the first `.apk`.
  final RegExp assetPattern;

  /// Change for GitHub Enterprise, e.g. `https://github.example.com/api/v3`.
  final String apiBaseUrl;

  /// The installed app's version name.
  Future<String> getAppVersion() =>
      FlutterOtaUpdatePlatform.instance.getAppVersion();

  /// Returns the latest GitHub release if it is newer than [currentVersion]
  /// (defaults to the installed version), otherwise null.
  ///
  /// Draft and pre-releases are ignored, as GitHub's "latest release" does.
  Future<OtaRelease?> checkForUpdate({String? currentVersion}) async {
    final json =
        jsonDecode(await _get('$apiBaseUrl/repos/$owner/$repo/releases/latest'))
            as Map<String, dynamic>;
    final tag = json['tag_name'] as String;
    currentVersion ??= await getAppVersion();
    if (compareVersions(tag, currentVersion) <= 0) return null;

    final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
    final apk = assets
        .where((a) => assetPattern.hasMatch(a['name'] as String))
        .firstOrNull;
    if (apk == null) {
      throw OtaException(
        'NO_ASSET',
        'Release $tag has no asset matching ${assetPattern.pattern}',
      );
    }

    // GitHub records a digest ("sha256:<hex>") for each uploaded asset; older
    // releases may instead ship a "<apk name>.sha256" file next to the APK.
    var sha256 = switch (apk['digest']) {
      final String d when d.startsWith('sha256:') => d.substring(7),
      _ => null,
    };
    final sidecar = assets
        .where((a) => a['name'] == '${apk['name']}.sha256')
        .firstOrNull;
    if (sha256 == null && sidecar != null) {
      final text = await _get(
        _assetUrl(sidecar),
        accept: 'application/octet-stream',
      );
      sha256 = text.trim().split(RegExp(r'\s+')).first;
    }

    return OtaRelease(
      version: tag,
      notes: (json['body'] as String?) ?? '',
      htmlUrl: json['html_url'] as String,
      assetName: apk['name'] as String,
      downloadUrl: apk['browser_download_url'] as String,
      assetApiUrl: apk['url'] as String,
      size: apk['size'] as int,
      sha256: sha256?.toLowerCase(),
    );
  }

  /// Downloads [release]'s APK, verifies its SHA-256 and opens the system
  /// installer. The user still confirms the install; Android also refuses
  /// an APK signed with a different key than the installed app.
  ///
  /// Throws [OtaException] with `NO_CHECKSUM` if the release has no checksum,
  /// unless [allowUnverified] is true.
  Future<void> downloadAndInstall(
    OtaRelease release, {
    void Function(int received, int total)? onProgress,
    bool allowUnverified = false,
  }) async {
    if (release.sha256 == null && !allowUnverified) {
      throw OtaException(
        'NO_CHECKSUM',
        'Release ${release.version} publishes no SHA-256 for ${release.assetName}',
      );
    }
    await FlutterOtaUpdatePlatform.instance.downloadAndInstall(
      url: token == null ? release.downloadUrl : release.assetApiUrl,
      fileName: release.assetName,
      headers: _headers('application/octet-stream'),
      sha256: release.sha256,
      onProgress: onProgress,
    );
  }

  String _assetUrl(Map<String, dynamic> asset) => token == null
      ? asset['browser_download_url'] as String
      : asset['url'] as String;

  Map<String, String> _headers(String accept) => {
    'Accept': accept,
    'User-Agent': 'flutter_ota_update',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<String> _get(
    String url, {
    String accept = 'application/vnd.github+json',
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      _headers(accept).forEach(request.headers.set);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw OtaException('HTTP_ERROR', 'GET $url -> ${response.statusCode}');
      }
      return body;
    } finally {
      client.close();
    }
  }
}

/// Compares two version strings such as `v1.2.3`, `1.2.3+4` or `2.0.0-beta.1`.
///
/// A leading `v` and build metadata (`+…`) are ignored; a pre-release sorts
/// before the same version without one. Returns <0, 0 or >0.
int compareVersions(String a, String b) {
  (List<int>, String?) parse(String v) {
    v = v.trim().replaceFirst(RegExp('^[vV]'), '').split('+').first;
    final dash = v.indexOf('-');
    final core = dash < 0 ? v : v.substring(0, dash);
    return (
      core.split('.').map((p) => int.tryParse(p) ?? 0).toList(),
      dash < 0 ? null : v.substring(dash + 1),
    );
  }

  final (ac, ap) = parse(a);
  final (bc, bp) = parse(b);
  for (var i = 0; i < max(ac.length, bc.length); i++) {
    final d = (i < ac.length ? ac[i] : 0).compareTo(i < bc.length ? bc[i] : 0);
    if (d != 0) return d;
  }
  if (ap == bp) return 0;
  if (ap == null) return 1;
  if (bp == null) return -1;
  // ponytail: plain string compare of pre-release tags ("rc.10" < "rc.2");
  // switch to per-identifier semver compare if that ever matters.
  return ap.compareTo(bp);
}
