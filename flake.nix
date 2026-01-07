{
  description = "NixOS Hetzner Cloud Image Test";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.hetzner = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ({ config, lib, pkgs, ... }: {
          # Minimal system for image building
          system.stateVersion = "25.11";
        })
      ];
    };
  };
}
