## 0.0.1

* Initial release (Android only).
* `checkForUpdate` reads the latest GitHub release and compares it to the installed version.
* `downloadAndInstall` downloads the APK, verifies its SHA-256 (GitHub asset digest or `.sha256` sidecar) and opens the Android installer.
* Supports private repos via token, custom asset patterns and GitHub Enterprise.
* `REQUEST_INSTALL_PACKAGES` is opt-in: apps declare it themselves, so depending on this package never adds a Play-restricted permission. Missing it throws `PERMISSION_NOT_DECLARED` before any download.
* iOS, web and desktop throw `UNSUPPORTED_PLATFORM` instead of `MissingPluginException`.
