{ pkgs, ... }:

{
  # Basic host identity
  networking.hostName = "mac";
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

  # Required by nix-darwin; update only after reviewing release notes
  system.stateVersion = 6;
}
