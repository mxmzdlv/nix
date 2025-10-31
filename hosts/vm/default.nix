# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  # 24.05+ renamed hardware.opengl → hardware.graphics. Support either.
  hasGraphics = lib.hasAttr "graphics" config.hardware;
in
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.maxim = {
    isNormalUser = true;
    description = "maxim";
    extraGroups = [ "networkmanager" "wheel" "seat" ];
    shell = pkgs.fish;
    packages = with pkgs; [];
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "maxim";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  ############################################
  # VMware guest + graphics
  ############################################
  virtualisation.vmware.guest.enable = true;     # open-vm-tools, udev rules, etc.
  services.xserver.videoDrivers = [ "vmware" ];  # loads vmwgfx (DRM/KMS) for Wayland

  # GL stack (pick the right option based on your NixOS release)
  hardware.graphics = lib.mkIf hasGraphics {
    enable = true;
    enable32Bit = true;
  };
  hardware.opengl = lib.mkIf (!hasGraphics) {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  ############################################
  # Hyprland (wlroots Wayland compositor)
  ############################################
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;   # X apps under Wayland
  };

  # Optional: log into Hyprland via a display manager (SDDM/Wayland)
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "hyprland";

  ############################################
  # Portals, audio, auth prompts
  ############################################
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  security.polkit.enable = true;

  ############################################
  # Helpful packages
  ############################################
  environment.systemPackages = with pkgs; [
    waybar
    hyprpaper
    hyprlock
    rofi-wayland
    wl-clipboard
    grim
    slurp
    foot
    hypridle
    ghostty
    zed-editor
    mesa-demos
    wofi
  ];

  ############################################
  # VMware + wlroots quirks (safe to keep)
  ############################################
  environment.variables = {
    # Fixes invisible/blinky cursor with vmwgfx in some VMware versions
    WLR_NO_HARDWARE_CURSORS = "1";

    # If 3D accel isn't actually available, allow llvmpipe rather than hard-failing
    WLR_RENDERER_ALLOW_SOFTWARE = "1";

    # Use systemd-logind for seat management (no separate seatd service needed on NixOS)
    LIBSEAT_BACKEND = "logind";

    XDG_SESSION_TYPE = "wayland";
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
