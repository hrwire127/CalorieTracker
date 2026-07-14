# Demo Checklist

## Automated Gate
1. Run Codemagic `ios-simulator-build`; app build and all unit tests must pass.
2. Run `ios-simulator-screenshots`; verify all seven PNG artifacts.
3. Run `ios-unsigned-device-ipa`; verify the IPA artifact is produced.

## Physical iPhone Smoke Test
1. Launch without an API key and confirm manual entry still works.
2. Enter the Gemini API key in Settings and restart the app.
3. Run AI Guess with a food name and weight; edit and save the estimate.
4. Scan a clear food photo; edit and save the confirmation result.
5. Disable networking, retry a scan, then complete the retained photo manually.
6. Edit and delete meals from Today and History; verify totals update.
7. Change diet targets, restart the app, and verify they persist.
8. Verify History week/month modes and Stats 7D/1M/3M ranges.
9. Export a backup, import it, and confirm meals/profile return while the API key remains unchanged.

## Release Gate
The demo is ready only after all automated jobs pass and the physical-device smoke test has no data loss, duplicate meals, silent save errors, or blocked manual-entry path.
