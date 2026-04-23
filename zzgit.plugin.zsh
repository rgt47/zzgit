#!/usr/bin/env zsh
# zzgit - interactive git add/commit/push with content-based secret
# scanning, a Conventional Commits wizard, and a protected-branch guard.
#
# Repository: https://github.com/rgt47/zzgit
# License: MIT (see LICENSE)

typeset -g ZZGIT_VERSION='0.1.1'

# ----------------------------------------------------------------------------
# Help strings
# ----------------------------------------------------------------------------

_zzgit_help() {
    cat <<'EOF'
zzgit - interactive git add/commit/push with secret scanning.

Usage: zzgit [-h|--help] [-v|--version]

Interactive workflow:
  1. Show branch and working-tree status.
  2. Select files to stage (fzf if installed; numeric menu otherwise).
  3. Scan staged content for secrets (gitleaks if installed).
  4. Choose commit type, scope, subject, body.
  5. Confirm, commit, then confirm and push.

Environment variables:
  ZZGIT_PROTECTED_BRANCHES     space-separated branches.
                               Default: "main master"
  ZZGIT_SECRET_SCANNER         "gitleaks" (default) or "none"
  ZZGIT_ALLOW_SECRET_OVERRIDE  set to 1 to enable an audited override when
                               gitleaks flags findings. Overrides are
                               appended to $GIT_DIR/zzgit-overrides.log.
                               Do not set this permanently.

Companion:
  zzgit-scan-history           scan the full git history for secrets.

See README.md for details.
EOF
}

_zzgit_scan_history_help() {
    cat <<'EOF'
zzgit-scan-history - scan the full git history for secrets.

Usage: zzgit-scan-history [-h|--help]

Runs the scanner configured by ZZGIT_SECRET_SCANNER over the entire log.
Complements zzgit, which only scans the staged diff.
EOF
}

# ----------------------------------------------------------------------------
# Main function
# ----------------------------------------------------------------------------

