# modules/home/common.nix
{ config, lib, pkgs, isWSL ? false, inputs ? {}, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux  = pkgs.stdenv.isLinux;
  notesGitWatch = pkgs.writeShellScript "notes-git-watch" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    export PATH="${lib.makeBinPath [ pkgs.git pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnutar pkgs.gawk pkgs.bash ]}:$PATH"

    NOTES_DIR="$HOME/notes"
    mkdir -p "$NOTES_DIR"
    cd "$NOTES_DIR"

    ensure_repo() {
      if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git init
      fi
    }

    ensure_repo

    while true; do
      ensure_repo
      git add -A
      if ! git diff --cached --quiet --ignore-submodules --; then
        git commit -m "Auto-save $(date -Iseconds)" || true
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
  xdg.configFile = {
    "ghostty/config".text =
      builtins.readFile ./ghostty + "\n" + builtins.readFile ./ghostty-keybinds;
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
