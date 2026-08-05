import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ota_update_method_channel.dart';

abstract class FlutterOtaUpdatePlatform extends PlatformInterface {
  /// Constructs a FlutterOtaUpdatePlatform.
  FlutterOtaUpdatePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterOtaUpdatePlatform _instance = MethodChannelFlutterOtaUpdate();

  /// The default instance of [FlutterOtaUpdatePlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterOtaUpdate].
  static FlutterOtaUpdatePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterOtaUpdatePlatform] when
  /// they register themselves.
  static set instance(FlutterOtaUpdatePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
