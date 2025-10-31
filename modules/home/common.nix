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

  # Shared application configuration synced into XDG config directory
  xdg.configFile = {
    "ghostty/config".text =
      builtins.readFile ./ghostty + "\n" + builtins.readFile ./ghostty-keybinds;
    "zed/settings.json".source = ./zed.json;
  };

}
