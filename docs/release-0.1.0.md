# Initial public release validation

Package: `ros2_embedded_bridge_client` 0.1.0.
License: Apache-2.0. Maintainer contact: rosnect.dev@tutaemail.com.

Completed locally with Flutter 3.22.0 / Dart 3.4.0:

- Library and full Rosnect app analyzer: no issues.
- Minimal example analyzer: no issues.
- 11 library tests and 13 app tests: all 24 pass.
- Public package source/example formatting checked with the same Dart version.
- API documentation generated with link validation: no code/link errors. The
  installed Dart documentation tool emits one internal deprecated-resources-dir
  warning, unrelated to this package's source.
- `flutter pub publish --dry-run`: zero warnings, compressed archive about 20 KB.
- Archive includes Apache LICENSE, NOTICE, README, CHANGELOG, pubspec, the library,
  tests, minimal example and MQTT smoke tool. Rosnect platform projects, generated
  build output, SDK caches and machine-local configuration are excluded.
- Existing Dart/Kotlin/Swift runtime source was compared with the previous commit:
  changes are comments/license headers and formatting only.
- Root generated SDK/build caches and the library lockfile are no longer tracked;
  local copies remain available. The app lockfile remains tracked.

The GitHub workflow repeats the checks on the same Flutter version and performs
an upload dry run only. It does not publish or contain pub.dev credentials.

A successful dry run is not a publication. Actual pub.dev upload requires the
Rosnect account owner's Google authorization and a successful upload confirmation.
A verified publisher is not claimed until its domain is verified on pub.dev.

These checks do not constitute a new physical phone/ROS, iOS, desktop hardware or
TLS certificate deployment test. Previously verified Android sensor operation is
unchanged by this licensing/package-preparation work.
