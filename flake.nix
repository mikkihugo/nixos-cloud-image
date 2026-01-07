{
  description = "NixOS Hetzner Cloud Image Builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      darwinPkgs = nixpkgs.legacyPackages.aarch64-darwin;
    in
    {
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

      # Development shell for macOS and Linux
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          actionlint
          yamllint
          shellcheck
        ];
      };

      devShells.aarch64-darwin.default = darwinPkgs.mkShell {
        buildInputs = with darwinPkgs; [
          actionlint
          yamllint
          shellcheck
        ];
      };
    };
}
