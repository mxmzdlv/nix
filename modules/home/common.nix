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

  nixpkgs.config.allowUnfree = true;
  chrome = pkgs.google-chrome;

  home.packages = [ pkgs.google-chrome ];

  # Shared Ghostty configuration used on both Darwin and Linux
  xdg.configFile = {
    "ghostty/config".text = builtins.readFile ./ghostty;
  };

}
