# Contributing

Thank you for helping improve Rosnect. File issues and pull requests at
https://github.com/rosnect/flutter_bridge_client.

The reusable package is at the repository root. The phone app is in `rosnect/`;
the small pub.dev example is in `example/`. Keep transport and interface logic
independent from hardware capture. Explain protocol changes and preserve
compatibility with the documented ros2embedded wire format.

Before a pull request:

```sh
flutter pub get
flutter analyze
flutter test
cd rosnect
flutter pub get
flutter analyze
flutter test
```

For a package release, also run `flutter pub publish --dry-run` at the repository
root and inspect the file list. Do not commit build output, SDK caches, broker
credentials or signing keys. The Rosnect app's `pubspec.lock` remains tracked;
the reusable library's lockfile is ignored.

Include regression tests for behavioral changes. State which device/ROS checks
were performed; passing widget tests does not establish hardware delivery.

Contributions intentionally submitted for inclusion are licensed under this
project's Apache License, Version 2.0. Preserve existing third-party notices.
