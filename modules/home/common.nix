{
  config,
  lib,
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  repoDir = "${config.home.homeDirectory}/code/nix";
  outOfStoreConfig = path: config.lib.file.mkOutOfStoreSymlink "${repoDir}/${path}";
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

      if git diff --cached --quiet --ignore-submodules --
        echo "gas: nothing to commit" >&2
        return 0
      end

      set msg (printf "Auto-commit %s" (date -u +"%Y-%m-%dT%H:%M:%SZ"))

      git commit -m "$msg"
    '';
    copy = ''
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
    '';
  };
  notesGitWatch = pkgs.writeShellScript "notes-git-watch" (
    ''
      export PATH="${
        lib.makeBinPath [
          pkgs.git
          pkgs.coreutils
        ]
      }:/usr/bin:/bin:$PATH"
    ''
    + builtins.readFile ./notes-git-watch.sh
  );

in
{
  home.stateVersion = "25.11";
  home.sessionVariables = {
    LANG = "en_US.UTF-8";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/go/bin"
  ]
  ++ lib.optionals isDarwin [
    "/opt/homebrew/opt/postgresql@18/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  # macOS Chrome is installed by Homebrew with the other desktop apps.
  programs.chromium = lib.mkIf isLinux {
    enable = true;
    package = pkgs.chromium;
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
    ];
  };

  home.packages = lib.optionals isLinux [
    pkgs.bitwarden-desktop
    pkgs.zed-editor
    pkgs.vscode
    pkgs.ghostty
  ];

  dconf.settings = lib.mkIf isLinux {
    # App switching with Super+1..9 (GNOME Shell)
    "org/gnome/shell/keybindings" = {
      switch-to-application-1 = [ ];
      switch-to-application-2 = [ ];
      switch-to-application-3 = [ ];
      switch-to-application-4 = [ ];
      switch-to-application-5 = [ ];
      switch-to-application-6 = [ ];
      switch-to-application-7 = [ ];
      switch-to-application-8 = [ ];
      switch-to-application-9 = [ ];
      # Disable overview on bare Super press so it can be remapped by the tiling WM
      toggle-overview = [ "<Super>space" ];
    };
  };

  # Shared application configuration synced into XDG config directory
  xdg.configFile = {
    "ghostty/config".text =
      if isDarwin then
        ''
          theme = niji
          macos-titlebar-style = tabs
          command = ${pkgs.fish}/bin/fish
          keybind = shift+enter=text:\x1b\r
          shell-integration = fish
          notify-on-command-finish = unfocused
        ''
      else
        builtins.readFile ./ghostty + "\n" + builtins.readFile ./ghostty-keybinds;
    # Link the macOS Zed settings to this checkout so edits apply without rebuilding.
    "zed/settings.json".source =
      if isDarwin then outOfStoreConfig "modules/home/zed.json" else ./zed.json;
  };

  # Sync an existing, configured ~/notes clone every 10 seconds on macOS
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
      claude-b = ''
        CLAUDE_CONFIG_DIR=~/.claude-b claude $argv
      '';
      codex-b = ''
        CODEX_HOME=~/.codex-b codex $argv
      '';
      develop = {
        wraps = "nix develop";
        body = ''
          env ANY_NIX_SHELL_PKGS=(basename (pwd))"#"(git describe --tags --dirty) (type -P nix) develop $argv --command fish
        '';
      };
    };
    interactiveShellInit = ''
      if type -q opam
        eval (opam env --switch=default --shell=fish)
      end
    '';
  };
}
