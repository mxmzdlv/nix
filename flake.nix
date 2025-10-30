{
  description = "One flake to rule mac (nix-darwin), NixOS VM, NixOS PC.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-untable";
    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, home-manager, ... }:
  let
    # Adjust these if your arch differs:
    macSystem = "aarch64-darwin";
    linuxSystem = "aarch64-linux";

    mkHMUser = username: { pkgs, ... }: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} = import ./modules/home/common.nix;
    };

    # Shared modules across all hosts (only OS-agnostic options here)
    sharedModules = [
      ./modules/common.nix
    ];
  in {
    nixosConfigurations = {
      # pc = nixpkgs.lib.nixosSystem {
      #   system = linuxSystem;
      #   modules = sharedModules ++ [
      #     ./hosts/pc/hardware-configuration.nix
      #     ./hosts/pc
      #     home-manager.nixosModules.home-manager
      #     (mkHMUser "maxim")
      #   ];
      # };

      vm = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        modules = sharedModules ++ [
          ./hosts/vm/hardware-configuration.nix
          ./hosts/vm
          home-manager.nixosModules.home-manager
          (mkHMUser "maxim")
        ];
      };
    };

    # darwinConfigurations = {
    #   mac = darwin.lib.darwinSystem {
    #     system = macSystem;
    #     modules = sharedModules ++ [
    #       ./hosts/mac
    #       home-manager.darwinModules.home-manager
    #       (mkHMUser "maxim")
    #     ];
    #   };
    # };
  };
}
