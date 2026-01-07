# NixOS Hetzner Cloud Image Builder

Automated builds of minimal, netboot-style NixOS images for Hetzner Cloud.

## 🎯 Features

- ✅ **Tiny**: 1.46 GB compressed (vs 3GB+ typical cloud images)
- ✅ **Auto-updating**: Downloads latest NixOS stable channel on first boot
- ✅ **Smart swap**: 2GB-16GB automatically sized based on instance RAM
- ✅ **Cloud-ready**: Full cloud-init support with metadata
- ✅ **Auto-resize**: Filesystem expands to any disk size (40GB-320GB+)
- ✅ **Weekly builds**: Automated via GitHub Actions (like official NixOS AMIs)

## 🚀 Quick Start

### Deploy with hcloud CLI

```bash
# Get latest image ID from releases
IMAGE_ID=347616916  # See releases for latest

hcloud server create \
  --type cx11 \
  --image $IMAGE_ID \
  --name my-nixos-server \
  --location nbg1 \
  --ssh-key YOUR_KEY
```

### Deploy with Terraform

```hcl
resource "hcloud_server" "nixos" {
  name        = "my-nixos-server"
  image       = "347588142"  # See releases for latest
  server_type = "cx11"
  location    = "nbg1"
  ssh_keys    = ["YOUR_KEY"]
}
```

## 📦 What's in the Image?

**Bootstrap includes:**
- Linux kernel 6.12+ with minimal virtio drivers
- Nix package manager with flakes enabled
- curl for channel downloads
- cloud-init for metadata
- OpenSSH server
- systemd + networking

**Downloads on first boot:**
- Latest NixOS stable channel (~450MB)
- Any additional packages you need

## 🏗️ Building Yourself

### Prerequisites

