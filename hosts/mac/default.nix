{ pkgs, ... }:

{
  # Shared settings for both Macs; flake.nix supplies each hostname.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow proprietary tools (needed for some user packages)
  nixpkgs.config.allowUnfree = true;

  # Tell nix-darwin which user owns per-user options (e.g. homebrew)
  system.primaryUser = "maxim";

  # Primary user; home-manager extends this
  users.users.maxim = {
    home = "/Users/maxim";
    shell = pkgs.fish;
  };

  # Use Determinate-managed Nix instead of nix-darwin's built-in management
  nix.enable = false;

  # Disable Spotlight indexing on the startup disk's system and data volumes.
  system.activationScripts.postActivation.text = ''
    /usr/bin/mdutil -i off / /System/Volumes/Data
  '';

  # Required by nix-darwin; update only after reviewing release notes
  system.stateVersion = 6;
}
