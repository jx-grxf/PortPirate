# Release Runbook

MacDev preview releases are built on GitHub Actions from tags.

## Local Preflight

```bash
swift test
./script/build_and_run.sh build-only
codesign --verify --deep --strict dist/MacDev.app
MACDEV_VERSION=0.1.2 ./script/package_dmg.sh
hdiutil imageinfo dist/MacDev-0.1.2.dmg >/dev/null
```

## Publish

```bash
git tag -s v0.1.2 -m "release v0.1.2"
git push origin v0.1.2
```

The `Release` workflow creates or updates the GitHub Release and uploads `MacDev-<version>.dmg`.

## Distribution Notes

Current preview builds are ad-hoc signed for bundle integrity. Public end-user distribution should move to Developer ID signing, hardened runtime, notarization, and stapling before the app is marketed outside GitHub preview releases.
