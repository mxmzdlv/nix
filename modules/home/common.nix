# modules/home/common.nix
{ config, lib, pkgs, isWSL ? false, inputs ? {}, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux  = pkgs.stdenv.isLinux;
in
{
  home.stateVersion = "25.05";
  home.sessionVariables = {
    LANG = "en_US.UTF-8";
  } // (if isDarwin then {} else {});

  # Shared Ghostty configuration used on both Darwin and Linux
  programs.ghostty = {
    enable = true;
    settings =
      {
        theme = "niji";
      }
      // lib.optionalAttrs isDarwin {
      };
  };
}
