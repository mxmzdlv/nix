#!/usr/bin/env bash
set -euo pipefail

# The Nix wrapper supplies Git, coreutils (including timeout), and macOS tools.
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=10}"
export GIT_TERMINAL_PROMPT=0
export GIT_EDITOR=true

NOTES_DIR="${NOTES_DIR:-$HOME/notes}"
NOTES_REMOTE_URL="${NOTES_REMOTE_URL:-git@github.com:mxmzdlv/notes.git}"
last_remote_sync=$(date +%s)
last_remote_alert=0

log() { echo "notes-git-watch: $*" >&2; }

ready() {
  if ! cd "$NOTES_DIR" 2>/dev/null; then
    log "waiting for a clone at $NOTES_DIR"
    return 1
  fi
  local root marker
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  if [ "$root" != "$(pwd -P)" ]; then
    log "notes directory must be the repository root"
    return 1
  fi
  if [ "$(git remote get-url origin 2>/dev/null)" != "$NOTES_REMOTE_URL" ] ||
     [ "$(git remote get-url --push origin 2>/dev/null)" != "$NOTES_REMOTE_URL" ]; then
    log "origin does not match $NOTES_REMOTE_URL; leaving it unchanged"
    return 1
  fi
  if ! git config user.name >/dev/null || ! git config user.email >/dev/null; then
    log "configure git user.name and user.email before enabling sync"
    return 1
  fi
  for marker in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_START; do
    if [ -e "$(git rev-parse --git-path "$marker")" ]; then
      log "Git operation in progress; waiting for manual resolution"
      return 1
    fi
  done
  if [ -n "$(git ls-files --unmerged)" ]; then
    log "unresolved conflicts; waiting for manual resolution"
    return 1
  fi
  branch=$(git symbolic-ref --quiet --short HEAD) || {
    log "detached HEAD; select a branch before syncing"
    return 1
  }
  # Respect the clone's upstream, including a differently named remote branch.
  local remote merge_ref
  remote=$(git config --get "branch.$branch.remote") || return 1
  merge_ref=$(git config --get "branch.$branch.merge") || return 1
  if [ "$remote" != origin ] || [[ "$merge_ref" != refs/heads/* ]]; then
    log "branch must track a branch on origin"
    return 1
  fi
  remote_branch=${merge_ref#refs/heads/}
}

sync_once() {
  ready || return 1
  git add -A || return 1
  if ! git diff --cached --quiet --ignore-submodules --; then
    git commit -m "Auto-save $(date -u +%Y-%m-%dT%H:%M:%SZ)" || return 1
  fi

  # Save locally while offline, then reconcile before every push. Fetch success
  # alone does not mean our local commits reached the other machine.
  timeout --kill-after=2s 45s git fetch --no-tags origin "refs/heads/$remote_branch" || return 1
  if ! git diff --quiet || ! git diff --cached --quiet; then
    log "notes changed during sync; retrying next cycle"
    return 1
  fi
  # Disable user-configured autostash so conflicts cannot strand hidden edits.
  if ! git -c rebase.autoStash=false rebase FETCH_HEAD; then
    if [ -d "$(git rev-parse --git-path rebase-merge)" ] ||
       [ -d "$(git rev-parse --git-path rebase-apply)" ]; then
      git rebase --abort || return 1
    fi
    log "could not reconcile remote changes; local commits preserved, resolve manually"
    return 1
  fi
  # Retry even when no files changed since a failed push. Never force-push.
  timeout --kill-after=2s 45s git push origin "HEAD:refs/heads/$remote_branch" || return 1
  last_remote_sync=$(date +%s)
}

notify_stale_sync() {
  local now
  now=$(date +%s)
  if [ $((now - last_remote_sync)) -ge 300 ] && [ $((now - last_remote_alert)) -ge 300 ]; then
    log "no complete remote sync for over five minutes; check SSH access and Git conflicts"
    if [ "$(uname -s)" = Darwin ] && command -v osascript >/dev/null 2>&1; then
      osascript -e 'display notification "No complete remote sync for over five minutes. Check notes-git-watch logs." with title "notes-git-watch"' || true
    fi
    last_remote_alert=$now
  fi
}

# One cycle is useful for diagnostics and isolated local-repository tests.
if [ "${1:-}" = --once ]; then
  sync_once
else
  while true; do
    sync_once || log "sync incomplete; will retry"
    notify_stale_sync
    sleep 10
  done
fi
