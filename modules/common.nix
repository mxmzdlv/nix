{ pkgs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Command-line tools available on every host.
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
    go
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
  ];

  programs.zsh.enable = true;
  programs.fish.enable = true;
}
