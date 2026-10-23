import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ota_update/flutter_ota_update.dart';
import 'package:flutter_ota_update/flutter_ota_update_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterOtaUpdate platform = MethodChannelFlutterOtaUpdate();
  const MethodChannel channel = MethodChannel('flutter_ota_update');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('getAppVersion', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => '1.2.3');
    expect(await platform.getAppVersion(), '1.2.3');
  });

  test('downloadAndInstall forwards progress and arguments', () async {
    MethodCall? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call;
      // Simulate native progress callbacks before completing.
      await messenger.handlePlatformMessage(
        'flutter_ota_update',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('progress', {'received': 5, 'total': 10}),
        ),
        (_) {},
      );
      return null;
    });
    final progress = <List<int>>[];
    await platform.downloadAndInstall(
      url: 'https://x/app.apk',
      fileName: 'app.apk',
      sha256: 'abc',
      onProgress: (r, t) => progress.add([r, t]),
    );
    expect(sent!.method, 'downloadAndInstall');
    expect(sent!.arguments['sha256'], 'abc');
    expect(progress, [
      [5, 10],
    ]);
  });

  test('downloadAndInstall maps PlatformException to OtaException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'CHECKSUM_MISMATCH', message: 'bad');
    });
    expect(
      platform.downloadAndInstall(url: 'u', fileName: 'f'),
      throwsA(
        isA<OtaException>().having((e) => e.code, 'code', 'CHECKSUM_MISMATCH'),
      ),
    );
  });
}
