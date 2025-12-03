{ pkgs, ... }:

{
  # Basic host identity
  networking.hostName = "mac";
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow proprietary tools (needed for some user packages)
  nixpkgs.config.allowUnfree = true;

  # Primary user; home-manager extends this
  users.users.maxim = {
    home = "/Users/maxim";
    shell = pkgs.fish;
  };

  # Required by nix-darwin; update only after reviewing release notes
  system.stateVersion = 6;
}