zzgit() {
    emulate -L zsh

    case "$1" in
        -h|--help)    _zzgit_help; return 0 ;;
        -v|--version) echo "zzgit $ZZGIT_VERSION"; return 0 ;;
        '')           ;;
        *)            echo "zzgit: unknown argument: $1" >&2
                      echo "Try 'zzgit -h' for usage." >&2
                      return 2 ;;
    esac

    # Repo guard
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo 'Error: Not a git repository' >&2
        return 1
    fi

    # Branch + protected-branch check. symbolic-ref works on an empty
    # repo (unborn branch); fall back to rev-parse for detached HEAD.
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) \
      || branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) \
      || branch='HEAD'
    local protected_branches="${ZZGIT_PROTECTED_BRANCHES:-main master}"
    local is_protected=0 b
    for b in ${=protected_branches}; do
        [[ "$branch" == "$b" ]] && is_protected=1
    done

    echo "Branch: $branch"
    echo ''
    echo 'Working tree status:'
    git status --short
    echo ''

    # Gather unstaged candidates (tracked-modified + untracked, deduped,
    # empties stripped). Filenames with spaces survive because (f) splits
    # only on newlines.
    local -a unstaged
    unstaged=(
        ${(f)"$(git diff --name-only 2>/dev/null)"}
        ${(f)"$(git ls-files --others --exclude-standard 2>/dev/null)"}
    )
    typeset -U unstaged
    unstaged=(${unstaged:#})

    # Interactive file selection
    local -a chosen
    if [[ ${#unstaged[@]} -gt 0 ]]; then
        if command -v fzf > /dev/null 2>&1; then
            echo 'Select files to stage (TAB multi-select, Enter confirm, Esc none):'
            chosen=(${(f)"$(printf '%s\n' "${unstaged[@]}" | fzf -m --prompt='stage> ' --height=40% --reverse)"})
        else
            echo 'Unstaged / untracked files:'
            local i=1 f
            for f in "${unstaged[@]}"; do
                printf '  %2d) %s\n' $i "$f"
                ((i++))
            done
            echo ''
            echo -n 'Select files (numbers space/comma-separated, "a" all, Enter none): '
            local sel
            read -r sel
            if [[ "$sel" == 'a' || "$sel" == 'A' ]]; then
                chosen=("${unstaged[@]}")
            elif [[ -n "$sel" ]]; then
                local -a idxs
                idxs=(${(s: :)${sel//,/ }})
                local n
                for n in "${idxs[@]}"; do
                    if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#unstaged[@]} )); then
                        chosen+=("${unstaged[$n]}")
                    fi
                done
            fi
        fi
        chosen=(${chosen:#})
    fi

    # Stage selected files
    if [[ ${#chosen[@]} -gt 0 ]]; then
        if ! git add -- "${chosen[@]}"; then
            echo 'Error: git add failed' >&2
            return 1
        fi
    fi

    # Need something in the index at this point
    if [[ -z "$(git diff --cached --name-only)" ]]; then
        echo 'Nothing staged. Aborting.' >&2
        return 1
    fi

    # Content-based secret scan of the staged diff. Refuses on findings
    # unless ZZGIT_ALLOW_SECRET_OVERRIDE=1 (audited). Non-destructive: on
    # refusal the index is left as-is so you can run `git reset HEAD -- <f>`
    # or edit the file and re-run zzgit.
    if ! _zzgit_secret_scan; then
        return 1
    fi

    # Summary
    echo ''
    echo '---------------------------------------------------------------'
    echo 'STAGED CHANGES'
    echo '---------------------------------------------------------------'
    git diff --cached --stat
    echo ''
    echo 'Preview (first 30 lines):'
    git --no-pager diff --cached | awk 'NR<=30'
    echo ''

    # Commit type
    echo '---------------------------------------------------------------'
    echo 'Commit type:'
    echo '  1) feat       - A new feature'
    echo '  2) fix        - A bug fix'
    echo '  3) refactor   - Code refactoring'
    echo '  4) docs       - Documentation updates'
    echo '  5) test       - Adding/updating tests'
    echo '  6) chore      - Build, config, dependencies'
    echo '  7) perf       - Performance improvements'
    echo '  8) ci         - CI/CD configuration'
    echo '  9) style      - Code style (formatting, linting)'
    echo ''
    echo -n 'Select commit type (1-9): '
    local type_choice type
    read -r type_choice
    case $type_choice in
        1) type='feat' ;;
        2) type='fix' ;;
        3) type='refactor' ;;
        4) type='docs' ;;
        5) type='test' ;;
        6) type='chore' ;;
        7) type='perf' ;;
        8) type='ci' ;;
        9) type='style' ;;
        *) echo "Invalid choice. Using 'chore'" >&2; type='chore' ;;
    esac

    local scope subject body
    echo -n 'Scope (optional, Enter to skip): '
    read -r scope
    echo -n 'Subject (short imperative summary of the change): '
    read -r subject
    if [[ -z "$subject" ]]; then
        local -a staged_now
        staged_now=(${(f)"$(git diff --cached --name-only)"})
        staged_now=(${staged_now:#})
        local -a first_five=(${staged_now[1,5]})
        subject=${(j:,:)first_five}
        if (( ${#staged_now[@]} > 5 )); then
            subject="$subject and $((${#staged_now[@]} - 5)) more files"
        fi
        echo "  (no subject given; using file list: $subject)"
    fi
    echo -n 'Body (optional, Enter to skip): '
    read -r body

    local commit_msg="$type"
    [[ -n "$scope" ]] && commit_msg="$commit_msg($scope)"
    commit_msg="$commit_msg: $subject"
    [[ -n "$body" ]] && commit_msg="$commit_msg"$'\n\n'"$body"

    # Pre-commit confirmation
    echo ''
    echo '---------------------------------------------------------------'
    echo 'Ready to commit:'
    echo "  branch:  $branch"
    echo '  files to be committed:'
    git diff --cached --name-only | sed 's/^/    - /'
    echo '  message:'
    echo "$commit_msg" | sed 's/^/    /'
    if [[ $is_protected -eq 1 ]]; then
        echo "  NOTE: '$branch' is a protected branch (see ZZGIT_PROTECTED_BRANCHES)."
    fi
    echo '---------------------------------------------------------------'
    echo -n 'Proceed with commit? [y/N]: '
    local proceed
    read -r proceed
    [[ "$proceed" == 'y' || "$proceed" == 'Y' ]] || { echo 'Aborted.'; return 1; }

    if ! git commit -m "$commit_msg"; then
        echo 'Error: Commit failed' >&2
        return 1
    fi

    # Push confirmation (extra-explicit on protected branches)
    local push_prompt='Push now? [y/N]: '
    [[ $is_protected -eq 1 ]] && push_prompt="About to push to protected branch '$branch'. Proceed? [y/N]: "
    echo -n "$push_prompt"
    local do_push
    read -r do_push
    if [[ "$do_push" != 'y' && "$do_push" != 'Y' ]]; then
        echo "Commit made on '$branch'. Not pushed."
        return 0
    fi

    if git push; then
        echo "Successfully pushed '$branch'."
    else
        echo 'Error: Push failed' >&2
        return 1
    fi
}

# ----------------------------------------------------------------------------
# Secret scan helper
# ----------------------------------------------------------------------------

# Content-based secret scan of the staged index. Called from zzgit.
# Returns 0 if clean or override accepted; 1 if findings and no override.
_zzgit_secret_scan() {
    emulate -L zsh

    local scanner="${ZZGIT_SECRET_SCANNER:-gitleaks}"
    if [[ "$scanner" == 'none' ]]; then
        echo 'Secret scan disabled (ZZGIT_SECRET_SCANNER=none).'
        return 0
    fi

    # Scanner missing: degraded mode with filename-only heuristic plus a
    # loud warning. This is explicitly worse than content scanning and is
    # only a stopgap until gitleaks is installed.
    if ! command -v "$scanner" > /dev/null 2>&1; then
        echo '---------------------------------------------------------------'
        echo "WARNING: '$scanner' not installed. Content-based secret scanning"
        echo 'is unavailable; falling back to filename heuristic only.'
        echo ''
        echo "Install:  brew install $scanner"
        echo '(or disable this check with  export ZZGIT_SECRET_SCANNER=none )'
        echo '---------------------------------------------------------------'
        local -a staged risky
        staged=(${(f)"$(git diff --cached --name-only)"})
        staged=(${staged:#})
        local f
        for f in "${staged[@]}"; do
            [[ "$f" == *.pub ]] && continue
            case "$f" in
                *.env|*.env.*|*credentials*|*secret*|*.pem|*.key|*id_rsa*|*id_ed25519*|*.p12|*.pfx)
                    risky+=("$f")
                    ;;
            esac
        done
        if [[ ${#risky[@]} -gt 0 ]]; then
            echo 'Filename heuristic flagged:'
            local r
            for r in "${risky[@]}"; do echo "  - $r"; done
            echo -n 'Continue without content scan? [y/N]: '
            local ok
            read -r ok
            [[ "$ok" == 'y' || "$ok" == 'Y' ]] || { echo 'Aborted.'; return 1; }
        fi
        return 0
    fi

    # gitleaks: prefer the newer `git --staged` subcommand, fall back to
    # the older `protect --staged` if present. Reads .gitleaks.toml and
    # .gitleaksignore from the repo root automatically.
    # `-v` prints the finding details (file, line, rule ID, fingerprint)
    # that the refusal message and the .gitleaksignore workflow both
    # reference. Without it, gitleaks prints only a count to stderr.
    local -a gl_cmd
    if gitleaks git --help > /dev/null 2>&1; then
        gl_cmd=(gitleaks git --staged --no-banner -v)
    elif gitleaks protect --help > /dev/null 2>&1; then
        gl_cmd=(gitleaks protect --staged --no-banner -v)
    else
        echo 'gitleaks present but neither "git" nor "protect" subcommand works.' >&2
        echo 'Check gitleaks version; aborting.' >&2
        return 1
    fi

    echo 'Scanning staged changes for secrets (gitleaks)...'
    if "${gl_cmd[@]}"; then
        return 0
    fi

    # Findings. Refuse by default.
    echo ''
    echo '==============================================================='
    echo 'SECRET SCAN: gitleaks flagged potential credentials above.'
    echo '==============================================================='
    echo 'Options:'
    echo '  1) Unstage and fix (preferred):'
    echo '       git reset HEAD -- <file>'
    echo '       edit out the secret; if it was real, rotate it'
    echo '       re-run zzgit'
    echo ''
    echo '  2) Confirmed false positive:'
    echo '       add the fingerprint reported by gitleaks to .gitleaksignore'
    echo '       (or a rule exception to .gitleaks.toml), commit that file,'
    echo '       then re-run zzgit'
    echo ''
    echo '  3) Audited override (last resort):'
    echo '       export ZZGIT_ALLOW_SECRET_OVERRIDE=1   # this shell only'
    echo '       re-run zzgit; a reason is required and will be appended to'
    echo '       $(git rev-parse --git-dir)/zzgit-overrides.log'
    echo '==============================================================='

    if [[ "$ZZGIT_ALLOW_SECRET_OVERRIDE" != '1' ]]; then
        echo 'Aborted. Index left unchanged.' >&2
        return 1
    fi

    echo ''
    echo 'Override path enabled. A reason is required and will be logged.'
    echo -n 'Reason (>= 10 chars, describing why this commit is safe): '
    local reason
    read -r reason
    if (( ${#reason} < 10 )); then
        echo 'Reason too short. Aborted.' >&2
        return 1
    fi

    local logfile
    logfile="$(git rev-parse --git-dir)/zzgit-overrides.log"
    {
        echo '---'
        echo "timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "user: ${USER:-unknown}"
        echo "branch: $(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD)"
        echo 'staged_files:'
        git diff --cached --name-only | sed 's/^/  - /'
        echo "reason: $reason"
    } >> "$logfile"
    echo "Override logged to $logfile"
    return 0
}

# ----------------------------------------------------------------------------
# Companion: full-history scan
# ----------------------------------------------------------------------------

zzgit-scan-history() {
    emulate -L zsh

    case "$1" in
        -h|--help) _zzgit_scan_history_help; return 0 ;;
        '')        ;;
        *)         echo "zzgit-scan-history: unknown argument: $1" >&2
                   echo "Try 'zzgit-scan-history -h' for usage." >&2
                   return 2 ;;
    esac

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo 'Not a git repository.' >&2
        return 1
    fi
    local scanner="${ZZGIT_SECRET_SCANNER:-gitleaks}"
    if ! command -v "$scanner" > /dev/null 2>&1; then
        echo "$scanner not installed. Try: brew install $scanner" >&2
        return 1
    fi
    echo "Scanning full git history with $scanner..."
    if gitleaks git --help > /dev/null 2>&1; then
        gitleaks git --no-banner
    else
        gitleaks detect --no-banner
    fi
}
