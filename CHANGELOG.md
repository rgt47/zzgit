# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-04-22

### Fixed

- Branch detection on an empty repository (no commits). Previously
  `git rev-parse --abbrev-ref HEAD` returned the literal string
  `"HEAD"` with exit 128 in this state, so the protected-branch guard
  silently did not match on first-commit pushes to `main` or `master`,
  and the override log recorded `branch: HEAD` instead of the actual
  branch name. The plugin now prefers `git symbolic-ref --short HEAD`,
  which resolves correctly on an unborn branch, and falls back to
  `rev-parse` only for the detached-HEAD case.
- `gitleaks` invocations now pass `-v` so that findings are printed
  with file, line, rule ID, and fingerprint. Previously the scanner
  was invoked with no verbosity flag, which caused gitleaks to emit
  only a count (`leaks found: N`) and no detail. The refusal message
  referred to "the fingerprint reported by gitleaks" and to remediation
  options "below" the scan output, but neither was visible. Applied
  to both the newer `gitleaks git --staged` and the older
  `gitleaks protect --staged` code paths.

## [0.1.0] - 2026-04-22

### Added

- Initial release as a zsh plugin.
- Interactive file selection via `fzf`; falls back to a numeric menu when
  `fzf` is not installed.
- Conventional Commits wizard covering type, scope, subject, and body.
- Content-based secret scanning of the staged diff via `gitleaks`;
  supports both the newer `gitleaks git --staged` and the older
  `gitleaks protect --staged` subcommands.
- Filename-heuristic fallback for environments where `gitleaks` is not
  installed; prints a prominent warning and offers only a degraded
  check.
- Protected-branch guard driven by `ZZGIT_PROTECTED_BRANCHES`; default
  list is `main master`.
- Audited override path for secret-scan findings, gated on
  `ZZGIT_ALLOW_SECRET_OVERRIDE=1` and a typed reason of at least 10
  characters. Each override appends a structured record to
  `$GIT_DIR/zzgit-overrides.log`.
- Independent pre-commit and pre-push confirmation prompts; the
  pre-push prompt is phrased more strongly on protected branches.
- Companion function `zzgit-scan-history` for scanning the full git
  history.
- `-h` / `--help` and `-v` / `--version` flags on `zzgit`; `-h` /
  `--help` on `zzgit-scan-history`.
- `emulate -L zsh` guards on each function to keep behavior stable
  across users' `setopt` configurations.
