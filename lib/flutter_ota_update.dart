
import 'flutter_ota_update_platform_interface.dart';

class FlutterOtaUpdate {
  Future<String?> getPlatformVersion() {
    return FlutterOtaUpdatePlatform.instance.getPlatformVersion();
  }
}
