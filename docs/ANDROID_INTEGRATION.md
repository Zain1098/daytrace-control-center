# Android integration contract

The web control center is optional. DayTrace must retain its local defaults whenever these endpoints are unavailable, malformed, unauthenticated, or slow.

## Existing updater compatibility

The current Android updater reads `https://api.github.com/repos/{repository}/releases/latest`, parses a release tag ending in `+build`, and opens an APK URL externally. This dashboard stores release metadata for owner review and future rollout policy; it does not force installation and does not replace the GitHub Release flow.

## Public, safe metadata

- `GET /api/v1/remote-config` returns `{ version, generatedAtUtc, settings }`.
- `GET /api/v1/maintenance` returns `{ active, offlineCoreUnaffected: true }`.

Only enabled optional configuration values are published. The app must validate key/type/build range locally, reject unknown or core-data keys, and fall back to bundled values. Do not send task, timer, timeline, reminder, report, or backup content to either endpoint.

## Backups

Owner-uploaded backup inspection is separate from the phone restore workflow. Accepted files use the existing envelope: `format: "daytrace-backup"`, integer `schemaVersion`, UTC `createdAtUtc`, and the expected data tables. No web upload can initiate restore on an Android device.
