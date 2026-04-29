{
  description = "One flake to rule mac (nix-darwin), NixOS VM, NixOS PC.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, home-manager, nix-homebrew, ... }:
  let
    # Adjust these if your arch differs:
    macSystem = "aarch64-darwin";
    linuxSystem = "aarch64-linux";

    mkHMUser = username: { pkgs, ... }: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";
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

    darwinConfigurations = {
      mac = darwin.lib.darwinSystem {
        system = macSystem;
        modules = sharedModules ++ [
          nix-homebrew.darwinModules.nix-homebrew
          ./hosts/mac
          home-manager.darwinModules.home-manager
          (mkHMUser "maxim")
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              autoMigrate = true;
              user = "maxim";
            };


            homebrew = {
              enable = true;

              taps = [
                "oven-sh/bun"
              ];

              brews = [
                "oven-sh/bun/bun"
                "dune"
                "sqlite"
              ];

              casks = [
                "bitwarden"
                "ghostty"
                "localsend"
                "mpv"
                "ollama"
                "visual-studio-code"
                "zed"
                "codex"
                "claude-code"
              ];
            };
          }
        ];
      };
    };
  };
}
