{
  description = "Shared configuration for mac, neo, and the NixOS VM.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      nixpkgs,
      darwin,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      macSystem = "aarch64-darwin";
      linuxSystem = "aarch64-linux";

      mkHMUser =
        username:
        { ... }:
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.${username} = import ./modules/home/common.nix;
        };

      # Shared modules across all hosts (only OS-agnostic options here)
      sharedModules = [
        ./modules/common.nix
      ];
      mkMac =
        hostName:
        darwin.lib.darwinSystem {
          system = macSystem;
          modules = sharedModules ++ [
            nix-homebrew.darwinModules.nix-homebrew
            ./hosts/mac
            home-manager.darwinModules.home-manager
            (mkHMUser "maxim")
            {
              networking = {
                inherit hostName;
                localHostName = hostName;
                computerName = hostName;
              };

              nix-homebrew = {
                enable = true;
                # Both Macs use native ARM Homebrew; no Intel prefix is needed.
                enableRosetta = false;
                autoMigrate = true;
                user = "maxim";
                trust.formulae = [ "oven-sh/bun/bun" ];
              };

              homebrew = {
                enable = true;

                taps = [
                  "oven-sh/bun"
                ];

                brews = [
                  "oven-sh/bun/bun"
                  "dune"
                  "herdr"
                  "postgresql@18"
                  "sqlite"
                  "tokei"
                ];

                casks = [
                  "bitwarden"
                  "ghostty"
                  "google-chrome"
                  "tailscale-app"
                  "orbstack"
                  "telegram"
                  "transmission"
                  "iina"
                  "steam"
                  "visual-studio-code"
                  "zed"
                  "codex"
                  "claude-code"
                ];
              };
            }
          ];
        };
    in
    {
      packages.${macSystem}.darwin-rebuild = darwin.packages.${macSystem}.darwin-rebuild;

      formatter = nixpkgs.lib.genAttrs [ macSystem linuxSystem ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );

      nixosConfigurations = {
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
        mac = mkMac "mac";
        neo = mkMac "neo";
      };
    };
}
