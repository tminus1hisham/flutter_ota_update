import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ota_update_method_channel.dart';

/// Thrown when checking for, downloading or installing an update fails.
///
/// [code] is one of `HTTP_ERROR`, `NO_ASSET`, `NO_CHECKSUM`,
/// `PERMISSION_NOT_DECLARED`, `DOWNLOAD_FAILED`, `CHECKSUM_MISMATCH`,
/// `INSTALL_FAILED` or `UNSUPPORTED_PLATFORM`.
class OtaException implements Exception {
  const OtaException(this.code, this.message);

  final String code;
  final String? message;

  @override
  String toString() => 'OtaException($code): $message';
}

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

  /// The installed app's version name (e.g. `1.2.3`).
  Future<String> getAppVersion() {
    throw UnimplementedError('getAppVersion() has not been implemented.');
  }

  /// Downloads [url] to [fileName], verifies it against [sha256] when given,
  /// and opens the system installer. Completes once the installer is shown.
  Future<void> downloadAndInstall({
    required String url,
    required String fileName,
    Map<String, String> headers = const {},
    String? sha256,
    void Function(int received, int total)? onProgress,
  }) {
    throw UnimplementedError('downloadAndInstall() has not been implemented.');
  }
}
