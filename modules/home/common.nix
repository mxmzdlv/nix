# modules/home/common.nix
{ config, lib, pkgs, isWSL ? false, inputs ? {}, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux  = pkgs.stdenv.isLinux;
in
{
  home.sessionVariables = {
    LANG = "en_US.UTF-8";
  } // (if isDarwin then {} else {});
}
