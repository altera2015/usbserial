# Releasing usb_serial

Releases are made by pushing a version tag to a commit on `master`. The
[Release workflow](workflows/release.yml) then:

1. **verify**: checks that the tag is on `master`, that it equals `v` + the
   `pubspec.yaml` version, and that `CHANGELOG.md` has a `## <version>` section.
   It then runs analyze, the tests and `flutter pub publish --dry-run`.
2. **github-release**: creates the GitHub release, using that CHANGELOG section
   as the notes. Versions with a `-` (e.g. `0.7.0-dev.1`) become pre-releases.
3. **publish-pub-dev**: publishes to pub.dev with GitHub's OIDC token, so no
   secrets are stored in the repo. This job is allowed to fail (see below).

## Steps

1. On a branch, bump `version:` in `pubspec.yaml` and rename `## Unreleased`
   in `CHANGELOG.md` to `## <version>`. Open a PR and merge it once CI is green.
2. Tag the merge commit on `master` and push the tag:

   ```sh
   git switch master && git pull
   git tag -a v0.6.0 -m "v0.6.0"
   git push origin v0.6.0
   ```

3. Watch the run under **Actions → Release**.

If **verify** fails (for example, a tag/version mismatch), nothing is released.
Delete the tag (`git push --delete origin v0.6.0 && git tag -d v0.6.0`), fix the
problem on `master`, and tag again.

## pub.dev automated publishing (one-time setup by a package admin)

Until this is done, the **publish-pub-dev** job fails without blocking the
GitHub release.

On <https://pub.dev/packages/usb_serial/admin>, under **Automated publishing**:

- Enable **publishing from GitHub Actions**.
- Repository: `altera2015/usbserial`
- Tag pattern: `v{{version}}`
- Optional: **require GitHub Actions environment** `pub.dev`.

To publish a release that was tagged before this was set up, open that tag's
**Release** run and use **Re-run jobs → publish-pub-dev**. A re-run keeps the
original tag event, which is what pub.dev checks. It also uses the workflow file
as it was at the tagged commit.