- [Packer](https://www.packer.io/) >= 1.11
- Hetzner Cloud API token
- 15-20 minutes for build

### Build locally

```bash
# Clone this repo
git clone https://github.com/YOUR_USERNAME/nixos-hetzner-image.git
cd nixos-hetzner-image

# Set your Hetzner token
export HCLOUD_TOKEN="your-token-here"

# Option 1: Automated build + test + cleanup
make all

# Option 2: Manual steps
make init      # Initialize Packer
make validate  # Validate config
make build     # Build image (~15-20 min)
make test      # Test the image
make clean     # Clean up old snapshots

# Option 3: Using Packer directly
packer init .
packer build hetzner-nixos.pkr.hcl
```

**Available Make targets:**
- `make all` - Full automated cycle (build, test, cleanup)
- `make build` - Build the image only
- `make test` - Test latest snapshot by creating a server
- `make clean` - Delete old snapshots (keep last 3)
- `make list` - Show all automated snapshots
- `make purge` - Delete ALL automated snapshots (⚠️ destructive)

### Customize the image

Edit `configuration.nix` to add your packages, services, or configuration:

```nix
{ modulesPath, lib, pkgs, ... }:
{
  # ... existing config ...

  # Add your packages
  environment.systemPackages = with pkgs; [
    curl
    vim
    git
    htop
  ];

  # Add your services
  services.postgresql.enable = true;
}
```

## 🤖 Automated Builds

This repository offers **two build methods**, both automated via GitHub Actions:

### Method 1: GitHub Runners (Recommended) ⭐

**Builds the image directly on GitHub runners - 100% FREE!**

- ✅ No Hetzner server costs during build
- ✅ Faster (parallel builds)
- ✅ More control over image content
- ✅ Can build locally without Hetzner API

**How it works:**
1. GitHub runner builds raw NixOS disk image with Nix
2. Compresses with xz (1-2 GB)
3. Uploads to Hetzner Cloud with `hcloud-upload-image`
4. Creates snapshot
5. Publishes to GitHub Releases

**Workflow:** `.github/workflows/build-with-nix.yml`

---

### Method 2: Packer on Hetzner (Traditional)

**Uses Packer to build on actual Hetzner servers**

- ⚠️ Costs ~€0.01-0.05 per build (server rental during build)
- ⚠️ Slower (serial build process)
- ✅ More "realistic" (actual hardware)
- ✅ Easier debugging (SSH into build server)

**How it works:**
1. Packer spins up Ubuntu server on Hetzner
2. Boots into rescue mode
3. Installs NixOS from scratch
4. Snapshots the disk
5. Deletes build server

**Workflow:** `.github/workflows/build-image.yml`

---

### Setup Automated Builds

⚠️ **Important:** GitHub Actions require manual setup after pushing!

1. **Push this repository to GitHub**
   ```bash
   gh repo create nixos-hetzner-image --public --source=. --remote=origin --push
   ```

2. **Enable GitHub Actions** (Settings → Actions → General)
   - Select "Allow all actions and reusable workflows"
   - Click Save

3. **Add Hetzner API token** (Settings → Secrets → Actions)
   - Name: `HCLOUD_TOKEN`
   - Value: Your Hetzner Cloud API token
   - Get token: https://console.hetzner.cloud/ → Security → API Tokens

4. **Test the workflow**
   - Go to Actions tab
   - Select a workflow
   - Click "Run workflow"
   - **Recommended for first test**: Use "Build NixOS Hetzner Image" (Packer)
   - GitHub runner workflow might need additional setup

5. **Builds run automatically after first success**:
   - Weekly on Sundays at 3 AM UTC
   - On push to configuration files
   - Manual trigger anytime

📖 **Detailed setup guide**: See [docs/SETUP.md](docs/SETUP.md)

### Manual Trigger

- Go to Actions tab
- Select "Build NixOS Image (GitHub Runners)" **OR** "Build NixOS Hetzner Image"
- Click "Run workflow"
- Choose NixOS version (optional)

## 📊 Comparison

| Image Type | Size | Channel Included | Updates |
|------------|------|------------------|---------|
| **This image** | 1.46 GB | Downloads on boot | Auto-detects latest |
| Official NixOS AMI | ~3 GB | Pre-installed | Manual rebuild |
| Standard NixOS ISO | ~1 GB | Pre-installed | Manual rebuild |
| nixos-infect | Varies | Downloads | Manual |

## 🔧 How It Works

This uses a **netboot-style bootstrap** approach:

1. **Minimal base image** (1.46 GB) contains just enough to boot
2. **First boot** runs cloud-init which:
   - Detects latest NixOS stable from channels.nixos.org
   - Downloads and installs the channel
   - Creates smart swap based on RAM
   - Resizes filesystem to full disk
3. **Result**: Full NixOS system with latest packages

## 📖 Documentation

- **[Cloud-Init Options](docs/cloud-init-options.md)** - Customize NixOS version, swap, and more
- [Configuration Reference](docs/configuration.md) - Modify configuration.nix
- [Customization Guide](docs/customization.md) - Add packages, services, users
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## ⚙️ Customization

### Change NixOS Version

The image auto-detects the latest stable by default. To use a specific version:

```yaml
# user-data.yaml
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      # Use NixOS 25.11 specifically
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --update
    fi
```

Deploy with custom config:
```bash
hcloud server create \
  --type cx11 \
  --image IMAGE_ID \
  --name my-server \
  --user-data-from-file user-data.yaml
```

### Fixed Swap Size

Default is smart sizing (2-16GB based on RAM). To set a fixed size:

```yaml
# user-data.yaml
#cloud-config
bootcmd:
  - |
    if [ ! -f /swapfile ]; then
      # Fixed 8GB swap
      fallocate -l 8G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo "/swapfile none swap sw 0 0" >> /etc/fstab
      echo "vm.swappiness=10" >> /etc/sysctl.conf
      sysctl -p
    fi
```

**See [Cloud-Init Options](docs/cloud-init-options.md) for all customization options!**

## 🙏 Credits

Built using:
- [HashiCorp Packer](https://www.packer.io/)
- [Hetzner Cloud Packer Plugin](https://github.com/hetznercloud/packer-plugin-hcloud)
- [NixOS](https://nixos.org/)

Inspired by:
- [jktr/hcloud-packer-templates](https://github.com/jktr/hcloud-packer-templates)
- [Developer Friendly Blog - Packer NixOS Guide](https://developer-friendly.blog/blog/2025/01/20/packer-how-to-build-nixos-24-snapshot-on-hetzner-cloud/)
- [NixOS/amis](https://github.com/NixOS/amis)

## 📝 License

MIT License - see [LICENSE](LICENSE)

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.

### Reporting Issues

If you find a bug or have a feature request, please open an issue with:
- Image ID from releases
- Instance type and location
- Steps to reproduce
- Expected vs actual behavior

## ⭐ Star History

If you find this useful, please star the repo!
