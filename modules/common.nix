{ pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Cross-platform packages (keep it conservative here)
  environment.systemPackages = with pkgs; [
    git
    gnupg
    curl
    wget
    vim
    htop
    ripgrep
    fd
    jq
    unzip
  ];

  programs.zsh.enable = true;
}
