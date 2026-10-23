## 0.0.1

* Initial release.
* `checkForUpdate` reads the latest GitHub release and compares it to the installed version.
* `downloadAndInstall` downloads the APK, verifies its SHA-256 (GitHub asset digest or `.sha256` sidecar) and opens the Android installer.
* Supports private repos via token, custom asset patterns and GitHub Enterprise.
