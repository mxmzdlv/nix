# Mac setup

Use the `maxim` macOS account. Install Apple's command-line tools (`xcode-select
--install`) and [Determinate Nix](https://docs.determinate.systems/), then open a
new terminal.

Clone into **`~/code/nix`** on every Mac:

```sh
mkdir -p ~/code
git clone https://github.com/mxmzdlv/nix.git ~/code/nix
cd ~/code/nix
make build HOST=neo
make switch HOST=neo
```

Authenticate to GitHub if the clone requires access. Zed's settings are a live
symlink to this checkout, so keep the repository at this location. Use `HOST=mac`
on the original Mac. Both use the `maxim` login and `/Users/maxim`; Neo gets its
own hostname, Bonjour name (`neo.local`), and computer name: `neo`. Packages and
home configuration are shared. After the first activation, the Makefile detects
Neo's Bonjour name, so plain `make switch` keeps its identity.

`make build` builds without activating; `make switch` applies the selected host.
Both use the nix-darwin runner pinned by `flake.lock`. `make check` checks the
flake and explicitly evaluates both Mac configurations. `make fmt` formats the
Nix files using the pinned formatter and reports failures. `make update` is the
explicit command to update dependencies.

## Notes sync

The macOS service checks `~/notes` every ten seconds. It waits until this is a
repository root with the expected origin, a branch tracking origin, and Git
`user.name` / `user.email` configured. It never initializes a repository, changes
its remote, or switches branches for you.

Before the first switch, configure your Git name/email and set up this Mac's SSH
key for GitHub. Verify SSH access interactively with `ssh -T git@github.com`
(GitHub reports successful authentication but exits with status 1). Then clone:

```sh
git clone git@github.com:mxmzdlv/notes.git ~/notes
```

The service commits edits locally even when offline, rebases onto the tracked
remote branch, and retries pushes even when no new files have changed. A rebase
conflict aborts that rebase, preserves the local commits, and prevents the push.
Resolve conflicting changes manually; existing merges/rebases are left alone.
Git identity, SSH keys, and app sign-ins are separate from this configuration.

Notes commits use a timestamp, for example `Auto-save 2026-09-09T04:30:00Z`.
The Fish `gas` helper also makes timestamped commits. Neither needs a model or
external message-generation service.

Logs: `~/Library/Logs/notes-git-watch.{err,out}.log`. A notification appears after
five minutes without a complete remote sync.

Run isolated sync tests with `python3 tests/test_notes_sync.py` (Git, Bash, and GNU
coreutils `timeout` on PATH). These use temporary local repositories only.

## NixOS VM

```sh
sudo nixos-rebuild -L --refresh --no-write-lock-file switch --flake github:mxmzdlv/nix#vm
```
