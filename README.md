sudo nixos-rebuild -L --refresh --no-write-lock-file switch --flake github:mxmzdlv/nix#vm
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#mac
