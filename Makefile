# Usage:
#   make switch HOST=mac   # nix-darwin
#   make switch HOST=neo   # new MacBook
#   make switch HOST=vm    # NixOS VM

# Once Neo has been activated, plain `make switch` keeps its identity.
HOST ?= $(shell if [ "$$(uname -s)" = Darwin ] && [ "$$(scutil --get LocalHostName 2>/dev/null)" = neo ]; then echo neo; else echo mac; fi)

# Darwin vs Linux switch command
ifneq ($(filter $(HOST),mac neo),)
  SWITCH = sudo nix run --no-write-lock-file .\#darwin-rebuild -- switch --flake .\#$(HOST)
  BUILD  = nix run --no-write-lock-file .\#darwin-rebuild -- build --flake .\#$(HOST)
else ifeq ($(HOST),vm)
  SWITCH = sudo nixos-rebuild switch --flake .\#$(HOST)
  BUILD  = sudo nixos-rebuild build --flake .\#$(HOST)
else
  $(error Unknown HOST '$(HOST)'; use mac, neo, or vm)
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
	nix eval --no-write-lock-file .\#darwinConfigurations.mac.system.drvPath
	nix eval --no-write-lock-file .\#darwinConfigurations.neo.system.drvPath
	nix eval --no-write-lock-file .\#nixosConfigurations.vm.config.system.build.toplevel.drvPath

fmt:
	nix fmt

gc:
	- sudo nix-collect-garbage -d || true
	- nix store gc || true
