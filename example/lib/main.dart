import 'package:flutter/material.dart';
import 'package:flutter_ota_update/flutter_ota_update.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Point this at the repo whose releases carry your APK.
  final _ota = FlutterOtaUpdate(
    owner: 'tminus1hisham',
    repo: 'flutter_ota_update',
  );

  OtaRelease? _release;
  String _status = 'Tap the button to check for updates.';
  double? _progress;
  bool _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final release = await _ota.checkForUpdate();
      setState(() {
        _release = release;
        _status = release == null
            ? 'You are on the latest version.'
            : 'Version ${release.version} is available.';
      });
    } on Exception catch (e) {
      setState(() => _status = 'Check failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      await _ota.downloadAndInstall(
        _release!,
        onProgress: (received, total) =>
            setState(() => _progress = total > 0 ? received / total : null),
      );
      setState(() => _status = 'Installer opened.');
    } on OtaException catch (e) {
      setState(() => _status = 'Update failed: ${e.message}');
    } finally {
      setState(() {
        _busy = false;
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_ota_update example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_status),
              if (_release != null && _release!.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_release!.notes),
              ],
              const SizedBox(height: 16),
              if (_busy) LinearProgressIndicator(value: _progress),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _check,
                child: const Text('Check for updates'),
              ),
              if (_release != null)
                OutlinedButton(
                  onPressed: _busy ? null : _install,
                  child: const Text('Download & install'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
