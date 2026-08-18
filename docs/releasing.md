# Releasing Disposable Email

## Prepare a release

1. Update `manifest.json` to the release version.
2. Add the release notes to `CHANGELOG.md`.
3. Run the focused tests, QML lint, and plugin validation:

   ```bash
   for test_file in tests/*.js providers/tests/run.js; do
     node "$test_file"
   done

   qmllint -I /usr/share/omarchy/shell \
     BarWidget.qml Panel.qml Service.qml \
     lib/*.qml providers/*.qml ui/*.qml

   omarchy plugin validate .
   ```

4. Push the validated commit to `master`.
5. Create and push the annotated version tag:

   ```bash
   git tag -a v0.2.0 -m "Release v0.2.0"
   git push origin v0.2.0
   ```

6. Create the GitHub release from the matching changelog section.

The tag and GitHub release are useful release records. The marketplace update
itself follows the repository branch and does not depend on a GitHub release.

## Marketplace updates

Disposable Email is already registered in the marketplace under
`io.github.ajanraj.disposable-email`. Do not open another submission issue for
a normal release.

The marketplace refresh workflow reads listed repositories and rebuilds the
catalog every day at 04:17 UTC. After a validated release is pushed to this
repository's default branch, the next successful refresh should read the new
root manifest, version, README, and preview automatically.

The marketplace owns category and tag metadata separately from the plugin
manifest. The current listing uses the `Productivity` category and the `bar`,
`quickshell`, and `security` tags. Repository changes do not update those
values. The marketplace currently documents no dedicated metadata-update form.
If those values need to change, ask a maintainer on the original submission
issue instead of opening a duplicate plugin submission.

## Sources

- [Official publishing guide](https://omarchyplugins.com/publish.html)
- [Marketplace submission and refresh notes](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/main/SUBMISSION.md)
- [Scheduled catalog refresh workflow](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/main/.github/workflows/refresh-catalog.yml)
- [Marketplace registry](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/main/registry.json)
- [Original Disposable Email submission](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/578)
