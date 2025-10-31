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

  programs.chromium = {
    enable = true;
    package = if pkgs ? google-chrome then pkgs.google-chrome else pkgs.chromium;
  };

  home.packages = [ pkgs.zed-editor ];

  # Shared application configuration synced into XDG config directory
  xdg.configFile = {
    "ghostty/config".text = builtins.readFile ./ghostty;
    "zed/settings.json".source = ./zed.json;
  };

}
