# Current State

## Implemented Features
- Dashboard with calorie ring, remaining/used calories, macro progress, today food list, editable food rows.
- Diet goal editor with calories, macros, maintenance-aware deficit/surplus, diet score.
- Persistent current diet targets via `DailyGoalTargets.current`.
- Manual entry with image attachment and editable calories/macros/health score.
- Manual entry AI Guess tab using food name + grams to estimate nutrition.
- AI camera/photo entry using Gemini, with editable confirmation before saving.
- Food item editing from dashboard/history.
- Stats screen with 7D/1M/3M ranges, chart, goal line, maintenance line, average deficit/surplus, completed/missed days, net kcal lost/gained.
- History screen with Week/Month modes, scoped fetching, selected period highlighting, and period food summary.
- Settings profile with icons, name, weight, height, birth date, sex, activity, about me, theme, Gemini API key.
- Backup export/import for meals, goals, profile, settings, API key, and current targets.
- Streak bar colors days as success/surplus/empty.
- Codemagic screenshot workflow exports PNGs from UI test attachments.

## Unfinished / Next Useful Work
- Run Codemagic build and screenshot workflow after recent History/Settings/streak changes.
- Review History UI screenshots for spacing and period highlight clarity.
- Add more UI tests if behavior becomes critical, not just screenshot capture.
- Consider SwiftData migration handling if model properties change later.

## Known Bugs / Risks
- Local iOS builds cannot be validated on this Windows workspace.
- Gemini model name and API behavior can change; verify if API errors appear.
- SwiftData + CloudKit is configured as `.automatic`; behavior depends on entitlements/signing environment.
- Screenshot extraction in Codemagic has a fallback that copies PNGs from `.xcresult/Data`; keep this if `xcresulttool` changes.
- History currently fetches only the visible period; calendar heat colors outside that period are intentionally unavailable.

## Recent Notes
- `git add .` was requested earlier but interrupted; confirm staging before committing.
- Downloaded artifacts are ignored by `CalorieTracker_*_artifacts/`.
