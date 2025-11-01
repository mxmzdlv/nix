# modules/home/common.nix
{ config, lib, pkgs, isWSL ? false, inputs ? {}, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux  = pkgs.stdenv.isLinux;
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
  };

  home.packages = [
    pkgs.zed-editor
  ];

  dconf.settings = {
    "org/gnome/mutter" = {
      overlay-key = "";
    };

    # Tiling with Super+Left/Right (GNOME Mutter)
    "org/gnome/mutter/keybindings" = {
      toggle-tiled-left = [];
      toggle-tiled-right = [];
    };

    # Maximize/unmaximize on Super+Up/Down (GNOME WM)
    "org/gnome/desktop/wm/keybindings" = {
      maximize = [];
      unmaximize = [];
      # keep a non-super alternative for max/restore
      toggle-maximized = ["<Alt>F10"];
      panel-main-menu = [];
    };

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
      toggle-application-view = [ "" ];
    };
  };


  # Shared application configuration synced into XDG config directory
  xdg.configFile = {
    "ghostty/config".text =
      builtins.readFile ./ghostty + "\n" + builtins.readFile ./ghostty-keybinds;
    "zed/settings.json".source = ./zed.json;
  };

}
