import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ota_update_platform_interface.dart';

/// An implementation of [FlutterOtaUpdatePlatform] that uses method channels.
class MethodChannelFlutterOtaUpdate extends FlutterOtaUpdatePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ota_update');

  @override
  Future<String> getAppVersion() async {
    return (await methodChannel.invokeMethod<String>('getAppVersion'))!;
  }

  @override
  Future<void> downloadAndInstall({
    required String url,
    required String fileName,
    Map<String, String> headers = const {},
    String? sha256,
    void Function(int received, int total)? onProgress,
  }) async {
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        final args = call.arguments as Map;
        onProgress?.call(args['received'] as int, args['total'] as int);
      }
    });
    try {
      await methodChannel.invokeMethod<void>('downloadAndInstall', {
        'url': url,
        'fileName': fileName,
        'headers': headers,
        'sha256': sha256,
      });
    } on PlatformException catch (e) {
      throw OtaException(e.code, e.message);
    } finally {
      methodChannel.setMethodCallHandler(null);
    }
  }
}
