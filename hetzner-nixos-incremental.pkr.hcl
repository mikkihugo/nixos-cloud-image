# Packer configuration for INCREMENTAL builds using existing NixOS snapshot
# This is MUCH faster (2-5 min) since NixOS is already installed

packer {
  required_version = ">= 1.11"

  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1.6"
    }
  }
}

variable "hcloud_token" {
  type      = string
  sensitive = true
  default   = env("HCLOUD_TOKEN")
}

variable "base_snapshot_id" {
  type        = string
  default     = "347588142"
  description = "Existing NixOS snapshot to use as base"
}

variable "image_name" {
  type    = string
  default = "nixos-25.11-netboot"
}

variable "server_type" {
  type        = string
  default     = "cx33"
  description = "Server type for building"
}

variable "location" {
  type        = string
  default     = "fsn1"
  description = "Hetzner datacenter location"
}

source "hcloud" "nixos" {
  token        = var.hcloud_token
  image        = var.base_snapshot_id  # Use existing snapshot instead of Ubuntu!
  location     = var.location
  server_type  = var.server_type
  ssh_username = "root"

  snapshot_name = var.image_name

  snapshot_labels = {
    os           = "nixos"
    version      = "25.11"
    type         = "netboot"
    architecture = "x86"
    created_by   = "packer"
    auto_built   = "true"
    minimal      = "true"
  }
}

build {
  sources = ["source.hcloud.nixos"]

  # Upload updated NixOS configuration
  provisioner "file" {
    source      = "configuration.nix"
    destination = "/tmp/configuration.nix"
  }

  # Upload cloud-init config
  provisioner "file" {
    source      = "cloud-init-99-custom.yaml"
    destination = "/tmp/cloud-init-99-custom.yaml"
  }

  # Quick update: ensure channels, copy configs, rebuild
  provisioner "shell" {
    inline = [
      "echo '=== Incremental NixOS Update ==='",
      # Set up channels for build (needed for nixos-rebuild)
      "echo 'Setting up nixpkgs channel for build...'",
      "nix-channel --add https://nixos.org/channels/nixos-25.11 nixos",
      "nix-channel --update",
      "echo 'Copying configuration files...'",
      "cp /tmp/configuration.nix /etc/nixos/configuration.nix",
      "cp /tmp/cloud-init-99-custom.yaml /etc/cloud/cloud.cfg.d/99-custom.yaml",
      "echo 'Running nixos-rebuild...'",
      "nixos-rebuild boot",  # Rebuild for next boot
      "echo 'Cleaning up...'",
      "nix-collect-garbage",  # Cleanup unreferenced packages
      "echo 'Removing channel config (cloud-init will download fresh on first boot)...'",
      "rm -f /root/.nix-channels",  # Cloud-init will recreate and download latest
      "echo '=== Build Complete ==='",
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
