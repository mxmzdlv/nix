# modules/home/common.nix
{ config, lib, pkgs, isWSL ? false, inputs ? {}, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux  = pkgs.stdenv.isLinux;
  notesGitWatch = pkgs.writeShellScript "notes-git-watch" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    export PATH="${lib.makeBinPath [ pkgs.git pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnutar pkgs.gawk pkgs.bash pkgs.gnused ]}:$PATH"

    REMOTE_URL="git@github.com:mxmzdlv/notes.git"
    NOTES_DIR="$HOME/notes"
    # Optional overrides for the local LLM binary/model to summarize diffs (defaults to Ollama).
    NOTES_LLM_BIN="''${NOTES_LLM_BIN:-ollama}"
    NOTES_LLM_MODEL="''${NOTES_LLM_MODEL:-gemma3:4b}"
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
      git fetch origin >/dev/null 2>&1 || return
      if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        git pull --rebase --autostash origin "$branch" || true
      fi
    }

    push_remote() {
      local branch="$(current_branch)"
      git push -u origin "$branch" || true
    }

    generate_commit_message() {
      local diff msg
      diff=$(git diff --cached)
      if [ -z "$diff" ]; then
        echo "Auto-save $(date -Iseconds)"
        return
      fi

      if command -v "$NOTES_LLM_BIN" >/dev/null 2>&1; then
        echo "notes-git-watch: LLM command '$NOTES_LLM_BIN' run \"$NOTES_LLM_MODEL\"" >&2
        msg=$("$NOTES_LLM_BIN" run "$NOTES_LLM_MODEL" "Summarize the git diff into a short imperative commit message (max 12 words). Only output the commit message.\n\n$diff" 2>/dev/null || true)
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
      sleep 10
    done
  '';
in
{
  home.stateVersion = "25.11";
  home.sessionVariables = {
    LANG = "en_US.UTF-8";
  } // (if isDarwin then {} else {});

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
}
