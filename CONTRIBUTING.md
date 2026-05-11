# Contributing to MacDev

Thanks for helping improve MacDev. This project is a native macOS developer tool, so changes should preserve local-first behavior, precise process control, and a small trusted surface area.

## Good First Contributions

- Parser and classifier improvements for real local runtime output.
- Accessibility, keyboard, and VoiceOver polish.
- Tests for `MacDevCore` services and models.
- Documentation fixes that make installation or preview status clearer.

## Development Setup

```bash
swift build
swift test
./script/build_and_run.sh --verify
```

Use macOS 14+ with Xcode 15+ or a compatible Apple Swift toolchain.

## Pull Request Guidelines

- Keep PRs focused on one behavior or documentation area.
- Explain the user-facing impact and the validation you ran.
- Add or update tests when changing parser, classifier, process, or profile behavior.
- Avoid broad process-control commands. MacDev should target exact PIDs and explain system-looking services before suggesting action.
- Do not add telemetry, network upload, account requirements, or backend dependencies without a dedicated design discussion first.

## Release Changes

Release-facing changes should update `RELEASE_NOTES.md` or `docs/release.md` when they affect download, packaging, signing, installer behavior, or public trust.
