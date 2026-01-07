# Cloud-Init Configuration Options

The default cloud-init configuration auto-detects the latest NixOS stable and creates smart swap. You can customize this behavior by providing your own `user-data` when creating servers.

## 📋 Table of Contents

- [Quick Examples](#quick-examples)
- [NixOS Version Control](#nixos-version-control)
- [Swap Configuration](#swap-configuration)
- [Combined Examples](#combined-examples)
- [Advanced Customization](#advanced-customization)

## Quick Examples

### Deploy with Default (Auto-detect + Smart Swap)

```bash
# Uses built-in cloud-init config
hcloud server create \
  --type cx11 \
  --image IMAGE_ID \
  --name my-server \
  --location nbg1
```

### Deploy with Fixed NixOS Version

```bash
# Create user-data file
cat > user-data.yaml << 'EOF'
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --update
    fi
EOF

# Deploy with custom config
hcloud server create \
  --type cx11 \
  --image IMAGE_ID \
  --name my-server \
  --location nbg1 \
  --user-data-from-file user-data.yaml
```

## NixOS Version Control

### Option 1: Auto-detect Latest Stable (Default)

**Built into the image** - automatically finds the latest stable release.

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      LATEST_STABLE=$(curl -s https://channels.nixos.org/ | \
        grep -oP 'nixos-[0-9]+\.[0-9]+"' | \
        grep -v 'small\|unstable' | head -1 | tr -d '"' || \
        echo 'nixos-25.11')
      echo "Adding NixOS channel: $LATEST_STABLE"
      nix-channel --add https://nixos.org/channels/$LATEST_STABLE nixos
      nix-channel --update
    fi
```

**Use case**: Always get the latest stable NixOS (e.g., 26.05 when it releases)

---

### Option 2: Fixed Stable Version

**Lock to a specific NixOS release.**

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      # Lock to NixOS 25.11
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --update
    fi
```

**Use case**: Production systems that need version stability

**Available versions**: `nixos-25.11`, `nixos-24.11`, `nixos-24.05`, etc.

---

### Option 3: Unstable Channel

**Use bleeding-edge packages.**

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      # Use unstable channel
      nix-channel --add https://nixos.org/channels/nixos-unstable nixos
      nix-channel --update
    fi
```

⚠️ **Warning**: Unstable may have breaking changes. Use for development only.

---

### Option 4: Small Channel (Faster Updates)

**Smaller subset of packages, faster updates.**

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      # Use small channel (subset of packages)
      nix-channel --add https://nixos.org/channels/nixos-25.11-small nixos
      nix-channel --update
    fi
```

**Use case**: Servers that don't need full package set (e.g., minimal web servers)

---

### Option 5: Skip Channel Setup

**Don't download any channel on first boot.**

```yaml
#cloud-config
# Empty bootcmd - no channel setup
```

**Use case**: You'll manage channels manually or via NixOps/deploy-rs

## Swap Configuration

### Option 1: Smart Swap (Default)

**Built into the image** - automatically sizes swap based on RAM.

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -f /swapfile ]; then
      RAM_GB=$(free -g | awk "/^Mem:/{print \$2}")
      if [ "$RAM_GB" -le 2 ]; then
        SWAP_SIZE=2
      elif [ "$RAM_GB" -le 8 ]; then
        SWAP_SIZE=$((RAM_GB * 2))
      else
        SWAP_SIZE=16
      fi
      fallocate -l ${SWAP_SIZE}G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo "/swapfile none swap sw 0 0" >> /etc/fstab
      echo "vm.swappiness=10" >> /etc/sysctl.conf
      sysctl -p
    fi
```

**Sizing table:**

| RAM Size | Swap Size |
|----------|-----------|
| ≤2 GB    | 2 GB      |
| 4 GB     | 8 GB      |
| 8 GB     | 16 GB     |
| >8 GB    | 16 GB     |

---

### Option 2: Fixed Swap Size

**Set a specific swap size regardless of RAM.**

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -f /swapfile ]; then
      # Fixed 4GB swap
      SWAP_SIZE=4
      fallocate -l ${SWAP_SIZE}G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo "/swapfile none swap sw 0 0" >> /etc/fstab
      echo "vm.swappiness=10" >> /etc/sysctl.conf
      sysctl -p
    fi
```

**Use case**: Predictable swap size for capacity planning

---

### Option 3: No Swap

**Disable swap creation entirely.**

```yaml
#cloud-config
# No swap configuration in bootcmd
```

**Use case**: High-memory instances that don't need swap

---

### Option 4: Custom Swappiness

**Adjust how aggressively the kernel uses swap.**

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -f /swapfile ]; then
      SWAP_SIZE=4
      fallocate -l ${SWAP_SIZE}G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo "/swapfile none swap sw 0 0" >> /etc/fstab
      # Custom swappiness (lower = less swap usage)
      echo "vm.swappiness=1" >> /etc/sysctl.conf
      sysctl -p
    fi
```

**Swappiness values:**
- `0-10`: Minimal swap usage (performance-critical apps)
- `10-60`: Balanced (default: 10)
- `60-100`: Aggressive swap usage (memory-constrained)

## Combined Examples

### Production: Fixed Version + Fixed Swap

```yaml
#cloud-config
preserve_hostname: false

bootcmd:
  # Fixed NixOS 25.11
  - |
    if [ ! -e /root/.nix-channels ]; then
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --update
    fi

  # Fixed 8GB swap
  - |
    if [ ! -f /swapfile ]; then
      fallocate -l 8G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo "/swapfile none swap sw 0 0" >> /etc/fstab
      echo "vm.swappiness=10" >> /etc/sysctl.conf
      sysctl -p
    fi
```

**Deploy:**
```bash
hcloud server create \
  --type cx23 \
  --image IMAGE_ID \
  --name production-server \
  --location nbg1 \
  --user-data-from-file production-user-data.yaml
```

---

### Development: Unstable + No Swap

```yaml
#cloud-config
bootcmd:
  # Use unstable for latest packages
  - |
    if [ ! -e /root/.nix-channels ]; then
      nix-channel --add https://nixos.org/channels/nixos-unstable nixos
      nix-channel --update
    fi

  # No swap - plenty of RAM
```

**Deploy:**
```bash
hcloud server create \
  --type cx42 \
  --image IMAGE_ID \
  --name dev-server \
  --location nbg1 \
  --user-data-from-file dev-user-data.yaml
```

---

### CI/CD: Latest Stable + Minimal Swap

```yaml
#cloud-config
bootcmd:
  # Auto-detect latest stable
  - |
    if [ ! -e /root/.nix-channels ]; then
      LATEST_STABLE=$(curl -s https://channels.nixos.org/ | \
        grep -oP 'nixos-[0-9]+\.[0-9]+"' | \
        grep -v 'small\|unstable' | head -1 | tr -d '"' || \
        echo 'nixos-25.11')
      nix-channel --add https://nixos.org/channels/$LATEST_STABLE nixos
      nix-channel --update
    fi

  # Small 2GB swap
  - |
    if [ ! -f /swapfile ]; then
      fallocate -l 2G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo "/swapfile none swap sw 0 0" >> /etc/fstab
      echo "vm.swappiness=1" >> /etc/sysctl.conf
      sysctl -p
    fi
```

## Advanced Customization

### Add Custom Packages on First Boot

```yaml
#cloud-config
bootcmd:
  # Setup channel
  - |
    if [ ! -e /root/.nix-channels ]; then
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --update
    fi

runcmd:
  # Install packages after channel is ready
  - nix-env -iA nixos.vim nixos.git nixos.htop
  - nix-env -iA nixos.docker
```

---

### Run Custom Setup Script

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --update
    fi

runcmd:
  # Download and run custom setup
  - curl -fsSL https://example.com/setup.sh | bash
```

---

### Add SSH Keys from GitHub

```yaml
#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3... # Your key here
    # Or fetch from GitHub
    ssh_import_id:
      - gh:YOUR_GITHUB_USERNAME

bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --update
    fi
```

---

### Set Timezone and Hostname

```yaml
#cloud-config
hostname: my-nixos-server
fqdn: my-nixos-server.example.com
manage_etc_hosts: true

timezone: America/New_York

bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --update
    fi
```

---

### Multiple Channels

```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      # Add both stable and unstable
      nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
      nix-channel --add https://nixos.org/channels/nixos-unstable nixos-unstable
      nix-channel --update
    fi

runcmd:
  # Install stable vim, unstable git
  - nix-env -iA nixos.vim
  - nix-env -iA nixos-unstable.git
```

## Terraform Integration

### With Custom User Data

```hcl
resource "hcloud_server" "nixos" {
  name        = "nixos-server"
  image       = "IMAGE_ID"
  server_type = "cx11"
  location    = "nbg1"

  user_data = <<-EOT
    #cloud-config
    bootcmd:
      - |
        if [ ! -e /root/.nix-channels ]; then
          nix-channel --add https://nixos.org/channels/nixos-25.11 nixos
          nix-channel --update
        fi
      - |
        if [ ! -f /swapfile ]; then
          fallocate -l 4G /swapfile
          chmod 600 /swapfile
          mkswap /swapfile
          swapon /swapfile
          echo "/swapfile none swap sw 0 0" >> /etc/fstab
        fi
  EOT
}
```

### With Template File

```hcl
resource "hcloud_server" "nixos" {
  name        = "nixos-server"
  image       = "IMAGE_ID"
  server_type = "cx11"
  location    = "nbg1"

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    nixos_version = "25.11"
    swap_size     = 4
  })
}
```

**cloud-init.yaml template:**
```yaml
#cloud-config
bootcmd:
  - |
    if [ ! -e /root/.nix-channels ]; then
      nix-channel --add https://nixos.org/channels/nixos-${nixos_version} nixos
      nix-channel --update
    fi
  - |
    if [ ! -f /swapfile ]; then
      fallocate -l ${swap_size}G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
```

## Testing Cloud-Init

### View Cloud-Init Logs

```bash
# SSH into server after first boot
ssh root@YOUR_SERVER_IP

# Check cloud-init status
cloud-init status

# View logs
journalctl -u cloud-init -f
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log
```

### Verify Channel

```bash
# Check installed channel
nix-channel --list

# Check NixOS version
nixos-version
```

### Verify Swap

```bash
# Check swap status
free -h
swapon --show

# Check swappiness
cat /proc/sys/vm/swappiness
```

## Reference

### Available NixOS Channels

- `nixos-25.11` - Current stable (Xantusia)
- `nixos-24.11` - Previous stable (Vicuña)
- `nixos-24.05` - Older stable (Uakari)
- `nixos-unstable` - Rolling release (latest packages)
- `nixos-25.11-small` - Stable with smaller package set
- `nixos-unstable-small` - Unstable with smaller package set

### Cloud-Init Documentation

- [Cloud-Init Official Docs](https://cloudinit.readthedocs.io/)
- [Cloud-Init Examples](https://cloudinit.readthedocs.io/en/latest/reference/examples.html)
- [Hetzner Cloud-Init Support](https://docs.hetzner.com/cloud/servers/user-data/)

### NixOS Channels

- [NixOS Channels](https://channels.nixos.org/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Package Search](https://search.nixos.org/)
