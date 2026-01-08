# Usage:
#   make switch HOST=mac   # nix-darwin
#   make switch HOST=pc    # NixOS bare metal
#   make switch HOST=vm    # NixOS VM

HOST ?= mac

# Darwin vs Linux switch command
ifeq ($(HOST),mac)
  SWITCH = sudo nix run nix-darwin/master\#darwin-rebuild -- switch --flake .\#mac
  BUILD  = sudo nix run nix-darwin/master\#darwin-rebuild -- build --flake .\#mac
else
  SWITCH = sudo nixos-rebuild switch --flake .#$(HOST)
  BUILD  = sudo nixos-rebuild build --flake .#$(HOST)
endif

.PHONY: switch build update check fmt gc

switch:
	$(SWITCH)

build:
	$(BUILD)

update:
	nix flake update

check:
	nix flake check

fmt:
	nix fmt || true

gc:
	- sudo nix-collect-garbage -d || true
	- nix store gc || true
