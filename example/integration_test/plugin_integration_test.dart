// Integration tests run in a full Flutter app, so they reach the real
// Android side of the plugin. Run with: flutter test integration_test
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_ota_update/flutter_ota_update.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getAppVersion returns the installed version', (tester) async {
    final ota = FlutterOtaUpdate(owner: 'o', repo: 'r');
    expect(await ota.getAppVersion(), isNotEmpty);
  });
}
