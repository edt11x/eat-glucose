# 2026-10-10 / 2026-10-11 — Post-macOS-upgrade check, version line, Xcode hangs

## Prompt 1
> I want to make sure the project is intact after Mac OS upgrades. Rebuild the Blood Glucose app, run all the tests and re-install it on my iPhone 14 Pro Max verifying that things are intact.

**Done:** Clean build against the iOS 27.0 SDK (Xcode 27.0, macOS 27.0.1) succeeded; app code warning-clean. 38/38 tests passed on the iPhone 17 Pro Max iOS 26.5 simulator. Installed + launched on the iPhone 14 Pro Max (iOS 27.0.1), no app errors in console. New toolchain flags 3 Swift-6-mode concurrency warnings in `edt_glucoseTests.swift` (~line 474, `NamedLocation` main-actor-isolated Codable/Equatable conformance) — not fixed (not requested).

## Prompt 2
> On the front page, underneath the "Blood Glucose" title I would like in a small font, a version number that is incremented anytime a new version is pushed to the phone or commited to Github, followed by the date of the build.

**Done:**
- `build-number.txt` (repo root) — the counter.
- `scripts/build-info.sh` — "Build Info" Run Script phase (added to the app target in `project.pbxproj`, after Resources, always out of date). On `iphoneos` builds increments the counter; always writes `BuildInfo.plist` (BuildNumber, BuildDate) into the app bundle. Simulator builds don't bump.
- `scripts/githooks/pre-commit` — bumps the counter on commit unless a device build already bumped it since HEAD (so phone and GitHub show the same number); enabled via `git config core.hooksPath scripts/githooks`.
- `BuildInfo.swift` + `.navigationSubtitle(BuildInfo.displayString)` in `ContentView` → "Version 1.5 (9) · Oct 11, 2026".
- 2 new `BuildInfoTests` (40 tests total, all pass).
- Gotcha: listing `build-number.txt` as both input and output of the script phase → "Cycle inside edt-glucose" build error. Fixed by keeping it output-only.

## Prompt 3
> Run the build, upload it to the phone, run the commit workflow and push it to Github.

## Prompts 4–6 (Xcode hangs)
> This operation keeps hanging. Try to do this safely, in smaller steps, where this won't hang Xcode.

> Again this operation hung Xcode. Investigate and solve this problem. ... Log information about what steps are being taken and what steps have been completed so you can debug the Xcode and Claude hangs. ...

> Again Xcode hung after allowing a Claude instruction. Investigate this action. ... Access public information and find if users are having problems with Claude and Xcode.

**Findings:** Hangs began with the `BuildProject` MCP call right after the 2nd shell edit of `project.pbxproj` (Xcode had the project open). After that every approval-gated tool call failed with "PreToolUse hook did not respond before its timeout (host client may be unreachable)" — i.e. Xcode's main thread was unresponsive; non-approval tools (Read, WebSearch) worked. No Xcode hang reports exist (force-quit doesn't generate one). Public search found related Claude Code PreToolUse/IDE freeze issues (#33073, #95354, #11807) and Xcode MCP permission-prompt issues (#27557) but no exact match. Leading suspects: Xcode project-reload / modal dialog after external pbxproj edits, and/or a bug in Xcode 27's agent bridge. Unconfirmed — a `sudo spindump Xcode 10 -file …` during the next hang would settle it.

## Prompt 7
> I have the two terminal commands and have executed the first one. Try again

**Done (no hangs):** Bypassed the Xcode MCP build/run tools entirely. Each step a short Bash call, long work run in background (`nohup … > debug/<step>.log &`) and polled, every step logged to `debug/xcode-hang-log.md`:
1. trivial probe → ok
2. `xcodebuild … -destination 'platform=iOS,name=Ed iPhone 14 Pro Max' build` → BUILD SUCCEEDED, build 9
3. verified `BuildInfo.plist` in product, no warnings
4. `xcrun devicectl device install app` → installed
5. `xcrun devicectl device process launch` → launched
6–8. tests (40 pass), docs, commit, push.

Also: `debug/` added to `.gitignore`; Co-Authored-By trailer in `scripts/commit-workflow.sh` + `COMMIT_WORKFLOW.md` updated to Claude Opus 5.5; COMMIT_WORKFLOW step 6 documents the automatic build number.

## Pickup Context
- Build number now comes from `build-number.txt` (9 at this commit); `CURRENT_PROJECT_VERSION` in pbxproj (6) is no longer what's displayed — left alone to avoid another pbxproj edit.
- **Xcode-hang safety:** do not edit `project.pbxproj` from the shell while Xcode is open; prefer background `xcodebuild`/`devicectl` over `BuildProject`/`RunProject` MCP. Root cause still unconfirmed; if it recurs, ask the user to run `sudo spindump Xcode 10 -file ~/swift/edt-glucose/edt-glucose/debug/xcode-spindump.txt` before force-quitting and read that file.
- Every new clone needs `git config core.hooksPath scripts/githooks` for commit bumps.
- Open item: 3 Swift 6 concurrency warnings in the test file (NamedLocation conformances).
- Phase 3.1 next increment (empirical ISF fit) unchanged — see SPEC.md.
