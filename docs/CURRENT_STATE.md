# Current State

## Implemented Features
- Dashboard with calorie ring, remaining/used calories, macro progress, today food list, editable food rows.
- Diet goal editor with calories, macros, maintenance-aware deficit/surplus, diet score.
- Persistent current diet targets via `DailyGoalTargets.current`.
- Manual entry with image attachment and editable calories/macros/health score.
- Manual entry AI Guess tab using food name + grams to estimate nutrition.
- AI camera/photo entry using Gemini, with editable confirmation before saving.
- Gemini requests use system instructions, JSON Schema, typed errors, bounded retry, one-at-a-time execution, request coalescing, cache, and local `429` cooldown.
- AI image payloads are resized/compressed before upload; failed scans retain the photo for manual completion.
- Food item editing from dashboard/history.
- Stats screen with 7D/1M/3M ranges, chart, goal line, maintenance line, average deficit/surplus, completed/missed days, net kcal lost/gained.
- History screen with Week/Month modes, scoped fetching, selected period highlighting, and period food summary.
- Settings profile with icons, name, weight, height, birth date, sex, activity, about me, theme, Gemini API key.
- Validated backup export/import for meals, goals, profile, settings, and current targets. API keys are intentionally excluded.
- Streak bar colors days as success/surplus/empty.
- Codemagic screenshot workflow exports PNGs from UI test attachments.
- Codemagic simulator workflow runs 16 unit tests covering AI, persistence, backup, and validation.

## Unfinished / Next Useful Work
- Run the Codemagic `ios-simulator-build` workflow to compile and execute the new unit tests.
- Run the screenshot workflow and review all seven screens in light mode on the selected simulator.
- Install the resulting unsigned IPA through the existing sideloading flow and execute the physical-device demo checklist.
- Review History UI screenshots for spacing and period highlight clarity.
- Add more UI tests if behavior becomes critical, not just screenshot capture.
- Consider SwiftData migration handling if model properties change later.

## Known Bugs / Risks
- Local iOS builds cannot be validated on this Windows workspace.
- Gemini model availability, quotas, and API behavior can change; typed errors reduce impact but cannot remove provider outages.
- SwiftData + CloudKit is configured as `.automatic`; behavior depends on entitlements/signing environment.
- Screenshot extraction in Codemagic has a fallback that copies PNGs from `.xcresult/Data`; keep this if `xcresulttool` changes.
- History currently fetches only the visible period; calendar heat colors outside that period are intentionally unavailable.
- Unit tests and an iOS build cannot run directly in this Windows workspace; Codemagic remains the compilation gate.

## Recent Notes
- Do not consider the demo release complete until Codemagic unit tests, screenshots, and a physical-device smoke test pass.
- Downloaded artifacts are ignored by `CalorieTracker_*_artifacts/`.
