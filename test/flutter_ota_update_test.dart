import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ota_update/flutter_ota_update.dart';
import 'package:flutter_ota_update/flutter_ota_update_platform_interface.dart';
import 'package:flutter_ota_update/flutter_ota_update_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterOtaUpdatePlatform
    with MockPlatformInterfaceMixin
    implements FlutterOtaUpdatePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterOtaUpdatePlatform initialPlatform = FlutterOtaUpdatePlatform.instance;

  test('$MethodChannelFlutterOtaUpdate is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterOtaUpdate>());
  });

  test('getPlatformVersion', () async {
    FlutterOtaUpdate flutterOtaUpdatePlugin = FlutterOtaUpdate();
    MockFlutterOtaUpdatePlatform fakePlatform = MockFlutterOtaUpdatePlatform();
    FlutterOtaUpdatePlatform.instance = fakePlatform;

    expect(await flutterOtaUpdatePlugin.getPlatformVersion(), '42');
  });
}
