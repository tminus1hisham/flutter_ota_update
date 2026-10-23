# flutter_ota_update

OTA app updates from GitHub Releases. Check for a newer release, download the APK, verify its SHA-256 and open the Android installer, all without an app store.

Android only.

## Features

- Reads the latest release of any GitHub repo (public, private with a token, or GitHub Enterprise).
- Compares the release tag (`v1.2.3`) with the installed `versionName`.
- Verifies the APK against GitHub's built-in asset digest, or a `<apk>.sha256` file attached to the release.
- Streams download progress.
- Opens the system installer. Android itself refuses an APK signed with a different key.

## Install

```yaml
dependencies:
  flutter_ota_update: ^0.0.1
```

No manifest changes are needed. The plugin adds the `INTERNET` and `REQUEST_INSTALL_PACKAGES` permissions and its own `FileProvider`.

## Usage

```dart
import 'package:flutter_ota_update/flutter_ota_update.dart';

final ota = FlutterOtaUpdate(owner: 'your-name', repo: 'your-app');

final release = await ota.checkForUpdate();
if (release != null) {
  print('New version ${release.version}: ${release.notes}');
  await ota.downloadAndInstall(
    release,
    onProgress: (received, total) => print('$received / $total'),
  );
}
```

`downloadAndInstall` completes once the installer is on screen; the user confirms the install. The first time, Android asks the user to allow "install unknown apps" for your app.

### Options

| Parameter | Default | Purpose |
|---|---|---|
| `token` | none | GitHub token for private repos or higher rate limits. |
| `assetPattern` | `RegExp(r'\.apk$')` | Which release asset to install, e.g. `RegExp(r'arm64-v8a.*\.apk$')` for split APKs. |
| `apiBaseUrl` | `https://api.github.com` | GitHub Enterprise API root. |
| `checkForUpdate(currentVersion:)` | installed `versionName` | Compare against another version. |
| `downloadAndInstall(allowUnverified:)` | `false` | Install even when the release has no checksum. |

### Errors

Failures throw `OtaException` with one of these `code`s:

| Code | Meaning |
|---|---|
| `HTTP_ERROR` | GitHub API returned non-200 (no release yet, wrong repo, private repo without a token, rate limit). |
| `NO_ASSET` | The latest release has no asset matching `assetPattern`. |
| `NO_CHECKSUM` | No SHA-256 is available and `allowUnverified` is false. |
| `DOWNLOAD_FAILED` | Network or storage error while downloading. |
| `CHECKSUM_MISMATCH` | The downloaded file does not match the expected SHA-256. It is deleted. |
| `INSTALL_FAILED` | The installer could not be opened. |

## Publishing a release your app can find

1. Bump `version:` in your app's `pubspec.yaml` (e.g. `1.2.0+5`).
2. Build with the same signing key as before: `flutter build apk --release`.
3. Create a GitHub release tagged `v1.2.0` (not a draft or pre-release) and attach the APK.

GitHub records a SHA-256 digest for every uploaded asset, so no extra step is needed. For older releases, attach `app-release.apk.sha256` containing the hex digest (`sha256sum app-release.apk > app-release.apk.sha256`).

## Good to know

- **Google Play:** Play policy forbids apps from updating themselves outside Play and restricts `REQUEST_INSTALL_PACKAGES`. Use this for sideloaded, enterprise or internal builds, not Play Store builds.
- **Tokens in apps can be extracted.** If you need one, use a fine-grained, read-only token scoped to the single repo.
- Only the latest non-draft, non-pre-release release is considered.
- Pre-release suffixes are compared as plain strings (`rc.10` sorts before `rc.2`).
