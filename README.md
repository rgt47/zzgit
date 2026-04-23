# zzgit

*2026-04-22 17:05 PDT*

Interactive `git add` / `git commit` / `git push` for zsh, with a
Conventional Commits wizard, a protected-branch guard, and content-based
secret scanning of the staged diff via `gitleaks`.

`zzgit` is intended to replace the common reflex of `git add . && git
commit -am '...' && git push`, which stages credentials by accident,
produces subject lines that describe only filenames, and pushes to
`main` / `master` without a second thought.

## Dependencies

- `git` (required)
- `fzf` (optional; used for interactive multi-select file staging. Falls
  back to a numeric menu if missing)
- `gitleaks` (optional but recommended; used for content-based secret
  scanning of the staged diff. Falls back to a filename heuristic with a
  loud warning if missing)

Install the optional dependencies on macOS with:

```zsh
brew install fzf gitleaks
```

## Installation

### oh-my-zsh

```zsh
git clone https://github.com/rgthomas47/zzgit \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zzgit
# then add `zzgit` to the plugins=(...) list in ~/.zshrc
```

### zinit

```zsh
zinit load rgthomas47/zzgit
```

### antidote

```zsh
antidote bundle rgthomas47/zzgit
```

### Manual

```zsh
git clone https://github.com/rgthomas47/zzgit ~/.zsh/plugins/zzgit
# in ~/.zshrc:
source ~/.zsh/plugins/zzgit/zzgit.plugin.zsh
```

## Usage

Inside a git working tree:

```zsh
zzgit
```

The interactive flow:

1. Print the current branch and `git status --short`.
2. Offer a multi-select list of unstaged and untracked files (`fzf` or
   numeric fallback). Selected files are staged via `git add --`.
3. Scan the staged diff with `gitleaks`. If findings are reported, refuse
   to proceed and print three remediation options.
4. Prompt for commit type (one of `feat / fix / refactor / docs / test /
   chore / perf / ci / style`), optional scope, subject line, optional
   body.
5. Preview the assembled message and require a `y` confirmation before
   `git commit`.
6. After commit, prompt again before `git push` (protected branches get
   an extra-explicit prompt with the branch name surfaced).

Built-in help:

```zsh
zzgit -h
zzgit --version
zzgit-scan-history -h
```

## Configuration

All configuration is via environment variables.

### `ZZGIT_PROTECTED_BRANCHES`

Space-separated list of branches that require an explicit extra
confirmation on push. Default: `main master`.

```zsh
export ZZGIT_PROTECTED_BRANCHES='main master release develop'
```

The guard is client-side and advisory. For real enforcement, configure
branch protection on the remote (GitHub, GitLab, Gitea).

### `ZZGIT_SECRET_SCANNER`

Which scanner to use on the staged diff. Options:

- `gitleaks` (default): content-based scanning. Catches credentials
  regardless of filename.
- `none`: skip scanning entirely. Use only in repos where upstream CI
  already scans every commit.

```zsh
export ZZGIT_SECRET_SCANNER='gitleaks'
```

### `ZZGIT_ALLOW_SECRET_OVERRIDE`

Enables an audited override path when gitleaks flags findings. Not set
by default; must be exported in the current shell to opt in.

```zsh
export ZZGIT_ALLOW_SECRET_OVERRIDE=1
```

When set, a gitleaks finding triggers a second prompt for a reason (at
least 10 characters). The reason, timestamp, user, branch, and staged
file list are appended to `$GIT_DIR/zzgit-overrides.log`.

Do not set this permanently in `~/.zshrc`; that defeats the purpose.

### gitleaks configuration

`gitleaks` reads `.gitleaks.toml` (rule definitions) and `.gitleaksignore`
(per-finding fingerprints to allowlist) from the repo root automatically.
Commit a `.gitleaksignore` entry for each confirmed false positive so the
override path can remain rare.

## Commit message format

Messages are assembled as:

```
<type>(<scope>): <subject>

<body>
```

The scope and body are optional. If the subject prompt is left blank, a
comma-separated list of the first five staged files is substituted (with
`and N more files` appended when applicable), matching the behavior of
the pre-v0.1 single-function version.

## Companion commands

### `zzgit-scan-history`

Scan the full git history for secrets. Complements `zzgit`, which scans
only the staged diff. Recommended after cloning an unfamiliar repo,
merging a long-lived branch, or on a periodic audit schedule.

```zsh
zzgit-scan-history
```

## Design notes

### Why a push confirmation in addition to `git commit`'s own

`git commit` is local-only and reversible. `git push` is not. Splitting
the confirmation lets you make a commit, inspect it with `git log -1`
or `git show`, and then decide whether to publish.

### Why refuse on gitleaks findings instead of prompting

`[y/N]` prompts after secret-scan findings train users to mash `y`. The
refusal-by-default design forces three deliberate actions for the
override path: exporting an env var, re-running `zzgit`, and typing a
reason of non-trivial length. This keeps overrides rare and auditable.

### Why a protected-branch guard

`zzgit` cannot prevent a push to `main` that the remote allows; only the
remote can. The guard exists to catch the specific failure mode of
reflexively typing `zzgit` on the wrong branch.

### Limitations

- Scan coverage is gitleaks' rule pack. Bespoke credential formats
  require `.gitleaks.toml` rule additions.
- Binary blobs (`.pfx`, `.p12`) can slip past content scanning. Add
  path-based rules to `.gitleaks.toml` if this matters.
- `zzgit` does not scan unstaged changes; files you do not select are
  not scanned.
- History scanning is separate (`zzgit-scan-history`); the hot path
  scans only the staged diff to stay fast.

## License

MIT. See [LICENSE](LICENSE).

---

*Rendered on 2026-04-22 at 17:05 PDT.*<br>
*Source: ~/prj/sfw/13-zzgit/README.md*
