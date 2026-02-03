# modules/home/common.nix
{ config, lib, pkgs, isWSL ? false, inputs ? {}, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux  = pkgs.stdenv.isLinux;
  # Shared git aliases used across shells
  gitAliases = {
    g = "git";
    ga = "git add";
    gb = "git branch";
    gcb = "git checkout -b";
    gcl = "git clone";
    gco = "git checkout";
    gd = "git diff";
    gf = "git fetch";
    gl = "git log --oneline --graph --decorate";
    gm = "git merge";
    gp = "git push";
    gpl = "git pull";
    gr = "git rebase";
    gs = "git status";
    lz = "lazygit";
  };
  fishGitFunctions = {
    gc = ''
      if test (count $argv) -eq 0
        echo "usage: gc \"message\"" >&2
        return 1
      end

      set msg (string join " " $argv)
      git commit -m "$msg"
    '';
    gac = ''
      set msg "-"
      if test (count $argv) -gt 0
        set msg (string join " " $argv)
      end

      git add -A; and git commit -m "$msg"
    '';
    gas = ''
      git add -A; or return $status

      set diff (git diff --cached --ignore-submodules -- | string collect)
      if test -z "$diff"
        echo "gas: nothing to commit" >&2
        return 0
      end

      set llm_bin (string trim -- (set -q GIT_LLM_BIN; and echo $GIT_LLM_BIN; or echo "ollama"))
      set llm_model (string trim -- (set -q GIT_LLM_MODEL; and echo $GIT_LLM_MODEL; or echo "gemma3:12b"))
      set msg ""

      if type -q $llm_bin
        set request "Summarize the git diff into a descriptive commit message explaining what changed. Only output the commit message.\n\n$diff"
        set msg_raw ($llm_bin run $llm_model $request 2>/dev/null)
        set msg (printf "%s\n" $msg_raw | string trim | string match -r ".+" | head -n 1)
      else
        echo "gas: LLM command not found: $llm_bin" >&2
      end

      if test -z "$msg"
        set msg (printf "Auto-commit %s" (date -u +"%Y-%m-%dT%H:%M:%SZ"))
      end

      git commit -m "$msg"
    '';
    copy = ''
      function copy
          if test (count $argv) -gt 0
              set dir $argv[1]
          else
              set dir .
          end

          find $dir \
              \( -name .git -o -name _build -o -name .zig_cache -o -name zig-out \) -prune -o \
              -type f \
              ! -iname '*.db*' \
              ! -iname '*.parquet*' \
              ! -name '.*' \
              -print0 \
              | xargs -0 awk '
                  FNR == 1 { printf("==> %s <==\n", FILENAME) }
                  { print }
              ' \
              | pbcopy
      end
    '';
  };
  notesGitWatch = pkgs.writeShellScript "notes-git-watch" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Include Homebrew/default macOS bins so launchd can find Ollama when run headless.
    export PATH="${lib.makeBinPath [ pkgs.git pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnutar pkgs.gawk pkgs.bash pkgs.gnused ]}:/usr/local/bin:/opt/homebrew/bin:$PATH"
    # Fail fast on auth prompts so the launchd job never hangs silently.
    export GIT_SSH_COMMAND="''${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=10}"
    export GIT_TERMINAL_PROMPT=0

    REMOTE_URL="git@github.com:mxmzdlv/notes.git"
    NOTES_DIR="$HOME/notes"
    # Optional overrides for the local LLM binary/model to summarize diffs (defaults to Ollama).
    NOTES_LLM_BIN="''${NOTES_LLM_BIN:-ollama}"
    NOTES_LLM_MODEL="''${NOTES_LLM_MODEL:-gemma3:12b}"
    REMOTE_HEALTH_THRESHOLD_SECONDS=300
    last_remote_sync=$(date +%s)
    last_remote_alert=0
    mkdir -p "$NOTES_DIR"
    cd "$NOTES_DIR"

    current_branch() {
      git symbolic-ref --short HEAD 2>/dev/null || echo master
    }

    ensure_repo() {
      if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git init
      fi
      git symbolic-ref HEAD refs/heads/master 2>/dev/null || true
      if git remote get-url origin >/dev/null 2>&1; then
        git remote set-url origin "$REMOTE_URL"
      else
        git remote add origin "$REMOTE_URL"
      fi
    }

    pull_remote() {
      local branch="$(current_branch)"
      if ! git fetch origin >/dev/null 2>&1; then
        echo "notes-git-watch: git fetch origin failed; will retry" >&2
        return
      fi
      last_remote_sync=$(date +%s)
      if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        if ! git pull --rebase --autostash origin "$branch"; then
          echo "notes-git-watch: git pull --rebase failed for $branch; continuing" >&2
        else
          last_remote_sync=$(date +%s)
        fi
      fi
    }

    push_remote() {
      local branch="$(current_branch)"
      if ! git push -u origin "$branch"; then
        echo "notes-git-watch: git push failed for $branch; leaving commits local" >&2
      else
        last_remote_sync=$(date +%s)
      fi
    }

    generate_commit_message() {
      local diff msg
      diff=$(git diff --cached -- . ":(exclude)assets/*")
      if [ -z "$diff" ]; then
        echo "notes-git-watch: no staged diff after filtering assets; using timestamp" >&2
        echo "Auto-save $(date -Iseconds)"
        return
      fi

      if command -v "$NOTES_LLM_BIN" >/dev/null 2>&1; then
        request=$(printf "Summarize the git diff into a descriptive commit message explaining what changed. Only talk about changes (diff plus and minus signs). This is a log of todo, notes, and other tasks. So your message should reflect what has changed in the notes. Only output the commit message.\n\n%s" "$diff")
        msg=$("$NOTES_LLM_BIN" run "$NOTES_LLM_MODEL" "$request" 2>/dev/null || true)
        llm_status=$?
        msg=$(echo "$msg" | head -n 1 | sed 's/^\\s*//;s/\\s*$//')
        echo "notes-git-watch: LLM exit=$llm_status msg_len=$(printf \"%s\" \"$msg\" | wc -c)" >&2
        if [ -n "$msg" ]; then
          echo "$msg"
          return
        fi
      else
        echo "notes-git-watch: LLM command not found: $NOTES_LLM_BIN (PATH=$PATH)" >&2
      fi

      echo "Auto-save $(date -Iseconds)"
    }

    notify_stale_sync() {
      local now stale_seconds
      now=$(date +%s)
      stale_seconds=$((now - last_remote_sync))
      if [ "$stale_seconds" -lt "$REMOTE_HEALTH_THRESHOLD_SECONDS" ]; then
        return
      fi
      if [ "$last_remote_alert" -ne 0 ] && [ $((now - last_remote_alert)) -lt "$REMOTE_HEALTH_THRESHOLD_SECONDS" ]; then
        return
      fi
      echo "notes-git-watch: no successful remote sync for ''${stale_seconds}s (threshold ''${REMOTE_HEALTH_THRESHOLD_SECONDS}s)" >&2
      if [ "$(uname -s)" = "Darwin" ] && command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"No remote sync for over $((REMOTE_HEALTH_THRESHOLD_SECONDS / 60)) minutes\" with title \"notes-git-watch\"" || true
      fi
      last_remote_alert=$now
    }

    ensure_repo

    pull_timer=0
    while true; do
      ensure_repo
      pull_timer=$((pull_timer + 10))
      if [ "$pull_timer" -ge 30 ]; then
        pull_remote
        pull_timer=0
      fi
      git add -A
      if ! git diff --cached --quiet --ignore-submodules --; then
        commit_message=$(generate_commit_message)
        git commit -m "$commit_message" || true
        push_remote
      fi
      notify_stale_sync
      sleep 10
    done
  '';
in
{
  home.stateVersion = "25.11";
  home.sessionVariables = {
    LANG = "en_US.UTF-8";
  } // (if isDarwin then {} else {});

  home.sessionPath = lib.optionals isDarwin [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "${config.home.homeDirectory}/go/bin"
  ];


  programs.chromium = let
    hostSystem = pkgs.stdenv.hostPlatform.system;
    chromeMetaPlatforms =
      if pkgs ? google-chrome
      then (pkgs.google-chrome.meta.platforms or [])
      else [];
    canUseChrome = lib.elem hostSystem chromeMetaPlatforms;
  in {
    enable = true;
    package = if canUseChrome then pkgs.google-chrome else pkgs.chromium;
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
    ];
  };

  home.packages = lib.optionals (!isDarwin) [
    pkgs.bitwarden-desktop
    pkgs.localsend
    pkgs.mpv
    pkgs.zed-editor
    pkgs.vscode
    pkgs.ghostty
  ];

  dconf.settings = {
    # App switching with Super+1..9 (GNOME Shell)
    "org/gnome/shell/keybindings" = {
      switch-to-application-1 = [];
      switch-to-application-2 = [];
      switch-to-application-3 = [];
      switch-to-application-4 = [];
      switch-to-application-5 = [];
      switch-to-application-6 = [];
      switch-to-application-7 = [];
      switch-to-application-8 = [];
      switch-to-application-9 = [];
      # Disable overview on bare Super press so it can be remapped by the tiling WM
      toggle-overview = [ "<Super>space" ];

    };
  };


  # Shared application configuration synced into XDG config directory
  xdg.configFile =
    lib.optionalAttrs isLinux {
      "ghostty/config".text =
        builtins.readFile ./ghostty + "\n" + builtins.readFile ./ghostty-keybinds;
    }
    // {
      "zed/settings.json".source = ./zed.json;
    };

  # Auto-commit changes in ~/notes every 10 seconds on macOS
  launchd.agents.notes-git-watch = lib.mkIf isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ "${notesGitWatch}" ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/notes-git-watch.err.log";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/notes-git-watch.out.log";
    };
  };

  # Ensure ~/code exists so repos/apps have a consistent location
  home.file."code/.keep".text = "";

  programs.tmux = {
    enable = true;
    clock24 = true;
    mouse = true;
    shortcut = "a";
    terminal = "screen-256color";
    extraConfig = ''
      # Splitting panes with | and -
      bind | split-window -h
      bind - split-window -v

      # Enable window titles
      set -g set-titles on
      set -g set-titles-string "#S: #W"

      # Enable pane titles
      set -g pane-border-status top
      set -g pane-border-format " #P: #T "
    '';
  };

  programs.zsh = {
    enable = true;
    shellAliases = gitAliases;
  };

  programs.fish = {
    enable = true;
    shellAliases = gitAliases;
    functions = fishGitFunctions // {
      n = ''
        zed ~/notes
      '';
      develop = ''
        function develop --wraps='nix develop'
          env ANY_NIX_SHELL_PKGS=(basename (pwd))"#"(git describe --tags --dirty) (type -P nix) develop --command fish
        end
      '';
    };
    interactiveShellInit = ''
      if type -q opam
        eval (opam env --switch=default --shell=fish)
      end
    '';
  };
}
