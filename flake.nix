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
            system.stateVersion = "25.11";
          })
        ];
      };

      # Disk image package for GitHub runner builds
      # Produces a downloadable .img file
      packages.x86_64-linux.diskImage = let
        config = self.nixosConfigurations.hetzner.config;
      in pkgs.callPackage "${nixpkgs}/nixos/lib/make-disk-image.nix" {
        inherit pkgs config;
        lib = nixpkgs.lib;
        diskSize = 4096;  # 4GB (will auto-resize on first boot)
        format = "raw";
        partitionTableType = "legacy";  # MBR for maximum compatibility
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
