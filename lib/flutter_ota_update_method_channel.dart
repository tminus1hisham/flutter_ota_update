import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ota_update_platform_interface.dart';

/// An implementation of [FlutterOtaUpdatePlatform] that uses method channels.
class MethodChannelFlutterOtaUpdate extends FlutterOtaUpdatePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ota_update');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
