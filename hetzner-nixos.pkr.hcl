# Packer configuration for building NixOS images on Hetzner Cloud
# Reference: https://developer-friendly.blog/blog/2025/01/20/packer-how-to-build-nixos-24-snapshot-on-hetzner-cloud/

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

variable "image_name" {
  type    = string
  default = "nixos-25.11-netboot"
}

variable "server_type" {
  type        = string
  default     = "cx33"
  description = "Server type for building (needs 4GB+ RAM for NixOS installation)"
}

variable "location" {
  type        = string
  default     = "fsn1"
  description = "Hetzner datacenter location (fsn1=Falkenstein, nbg1=Nuremberg)"
}

source "hcloud" "nixos" {
  token        = var.hcloud_token
  image        = "ubuntu-24.04"
  location     = var.location
  server_type  = var.server_type
  ssh_username = "root"
  rescue       = "linux64"

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

  # Upload NixOS configuration
  provisioner "file" {
    source      = "configuration.nix"
    destination = "/tmp/configuration.nix"
  }

  # Upload cloud-init config
  provisioner "file" {
    source      = "cloud-init-99-custom.yaml"
    destination = "/tmp/cloud-init-99-custom.yaml"
  }

  # Install NixOS
  provisioner "shell" {
    script = "scripts/install-nixos.sh"
  }

  # Cleanup and optimize
  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
