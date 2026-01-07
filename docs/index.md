---
layout: default
title: NixOS Cloud Image - Universal Cloud Deployment
---

# 🚀 NixOS Cloud Image

Universal NixOS images for **any cloud provider** - Deploy in minutes, not hours.

## Latest Blog Posts

- **[Deploying NixOS to Any Cloud Provider in Minutes](blog/deploying-nixos-to-any-cloud.md)** (Jan 8, 2025)
  - Complete guide to universal cloud deployment
  - SOPS integration for secret management
  - Multi-cloud Terraform examples
  - Real-world production setup

## Quick Links

- [GitHub Repository](https://github.com/mikkihugo/nixos-cloud-image)
- [Download Latest Image](https://github.com/mikkihugo/nixos-cloud-image/releases/latest)
- [SOPS Deployment Guide](DEPLOY-WITH-SOPS.md)
- [Build Methods](BUILD-METHODS.md)

## Supported Cloud Providers

✅ Hetzner Cloud • ✅ DigitalOcean • ✅ AWS EC2 • ✅ Vultr • ✅ Linode
✅ Google Cloud • ✅ Azure • ✅ OVH • ✅ Scaleway • ✅ Oracle Cloud
✅ Proxmox VE • ✅ VMware ESXi • ✅ KVM/libvirt • ✅ QEMU

## Features

- **Tiny**: 1.5GB compressed (50% smaller than typical cloud images)
- **Universal**: Works on 14+ cloud providers and hypervisors
- **Auto-updating**: Downloads latest NixOS packages on first boot
- **SOPS-ready**: Auto-installs age keys for secret decryption
- **Fully automated**: GitHub PAT + auto-deploy via cloud-init
- **Free builds**: GitHub Actions (no cost)

## Quick Start

### Terraform (Hetzner Cloud)

```hcl
resource "hcloud_uploaded_image" "nixos" {
  name        = "nixos-25.11-cloud"
  type        = "raw"
  url         = "https://github.com/mikkihugo/nixos-cloud-image/releases/latest/download/nixos-25.11-cloud.img.xz"
  compression = "xz"
}

resource "hcloud_server" "nixos" {
  name        = "nixos-server"
  server_type = "cx11"
  location    = "nbg1"
  image       = hcloud_uploaded_image.nixos.id
}
```

### CLI (Hetzner Cloud)

```bash
hcloud image create \
  --type raw \
  --name nixos-25.11 \
  --url https://github.com/mikkihugo/nixos-cloud-image/releases/latest/download/nixos-25.11-cloud.img.xz \
  --compression xz
```

## Cost

| Build Method | Time | Cost |
|--------------|------|------|
| GitHub runners | 10 min | **FREE** |
| Packer (incremental) | 6 min | $0.013 |
| Packer (from scratch) | 25 min | $0.05 |

**Annual build cost:** $0.00 (using GitHub Actions)

---

Built with ❤️ using NixOS, Packer, and GitHub Actions
