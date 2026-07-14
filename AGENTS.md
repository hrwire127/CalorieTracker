# AI Agent Handoff

## Project Purpose
Native iOS calorie tracker for personal use. The app lets a user set diet targets, log meals manually or with AI assistance, review progress, inspect history, export/import backups, and capture UI screenshots through Codemagic.

## Tech Stack
- Swift / SwiftUI
- SwiftData for local persistence
- Swift Charts
- PhotosUI and AVFoundation camera bridge
- URLSession with Google Gemini Vision/text requests
- XcodeGen via `project.yml`
- Codemagic for simulator builds, screenshots, and unsigned IPA packaging

## Important Rules
- Do not commit build artifacts, downloaded Codemagic artifacts, DerivedData, or generated `.xcodeproj` unless explicitly requested.
- Keep SwiftUI changes consistent with the existing simple MVVM style.
- Use `DailyGoalTargets.current` when creating new `DailyGoal` records.
- Do not reset user data or SwiftData schema casually; migrations matter.
- Keep API keys in user settings/UserDefaults, not source code.
- Never add the Gemini API key to exported backups, logs, fixtures, or screenshots.
- Keep AI access behind `NutritionEstimating` so tests can use deterministic stubs.
- Preserve retry limits, request coalescing, local cooldown, and edit-before-save behavior.
- Run `git diff --check` after edits.
- Add or update tests in `Tests/` for persistence, backup, validation, or AI behavior changes.
- On Windows, local iOS builds are unavailable; use Codemagic/Xcode on macOS for real build validation.
- Prefer small, focused changes. Avoid unrelated UI rewrites.

## Useful Docs
- `docs/PROJECT_MAP.md`
- `docs/CURRENT_STATE.md`
- `docs/ARCHITECTURE.md`
- `docs/DEMO_CHECKLIST.md`
