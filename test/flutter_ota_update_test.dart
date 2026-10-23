import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ota_update/flutter_ota_update.dart';
import 'package:flutter_ota_update/flutter_ota_update_platform_interface.dart';
import 'package:flutter_ota_update/flutter_ota_update_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterOtaUpdatePlatform
    with MockPlatformInterfaceMixin
    implements FlutterOtaUpdatePlatform {
  Map<String, Object?>? lastDownload;

  @override
  Future<String> getAppVersion() => Future.value('1.0.0');

  @override
  Future<void> downloadAndInstall({
    required String url,
    required String fileName,
    Map<String, String> headers = const {},
    String? sha256,
    void Function(int received, int total)? onProgress,
  }) async {
    lastDownload = {
      'url': url,
      'fileName': fileName,
      'headers': headers,
      'sha256': sha256,
    };
  }
}

Map<String, Object?> asset(String name, String base, {String? digest}) => {
  'name': name,
  'size': 5,
  'url': '$base/api/assets/$name',
  'browser_download_url': '$base/dl/$name',
  'digest': digest,
};

void main() {
  final FlutterOtaUpdatePlatform initialPlatform =
      FlutterOtaUpdatePlatform.instance;

  test('$MethodChannelFlutterOtaUpdate is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterOtaUpdate>());
  });

  group('compareVersions', () {
    test('orders numeric parts', () {
      expect(compareVersions('v1.2.10', '1.2.9'), greaterThan(0));
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.0.0', '2.0.0'), lessThan(0));
    });
    test('ignores build metadata', () {
      expect(compareVersions('1.2.3+7', '1.2.3+1'), 0);
    });
    test('pre-release sorts before release', () {
      expect(compareVersions('2.0.0-beta.1', '2.0.0'), lessThan(0));
      expect(compareVersions('2.0.0', '2.0.0-rc.1'), greaterThan(0));
      expect(compareVersions('2.0.0-beta', '2.0.0-alpha'), greaterThan(0));
    });
  });

  group('checkForUpdate', () {
    late HttpServer server;
    late String base;
    late Map<String, Object?> release;
    final requests = <HttpRequest>[];

    setUp(() async {
      requests.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((req) {
        requests.add(req);
        if (req.uri.path == '/repos/me/app/releases/latest') {
          req.response.write(jsonEncode(release));
        } else if (req.uri.path.endsWith('.sha256')) {
          req.response.write('ABCDEF  app.apk\n');
        } else {
          req.response.statusCode = 404;
        }
        req.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    FlutterOtaUpdate ota({String? token}) => FlutterOtaUpdate(
      owner: 'me',
      repo: 'app',
      apiBaseUrl: base,
      token: token,
    );

    test('returns the release when newer, using the GitHub digest', () async {
      release = {
        'tag_name': 'v1.1.0',
        'body': 'notes',
        'html_url': 'https://github.com/me/app/releases/v1.1.0',
        'assets': [asset('app.apk', base, digest: 'sha256:ABC123')],
      };
      final r = await ota().checkForUpdate(currentVersion: '1.0.0');
      expect(r, isNotNull);
      expect(r!.version, 'v1.1.0');
      expect(r.assetName, 'app.apk');
      expect(r.sha256, 'abc123');
      expect(r.notes, 'notes');
    });

    test('returns null when not newer', () async {
      release = {
        'tag_name': 'v1.0.0',
        'html_url': '',
        'assets': [asset('app.apk', base)],
      };
      expect(await ota().checkForUpdate(currentVersion: '1.0.0'), isNull);
    });

    test('falls back to a .sha256 sidecar asset', () async {
      release = {
        'tag_name': '2.0.0',
        'html_url': '',
        'assets': [asset('app.apk', base), asset('app.apk.sha256', base)],
      };
      final r = await ota().checkForUpdate(currentVersion: '1.0.0');
      expect(r!.sha256, 'abcdef');
      expect(requests.last.uri.path, '/dl/app.apk.sha256');
    });

    test('sends the token and uses API asset URLs when set', () async {
      release = {
        'tag_name': '2.0.0',
        'html_url': '',
        'assets': [asset('app.apk', base), asset('app.apk.sha256', base)],
      };
      await ota(token: 't0k').checkForUpdate(currentVersion: '1.0.0');
      expect(requests.first.headers.value('authorization'), 'Bearer t0k');
      expect(requests.last.uri.path, '/api/assets/app.apk.sha256');
    });

    test('throws NO_ASSET when no asset matches', () async {
      release = {
        'tag_name': '2.0.0',
        'html_url': '',
        'assets': [asset('app.aab', base)],
      };
      expect(
        ota().checkForUpdate(currentVersion: '1.0.0'),
        throwsA(isA<OtaException>().having((e) => e.code, 'code', 'NO_ASSET')),
      );
    });

    test('throws HTTP_ERROR on a non-200 response', () async {
      final missing = FlutterOtaUpdate(owner: 'x', repo: 'y', apiBaseUrl: base);
      expect(
        missing.checkForUpdate(currentVersion: '1.0.0'),
        throwsA(
          isA<OtaException>().having((e) => e.code, 'code', 'HTTP_ERROR'),
        ),
      );
    });

    test('uses the installed version when none is given', () async {
      FlutterOtaUpdatePlatform.instance = MockFlutterOtaUpdatePlatform();
      release = {
        'tag_name': '1.0.0',
        'html_url': '',
        'assets': [asset('app.apk', base)],
      };
      expect(await ota().checkForUpdate(), isNull);
    });
  });

  group('downloadAndInstall', () {
    const release = OtaRelease(
      version: 'v2.0.0',
      notes: '',
      htmlUrl: '',
      assetName: 'app.apk',
      downloadUrl: 'https://dl/app.apk',
      assetApiUrl: 'https://api/assets/1',
      size: 5,
      sha256: 'abc',
    );
    late MockFlutterOtaUpdatePlatform platform;
    setUp(
      () => FlutterOtaUpdatePlatform.instance = platform =
          MockFlutterOtaUpdatePlatform(),
    );

    test('passes URL, file name and checksum to the platform', () async {
      await FlutterOtaUpdate(
        owner: 'me',
        repo: 'app',
      ).downloadAndInstall(release);
      expect(platform.lastDownload!['url'], 'https://dl/app.apk');
      expect(platform.lastDownload!['fileName'], 'app.apk');
      expect(platform.lastDownload!['sha256'], 'abc');
    });

    test('uses the API URL with auth when a token is set', () async {
      await FlutterOtaUpdate(
        owner: 'me',
        repo: 'app',
        token: 't',
      ).downloadAndInstall(release);
      expect(platform.lastDownload!['url'], 'https://api/assets/1');
      expect(
        (platform.lastDownload!['headers'] as Map)['Authorization'],
        'Bearer t',
      );
    });

    test('refuses an unverified release unless allowed', () async {
      const unverified = OtaRelease(
        version: 'v2.0.0',
        notes: '',
        htmlUrl: '',
        assetName: 'app.apk',
        downloadUrl: 'https://dl/app.apk',
        assetApiUrl: '',
        size: 5,
      );
      final ota = FlutterOtaUpdate(owner: 'me', repo: 'app');
      await expectLater(
        ota.downloadAndInstall(unverified),
        throwsA(
          isA<OtaException>().having((e) => e.code, 'code', 'NO_CHECKSUM'),
        ),
      );
      expect(platform.lastDownload, isNull);
      await ota.downloadAndInstall(unverified, allowUnverified: true);
      expect(platform.lastDownload, isNotNull);
    });
  });
}
