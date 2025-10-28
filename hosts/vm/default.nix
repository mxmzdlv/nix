{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vm";
  time.timeZone = "Pacific/Auckland";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.maxim = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  services.openssh.enable = true;
  programs.zsh.enable = true;
  programs.git.enable = true;

  # Handy for VM use
  services.qemuGuest.enable = true;

  system.stateVersion = "24.05";
}
