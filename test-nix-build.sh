#!/usr/bin/env bash
# Test if we can build NixOS image locally (simulates GitHub runner)
set -euo pipefail

echo "=== Testing NixOS Image Build (GitHub Runner Method) ==="

# Check if Nix is installed
if ! command -v nix &> /dev/null; then
    echo "❌ Nix is not installed"
    echo "Install with: sh <(curl -L https://nixos.org/nix/install) --daemon"
    exit 1
fi

echo "✓ Nix is installed: $(nix --version)"

# Create a minimal flake for testing
cat > flake.nix << 'FLAKE'
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
FLAKE

echo "✓ Flake created"

# Try to build (this will take a while)
echo "Building NixOS system config..."
echo "⚠️  This is a DRY RUN - we'll just check if it evaluates"

nix eval .#nixosConfigurations.hetzner.config.system.build.toplevel.drvPath \
  --show-trace 2>&1 | head -20

echo ""
echo "✓ Configuration evaluates successfully!"
echo ""
echo "To build the full image, run:"
echo "  nix build .#nixosConfigurations.hetzner.config.system.build.raw"
echo ""
echo "⚠️  Note: This requires:"
echo "  - Linux system (or Linux VM)"
echo "  - ~10 GB disk space"
echo "  - ~30 minutes build time"
