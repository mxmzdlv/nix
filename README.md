# Mac setup

Follow these steps on the new **Neo Mac**, in order. This configuration is for
Apple Silicon Macs and expects the macOS account **`maxim`** with home directory
**`/Users/maxim`**.

## 1. Check your macOS account

Open **Terminal** and run:

```sh
whoami
echo "$HOME"
uname -m
```

The results should be `maxim`, `/Users/maxim`, and `arm64`. If the account differs,
use a macOS account named `maxim` before continuing; the paths in this repo depend
on it.

## 2. Install Apple's command-line tools

```sh
xcode-select --install
```

Follow the popup and wait for installation to finish. If Terminal says the tools
are already installed, continue.

## 3. Install Determinate Nix

1. Open the [official Determinate download page](https://determinate.systems/install/).
2. Click **Install using our macOS package installer**.
3. Open the downloaded **Determinate.pkg** and follow the installer. Enter your
   Mac password when asked.
4. Quit Terminal and reopen it.
5. Check the installation:

   ```sh
   nix --version
   ```

You should see a version mentioning **Determinate Nix**. If you see
`command not found`, make sure the installer finished and reopen Terminal before
continuing. The repo already sets `nix.enable = false` so Determinate manages Nix.

## 4. Set up Git and GitHub access

Replace the example name and email with your Git commit identity:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Create an SSH key for this Mac:

```sh
ssh-keygen -t ed25519 -C "you@example.com"
```

Accept the default file location and choose a passphrase. If a key already exists,
do not overwrite it; use your existing key and adjust the paths below if needed.

Save the passphrase in the macOS Keychain:

```sh
/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Open the SSH configuration:

```sh
nano ~/.ssh/config
```

Add this block (or update the existing `Host github.com` block):

```sshconfig
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
```

Save with **Control-O**, **Enter**, then exit with **Control-X**.
These settings let SSH retrieve the passphrase for background notes sync.
See [GitHub's macOS SSH instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=mac).

Copy the public key:

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

Open [GitHub SSH keys](https://github.com/settings/ssh/new), name the key **Neo**,
choose **Authentication Key**, paste it, and save. Use the GitHub account with
access to these repositories.

Test access:

```sh
ssh -T git@github.com
```

On the first connection, compare the displayed fingerprint with
[GitHub's fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)
before accepting. You should see `Hi USERNAME! You've successfully authenticated`.
GitHub exits with status 1 even on success; that is expected.

## 5. Clone the repositories

Keep this checkout at **`~/code/nix`**: Zed's settings link directly to it.

```sh
mkdir -p ~/code
git clone git@github.com:mxmzdlv/nix.git ~/code/nix
```

For automatic notes sync, also clone your notes before applying the configuration:

```sh
git clone git@github.com:mxmzdlv/notes.git ~/notes
```

Skip the notes clone if you do not want notes sync yet. The service waits until
`~/notes` is configured. If either directory already contains a checkout, use that
checkout instead of cloning over it.

## 6. Build and apply Neo's configuration

First, build without changing the active configuration:

```sh
cd ~/code/nix
make build HOST=neo
```

After the build succeeds, apply it:

```sh
make switch HOST=neo
```

Enter your Mac password when asked; Terminal does not show characters as you type.
The first run downloads packages and installs Homebrew and the configured apps,
so allow it to finish. If either command fails, resolve the reported error and
rerun that command before continuing.

The Mac setup manages only native ARM Homebrew at `/opt/homebrew`. Intel
Homebrew under `/usr/local` is not needed. Some apps may still prompt to install
Rosetta for their own Intel components.

On the original Mac, use `HOST=mac` in both commands instead. Both Macs share
packages and home configuration; Neo gets its own hostname and `neo.local` name.

## 7. Check the setup

Quit and reopen Terminal, then run:

```sh
scutil --get LocalHostName
nix --version
psql --version
go version
rustc --version
cargo --version
```

The hostname should be `neo`, and Nix should print its version. Open your installed
apps and sign in where needed. Git identity, SSH keys, and app sign-ins are not
restored by this repo.

Chrome, Tailscale, and the other Mac apps are installed through Homebrew. After
activation:

- Open **Tailscale**, complete its macOS permission prompts, and sign in.
- Open **OrbStack** to finish its setup.
- Open **Chrome**, sign in if you use browser sync, and install the **Bitwarden**
  extension from the Chrome Web Store. The Mac configuration no longer manages
  Chrome extensions through Home Manager.

Ghostty gets this Mac's theme, tab titlebar, Shift-Enter binding, and command
notifications. It uses the Fish shell installed by Nix. Home Manager backs up an
existing unmanaged configuration with a `.backup` suffix when first replacing it.

Go and Rust (including Cargo, rustfmt, Clippy, and rust-analyzer) are installed
through Nix on every host. Their versions follow `flake.lock`.

### Spotlight indexing

This repo leaves Spotlight indexing at the macOS default (on). An earlier
version disabled it from a `postActivation` script on every `make switch`; that
block is gone, but removing it does not re-index anything by itself. If a Mac
still has indexing off from that era, turn it back on once:

```sh
sudo mdutil -i on / /System/Volumes/Data
```

Check the status at any time:

```sh
mdutil -s / /System/Volumes/Data
```

Both volumes should report indexing enabled. The first index after re-enabling
takes a while and is CPU- and disk-heavy. If Spotlight results stay incomplete,
force a rebuild from scratch with `sudo mdutil -E /`. External disks are not
changed either way.

### PostgreSQL

The repo installs [Homebrew PostgreSQL 18](https://formulae.brew.sh/formula/postgresql@18),
the current stable major version, and adds its commands to your shell path.
`psql --version` should report `18.x` after reopening Terminal.

To run a local database server on the new Neo Mac:

```sh
brew services start postgresql@18
psql postgres
```

Type `\q` to exit `psql`. Starting the service also enables it at login.
You can use `psql` with remote databases without starting a local server.

On the original Mac, the existing PostgreSQL 14 databases need a separate migration
to use the new server. Applying this repo does not migrate them or start PostgreSQL 18.

## Later changes

To pull and apply the latest repo configuration:

```sh
cd ~/code/nix
git pull --ff-only
make build
make switch
```

Run each command only after the previous one succeeds. After the first activation,
the Makefile detects Neo's Bonjour name, so plain `make switch` keeps its identity.

`make build` builds without activating; `make switch` applies the selected host.
Both use the nix-darwin runner pinned by `flake.lock`. `make check` checks the
flake and explicitly evaluates both Macs and the NixOS VM. `make fmt` formats the
Nix files using the pinned formatter and reports failures. `make update` is the
explicit command to update dependencies.

To update the Nix packages, including Go and Rust, run `make update`, then
`make check`, `make build`, and `make switch`. Review and commit the changed
`flake.lock` so other machines use the same versions.

The Homebrew runtime itself is pinned by `nix-homebrew` in `flake.lock`.
`brew update` refreshes package metadata and taps; it cannot update that runtime.
Use `make update`, then rebuild and switch, to update Homebrew itself. Updating
the inputs together also supplies the Ruby version required by nix-homebrew.

Homebrew packages are separate from `flake.lock`. `make switch` installs missing
packages but does not upgrade existing ones. To upgrade a particular package:

```sh
brew update
brew upgrade postgresql@18
```

For a desktop app, use `brew upgrade --cask APP`, replacing `APP` with its cask name
from `flake.nix`. Some apps also update themselves.

Removing an app from `flake.nix` prevents installation on a new Mac; it does not
uninstall an existing copy. LocalSend and mpv are no longer declared on any host.
Existing Mac copies can be removed separately when no longer wanted.

### Applying to an existing Mac

Homebrew may refuse to install an app already present in `/Applications` but not
managed by Homebrew. For an identical existing app, Homebrew supports adoption:

```sh
brew install --cask --adopt google-chrome
```

If adoption reports a different version, quit the app and move its existing
`.app` bundle to a backup folder outside `/Applications`, then rerun `make switch`.
Keep the app's data in `~/Library`. See [Homebrew's install options](https://docs.brew.sh/Manpage#install-options-formulacask-).

Existing Homebrew Go and rustup installations can take precedence over the Nix
toolchains. Check which commands your shell uses:

```sh
command -v go
command -v rustc
command -v cargo
```

On a clean Neo install, these resolve to the Nix toolchains. On the original Mac,
the existing installations are preserved; choosing to migrate them is separate
from installing this configuration.

### If first activation fails

Always work from `~/code/nix`. `make switch HOST=neo` uses `sudo -H` so root gets
its own home directory without changing the working directory. Do not use
`sudo -i` with a relative flake path: it changes to `/var/root`.

If nix-darwin refuses to overwrite `/etc/zshenv`, inspect it first:

```sh
cat /etc/zshenv
```

If it only contains the old Nix installer setup, preserve it and retry:

```sh
sudo mv -n /etc/zshenv /etc/zshenv.before-nix-darwin
make switch HOST=neo
```

If it contains other custom settings, preserve those settings in the configuration
before continuing. Do not overwrite an existing backup.

Errors such as `Unexpected method ... called on Cask` or exceptions in
`Utils::Bottles.load_tab` can mean the pinned Homebrew runtime is too old for
current package metadata. Update the flake inputs, build, and retry activation;
`brew update` alone does not fix that mismatch. `make build` validates the Nix
configuration, but Homebrew installs happen only during `make switch`.

If an earlier attempt created an Intel prefix and it was later deleted, use this
configuration with `enableRosetta = false`; activation will stop touching that
prefix. Keep `/opt/homebrew` and its installed packages. A partial activation can
be retried with `make switch HOST=neo`.

Until activation finishes and you reopen Terminal, use
`/opt/homebrew/bin/brew --version` to check the native installation directly.

## Notes sync

The macOS service checks `~/notes` every ten seconds. It waits until this is a
repository root with the expected origin, a branch tracking origin, and Git
`user.name` / `user.email` configured. It never initializes a repository, changes
its remote, or switches branches for you.

Until a valid clone, Git identity, and tracking branch are configured, the watcher
waits quietly. Once configured, it starts syncing automatically and reports later
sync failures.

The service commits edits locally even when offline, rebases onto the tracked
remote branch, and retries pushes even when no new files have changed. A rebase
conflict aborts that rebase, preserves the local commits, and prevents the push.
Resolve conflicting changes manually; existing merges/rebases are left alone.

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
