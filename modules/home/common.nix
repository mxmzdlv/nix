# modules/home/common.nix
{ config, lib, pkgs, isWSL ? false, inputs ? {}, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux  = pkgs.stdenv.isLinux;
in
{
  # Pull in the xremap Home Manager module provided by the flake
  imports = [
    inputs.xremap-flake.homeManagerModules.default
  ];

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

  services.xremap = {
    enable = true;
    serviceMode = "user";   # user session service
    withGnome = true;       # installs/uses the GNOME helper extension (needed for per-app filters)

    config = {
      keymap = [
        {
          name = "Cmd→Ctrl (except Ghostty)";
          # Ghostty’s Wayland app-id/class:
          #   com.mitchellh.ghostty   (and sometimes just "Ghostty")
          application = { not = [ "com.mitchellh.ghostty" "Ghostty" ]; };
          remap = {
            "Super-c" = "C-c";  # Cmd+C → Ctrl+C
            "Super-v" = "C-v";  # Cmd+V → Ctrl+V
            "Super-a" = "C-a";  # Cmd+A → Ctrl+A
            "Super-n" = "C-n";  # Cmd+N → Ctrl+N
            "Super-q" = "C-q";  # Cmd+Q → Ctrl+Q
            "Super-x" = "C-x";  # Cmd+X → Ctrl+X
          };
        }
      ];
    };
  };

  home.packages = [
    pkgs.zed-editor
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

}
