# Commit Workflow — edt-glucose

When asked to **"Run the Commit Workflow"**, follow these steps **in order**.
Each step happens once; do not repeat staging or re-run earlier steps. Prefer a
high-thinking model for the judgment-heavy steps (tests, dedup, commit message).

> Ordering rationale: verify correctness (tests) → clean up (lint/dedup) → stamp
> the release (version) → prove it builds (clean build) → capture context (docs)
> → then and only then stage/commit/push. Staging appears **once**, at step 9.

## 1. Assess Current State

```bash
git status
git diff --stat
git log --oneline -5
```

Review what changed since the last commit. **Ask the user to clarify anything
ambiguous — do not guess about intent** (e.g. version scheme, whether a change
is a feature vs a fix).

## 2. Tests — add/verify (skip if already done for this build)

- Add or extend unit tests for the **new functionality** this session added.
- **Verify legacy data still works**: old exports/records missing recently added
  fields must decode and behave correctly (see `DataExporterTests`).
- New `GlucoseEvent` fields need a default value AND a
  `decodeIfPresent(...) ?? default` line in `DataExporter`.
- If unit tests for this build are already complete, skip this step.

## 3. Run All Tests

- **Boot a simulator first**, or every test reports "TEST FAILED / No result"
  (even pure-logic tests) with no crash log:
  ```bash
  xcrun simctl list devices available | grep iPhone   # pick one
  xcrun simctl boot <UDID>
  ```
- Run via the `RunAllTests` MCP (or Xcode Cmd+U).
- **If any test fails, add more tests around that area**, fix, and re-run until green.

## 4. Lint / Cleanup

- SwiftLint is **not** installed and there's no `.swiftlint.yml`; rely on the
  Swift compiler's warnings (keep the build warning-clean). Install SwiftLint
  only if the user asks.
- **Refactor obvious duplication** introduced this session (extract shared
  helpers rather than copy/paste).

## 5. Executable Help

Not applicable — the only "executable" is the iOS app (built by Xcode). The
shell script `scripts/commit-workflow.sh` carries its own usage header; update it
if its flags change.

## 6. Version Number

Bump in `edt-glucose.xcodeproj/project.pbxproj` (all build configs):
- `MARKETING_VERSION` — feature batch → minor (1.0 → 1.1); small fixes → patch.
- `CURRENT_PROJECT_VERSION` — increment the build number.

```bash
sed -i '' 's/MARKETING_VERSION = X;/MARKETING_VERSION = Y;/g;
          s/CURRENT_PROJECT_VERSION = A;/CURRENT_PROJECT_VERSION = B;/g' \
  edt-glucose.xcodeproj/project.pbxproj
```

## 7. Full Clean Build

```bash
xcodebuild clean build -scheme edt-glucose \
  -destination 'platform=iOS Simulator,id=<booted-UDID>'
```

Confirm `** BUILD SUCCEEDED **`.

## 8. Update Documentation

### Session prompts log (`prompts/YYYY-MM-DD-short-topic.md`)
- Include each user prompt **verbatim** and a concise summary of what was done.
- Note key decisions, gotchas, and files touched.
- **Always end with a `## Pickup Context` section** covering what the next
  session (this model or another) needs: pending questions, decisions + why,
  known sharp edges, in-flight work. If nothing is in flight, say so in one line.

### MEMORY.md (Claude Agent config `memory/MEMORY.md`)
- Record what was accomplished, key decisions, known issues; keep concise.

### CLAUDE.md (repo root)
- Update Key Files table, Architecture, Event Types table, Data Model as needed.

### README.md (repo root)
- Update Features / Charts / Settings / Project Structure for user-facing changes.
- Keep the "Vibe Coded with Anthropic Claude" attribution.

### SPEC.md / plan files (repo root)
- Update status markers and the Progress Summary table for shipped items.

## 9. Stage Files (once)

- Update `.gitignore` first if it's missing entries (build artifacts,
  DerivedData, .DS_Store, etc.).
- Stage untracked files that belong in the repo (source, configs, docs, assets)
  and all modified tracked files. Do **not** stage `.gitignore`-covered artifacts.

```bash
git add <files>
```

## 10. Commit

- **Subject**: short imperative, ≤72 chars.
- **Body**: what changed and why, when not obvious.
- **Trailer**: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

```bash
git commit -m "$(cat <<'EOF'
Subject line here

Body explaining what and why.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

## 11. Push

```bash
git push          # or: git push --set-upstream origin <branch>  (no upstream set)
```

## 12. Verify

```bash
git status        # clean working tree
git log --oneline -1
```

---

## Quick Reference — Shell Script

For the mechanical parts only (stage → commit → push), after you've done the
tests / version / docs steps manually:

```bash
./scripts/commit-workflow.sh "Your commit message here"
```

The script does not run tests, bump the version, or update docs — those are the
judgment steps above.
