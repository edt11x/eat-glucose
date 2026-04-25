# Commit Workflow — edt-glucose

When asked to "Run the Commit Workflow", follow these steps in order.

## 1. Assess Current State

```bash
git status
git diff --stat
git log --oneline -5
```

Review what has changed since the last commit.

## 2. Stage New Files

- Identify untracked files that belong in the repo (source code, configs, docs, assets).
- Stage them with `git add`.
- Do NOT add files covered by `.gitignore` (build artifacts, DerivedData, .DS_Store, etc.).
- If `.gitignore` is missing entries, update it first.

## 3. Update Project Documentation

### MEMORY.md (`memory/MEMORY.md` in Claude Agent config)
- Record what was accomplished this session.
- Note key decisions made and known issues.
- Update architecture notes if new patterns were introduced.
- Keep concise — this is loaded into context every session.

### CLAUDE.md (repo root)
- Update the Key Files table if files were added or removed.
- Update Architecture section if frameworks or patterns changed.
- Update Event Types table if new event types were added.
- Update Data Model section if fields were added.

### README.md (repo root)
- Update Features section for new user-facing features.
- Update Charts & Analysis section for new charts.
- Update Settings section for new configurable items.
- Update Project Structure tree for new files.
- Ensure "Vibe Coded with Anthropic Claude" attribution remains.

## 4. Commit

Write a clear commit message following these conventions:
- **Subject line**: Short imperative (<=72 chars) summarizing the change.
- **Body**: Explain what changed and why if not obvious.
- **Trailer**: Always include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`.

```bash
git add <files>
git commit -m "$(cat <<'EOF'
Subject line here

Body explaining what and why.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

## 5. Push

```bash
git push
```

If no upstream is set: `git push --set-upstream origin main`

## 6. Verify

```bash
git status
git log --oneline -1
```

Confirm clean working tree and correct commit.

---

## Quick Reference — Shell Script

For the mechanical parts (stage, commit, push) without doc updates:

```bash
./scripts/commit-workflow.sh "Your commit message here"
```

## No Executable Files

This project has no command-line executables requiring `--help` updates. The only executable is the iOS app itself (built by Xcode). The shell script `scripts/commit-workflow.sh` has its own usage comment at the top.
