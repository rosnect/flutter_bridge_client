# Publishing ros2_embedded_bridge_client

Package: `ros2_embedded_bridge_client`, initial version `0.1.0`.
Source: https://github.com/rosnect/flutter_bridge_client
License: Apache-2.0. Contact: rosnect.dev@tutamail.com.

The root package is the reusable client. The `rosnect/` phone application stays
`publish_to: none` and is excluded from the pub.dev package. `.pubignore` excludes
app builds, generated SDK caches and local configuration. Do not publish a new
package by running the command from `rosnect/`.

## Account setup

Publishing requires a Google account chosen to own/upload the package. Sign
into https://pub.dev using that account and use the same account for CLI browser
authorization. The public maintainer contact `rosnect.dev@tutamail.com` is
independent; it does not need to be the Google login address. Do not put a
password, refresh token or credential file in Git.

A Rosnect Google account and a verified pub.dev publisher are different things.
A publisher such as `rosnect.dev` requires actual ownership/verification of that
domain. An email whose local part is `rosnect.dev` does not establish domain
ownership. No verified domain is asserted by this repository.

According to pub.dev's current flow, a new package is first uploaded by a Google
account and can then be transferred through its Admin tab to a verified publisher
that the account administers. Do not transfer it until the intended publisher is
verified and selected; that transfer cannot be reversed to a personal account.

## Release checks

From the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter pub publish --dry-run
```

Also verify the app and example:

```bash
cd rosnect
flutter pub get
flutter analyze
flutter test
cd ../example
flutter pub get
flutter analyze
```

Inspect the dry-run archive file list. It should contain LICENSE, NOTICE, README,
CHANGELOG, pubspec, lib, tests, the small example and the MQTT test tool, with no
Rosnect APK/platform projects, build/cache directories, machine paths or secrets.
A dry run does not authenticate or upload. The package name was unclaimed when
preparation began; availability is checked again by pub during publishing.

Before uploading, commit the reviewed release changes and push them so the
public license/docs correspond to the uploaded source. A clean Git status makes the dry run easier to review.
Do not use `--skip-validation` or `--force` to hide release problems.

## Upload

With the intended Google account ready:

```bash
flutter pub publish
```

Review the archive list and confirm the upload. If prompted, open the CLI's
Google authorization link and sign in with the intended package-owner account. The exact user
interaction must be completed by the account owner. No package is published
merely by adding metadata/license files or performing a dry run.

After successful upload:

1. Verify https://pub.dev/packages/ros2_embedded_bridge_client and version 0.1.0.
2. Verify installation from a fresh Flutter project with
   `flutter pub add ros2_embedded_bridge_client`.
3. Tag the corresponding Git commit as `v0.1.0`.
4. Add appropriate co-maintainers, or transfer to the intended verified publisher
   through the pub.dev Admin page when that publisher exists.

The GitHub CI workflow validates the package and examples; it does not publish or
store pub.dev credentials. Automated tag-based publication can be configured
later using pub.dev's supported GitHub OIDC publishing flow.

Official references:

- https://dart.dev/tools/pub/publishing
- https://dart.dev/tools/pub/cmd/pub-lish
- https://dart.dev/tools/pub/automated-publishing
- https://www.apache.org/foundation/license-faq
