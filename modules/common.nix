{ pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # nix.settings.auto-optimise-store = true;
  # nix.gc = {
  #   automatic = true;
  #   dates = "weekly";
  #   options = "--delete-older-than 14d";
  # };

  # Cross-platform packages (keep it conservative here)
  environment.systemPackages = with pkgs; [
    git
    xh
    curl
    fastfetch
    lazygit
    btop
    eza
    ripgrep
    fd
    jq
    unzip
    bat
    zoxide
  ];

  programs.zsh.enable = true;
  programs.fish.enable = true;
}
