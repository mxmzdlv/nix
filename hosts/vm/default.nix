# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Pacific/Auckland";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_NZ.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_NZ.UTF-8";
    LC_IDENTIFICATION = "en_NZ.UTF-8";
    LC_MEASUREMENT = "en_NZ.UTF-8";
    LC_MONETARY = "en_NZ.UTF-8";
    LC_NAME = "en_NZ.UTF-8";
    LC_NUMERIC = "en_NZ.UTF-8";
    LC_PAPER = "en_NZ.UTF-8";
    LC_TELEPHONE = "en_NZ.UTF-8";
    LC_TIME = "en_NZ.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "nz";
    variant = "";
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
    ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.maxim = {
    isNormalUser = true;
    description = "maxim";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [];
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "maxim";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    gnome-tweaks
    gnome-themes-extra
    gnome-user-share
    gnomeExtensions.appindicator
    mesa-demos
    zed-editor
    ghostty
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "maxim";
  };
  services.desktopManager.gnome.enable = true;

  services.desktopManager.gnome.extraGSettingsOverridePackages = [ pkgs.mutter ];
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
    [org/gnome/desktop/interface]
    scaling-factor=1.5
  '';

  virtualisation.vmware.guest.enable = true;

  programs.dconf.enable = true;


  services.xremap = {
    enable = true;
    serviceMode = "user";   # user session service
    withGnome = true;       # installs/uses the GNOME helper extension (needed for per-app filters)

    config = {
      keymap = [
        {
          name = "Cmd→Ctrl (except Ghostty)";
          # Ghostty’s Wayland app-id/class:
          #   com.mitchellh.ghostty   (and sometimes just "Ghostty")
          application = { not = [ "com.mitchellh.ghostty" "Ghostty" ]; };
          remap = {
            "Super-c" = "C-c";  # Cmd+C → Ctrl+C
            "Super-v" = "C-v";  # Cmd+V → Ctrl+V
            "Super-a" = "C-a";  # Cmd+A → Ctrl+A
            "Super-n" = "C-n";  # Cmd+N → Ctrl+N
            "Super-q" = "C-q";  # Cmd+Q → Ctrl+Q
            "Super-x" = "C-x";  # Cmd+X → Ctrl+X
          };
        }
      ];
    };
  };


}
