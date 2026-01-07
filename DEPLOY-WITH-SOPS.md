# Deploying NixOS Cloud Images with SOPS Support

This guide shows how to deploy NixOS servers that can automatically decrypt SOPS-encrypted secrets on first boot.

## How It Works

The cloud-init configuration checks for a SOPS age private key during boot. If found, it installs the key to `/root/.config/sops/age/keys.txt`, allowing the server to decrypt secrets immediately.

## Prerequisites

1. Have your SOPS age private key ready:
   ```bash
   cat ~/.config/sops/age/keys.txt
   ```

2. Know your age public key (for verification):
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   ```

## Deployment Examples

### Option 1: Hetzner Cloud (Terraform)

```hcl
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Read your local age key
locals {
  sops_age_key = file(pathexpand("~/.config/sops/age/keys.txt"))
}

# Create custom image from GitHub release
resource "hcloud_uploaded_image" "nixos" {
  name        = "nixos-25.11-cloud"
  type        = "raw"
  url         = "https://github.com/YOUR_REPO/releases/download/cloud-123/nixos-25.11-cloud.img.xz"
  compression = "xz"
}

# Deploy server with SOPS key
resource "hcloud_server" "nixos_server" {
  name        = "nixos-production"
  server_type = "cx11"
  location    = "nbg1"
  image       = hcloud_uploaded_image.nixos.id
  ssh_keys    = [var.ssh_key_id]

  # Pass SOPS age key via cloud-init user-data
  user_data = <<-EOT
    #cloud-config
    write_files:
      - path: /tmp/sops-age-key.txt
        permissions: '0600'
        content: |
${indent(10, local.sops_age_key)}
  EOT
}

output "server_ip" {
  value = hcloud_server.nixos_server.ipv4_address
}

output "connect" {
  value = "ssh root@${hcloud_server.nixos_server.ipv4_address}"
}
```

**Deploy:**
```bash
terraform init
terraform apply

# After deployment, verify SOPS works
ssh root@$(terraform output -raw server_ip) 'ls -la /root/.config/sops/age/keys.txt'
```

### Option 2: Hetzner Cloud (CLI)

```bash
#!/bin/bash

# Read your age key
AGE_KEY=$(cat ~/.config/sops/age/keys.txt)

# Create cloud-init user-data
cat > /tmp/cloud-init.yaml <<EOF
#cloud-config
write_files:
  - path: /tmp/sops-age-key.txt
    permissions: '0600'
    content: |
$(echo "$AGE_KEY" | sed 's/^/      /')
EOF

# Create server with SOPS key
hcloud server create \
  --type cx11 \
  --image YOUR_IMAGE_ID \
  --name nixos-production \
  --location nbg1 \
  --ssh-key YOUR_SSH_KEY_ID \
  --user-data-from-file /tmp/cloud-init.yaml

# Clean up
rm /tmp/cloud-init.yaml

# Wait for boot
sleep 60

# Test SOPS
SERVER_IP=$(hcloud server ip nixos-production)
ssh root@$SERVER_IP 'test -f /root/.config/sops/age/keys.txt && echo "✅ SOPS key installed"'
```

### Option 3: DigitalOcean (Terraform)

```hcl
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

locals {
  sops_age_key = file(pathexpand("~/.config/sops/age/keys.txt"))
}

resource "digitalocean_custom_image" "nixos" {
  name         = "nixos-25.11-cloud"
  url          = "https://github.com/YOUR_REPO/releases/download/cloud-123/nixos-25.11-cloud.img.xz"
  distribution = "Unknown OS"
  regions      = ["nyc3"]
}

resource "digitalocean_droplet" "nixos" {
  name     = "nixos-server"
  size     = "s-1vcpu-1gb"
  image    = digitalocean_custom_image.nixos.id
  region   = "nyc3"
  ssh_keys = [var.ssh_key_fingerprint]

  user_data = <<-EOT
    #cloud-config
    write_files:
      - path: /tmp/sops-age-key.txt
        permissions: '0600'
        content: |
${indent(10, local.sops_age_key)}
  EOT
}
```

### Option 4: Local KVM/libvirt (Terraform)

```hcl
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

locals {
  sops_age_key = file(pathexpand("~/.config/sops/age/keys.txt"))
}

# Download and prepare cloud-init ISO with SOPS key
resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"

  user_data = <<-EOT
    #cloud-config
    write_files:
      - path: /tmp/sops-age-key.txt
        permissions: '0600'
        content: |
${indent(10, local.sops_age_key)}
  EOT
}

resource "libvirt_volume" "nixos" {
  name   = "nixos-25.11"
  source = "/var/lib/libvirt/images/nixos-25.11.qcow2"
}

resource "libvirt_domain" "nixos" {
  name       = "nixos-server"
  memory     = "2048"
  vcpu       = 2
  cloudinit  = libvirt_cloudinit_disk.commoninit.id

  disk {
    volume_id = libvirt_volume.nixos.id
  }

  network_interface {
    network_name = "default"
  }
}
```

## Testing SOPS After Deployment

Once your server boots:

```bash
# SSH to server
ssh root@YOUR_SERVER_IP

# Verify age key is installed
ls -la /root/.config/sops/age/keys.txt
# Should show: -rw------- 1 root root ... /root/.config/sops/age/keys.txt

# View public key (verify it matches your local key)
nix-shell -p age --run 'age-keygen -y /root/.config/sops/age/keys.txt'

# Clone repo with encrypted secrets
git clone https://github.com/YOUR_REPO/ai-dev.git
cd ai-dev

# Test decryption
nix-shell -p sops --run 'sops -d secrets/prod.yaml'
# Should decrypt successfully!
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **User-data is visible** - Cloud provider APIs may log user-data. Only use for trusted infrastructure.

2. **Alternative: Vault/Secret Manager** - For production, consider:
   - HashiCorp Vault
   - AWS Secrets Manager
   - Google Secret Manager
   - Fetch secrets via API after boot instead of passing in user-data

3. **Rotate keys** - If you suspect compromise, rotate your age keys:
   ```bash
   # Generate new key
   age-keygen -o ~/.config/sops/age/new-keys.txt

   # Re-encrypt all secrets
   sops rotate -i secrets/prod.yaml
   ```

4. **Use separate keys per environment** - Don't use the same age key for dev/staging/production.

## Advanced: Multiple Keys for Team Access

If you have a team, add multiple age keys to your SOPS config:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/prod.yaml
    age: >-
      age1...,  # Your key
      age2...,  # Teammate 1
      age3...   # Teammate 2
```

Each person can deploy with their own age key, and all can decrypt the same secrets.

## Troubleshooting

### "SOPS key not found after boot"

Check cloud-init logs:
```bash
ssh root@SERVER_IP
cat /var/log/cloud-init-output.log | grep -A5 "SOPS age key"
```

### "Permission denied on keys.txt"

Verify permissions:
```bash
ssh root@SERVER_IP 'stat /root/.config/sops/age/keys.txt'
# Should show: 0600 (rw-------)
```

### "Decryption fails but key is present"

Verify key matches:
```bash
# On local machine
age-keygen -y ~/.config/sops/age/keys.txt

# On server
ssh root@SERVER_IP 'nix-shell -p age --run "age-keygen -y /root/.config/sops/age/keys.txt"'

# Public keys should match!
```

## GitHub Private Repository Support

The cloud-init config also supports GitHub PAT for cloning private repositories.

### Terraform Example with GitHub PAT + Auto-Clone

```hcl
locals {
  sops_age_key = file(pathexpand("~/.config/sops/age/keys.txt"))
  github_pat   = var.github_pat  # Set via TF_VAR_github_pat
}

resource "hcloud_server" "aidev" {
  name        = "ai-dev-server"
  server_type = "cx33"
  location    = "nbg1"
  image       = hcloud_uploaded_image.nixos.id
  ssh_keys    = [var.ssh_key_id]

  user_data = <<-EOT
    #cloud-config
    write_files:
      - path: /tmp/sops-age-key.txt
        permissions: '0600'
        content: |
${indent(10, local.sops_age_key)}

      - path: /tmp/github-pat.txt
        permissions: '0600'
        content: ${local.github_pat}

      - path: /tmp/repo-url.txt
        permissions: '0644'
        content: https://github.com/YOUR_USERNAME/ai-dev.git

      - path: /tmp/repo-dir.txt
        permissions: '0644'
        content: /root/ai-dev

      - path: /tmp/auto-rebuild.txt
        permissions: '0644'
        content: ai-dev-server
  EOT
}
```

**What this does:**
1. ✅ Installs SOPS age key
2. ✅ Configures GitHub PAT for private repo access
3. ✅ Auto-clones your ai-dev repository
4. ✅ Auto-runs `nixos-rebuild switch --flake .#ai-dev-server`
5. 🎉 Server is **fully configured** on first boot!

**Deploy:**
```bash
export TF_VAR_github_pat="ghp_your_token_here"
terraform apply
```

### CLI Example with Full Automation

```bash
#!/bin/bash
set -e

# Configuration
GITHUB_PAT="ghp_your_token_here"
REPO_URL="https://github.com/YOUR_USERNAME/ai-dev.git"
FLAKE_NAME="ai-dev-server"

# Read age key
AGE_KEY=$(cat ~/.config/sops/age/keys.txt)

# Create cloud-init with SOPS + GitHub + auto-clone
cat > /tmp/cloud-init.yaml <<EOF
#cloud-config
write_files:
  - path: /tmp/sops-age-key.txt
    permissions: '0600'
    content: |
$(echo "$AGE_KEY" | sed 's/^/      /')

  - path: /tmp/github-pat.txt
    permissions: '0600'
    content: ${GITHUB_PAT}

  - path: /tmp/repo-url.txt
    permissions: '0644'
    content: ${REPO_URL}

  - path: /tmp/repo-dir.txt
    permissions: '0644'
    content: /root/ai-dev

  - path: /tmp/auto-rebuild.txt
    permissions: '0644'
    content: ${FLAKE_NAME}
EOF

# Deploy
hcloud server create \
  --type cx33 \
  --image YOUR_IMAGE_ID \
  --name ai-dev-server \
  --location nbg1 \
  --ssh-key YOUR_KEY \
  --user-data-from-file /tmp/cloud-init.yaml

rm /tmp/cloud-init.yaml

echo "🚀 Server deploying with full automation!"
echo "⏳ Wait ~5 minutes for cloud-init to complete"
```

### Manual Clone (Without Auto-Rebuild)

If you just want to clone the repo without auto-rebuilding:

```yaml
#cloud-config
write_files:
  - path: /tmp/sops-age-key.txt
    permissions: '0600'
    content: |
      # your age key here

  - path: /tmp/github-pat.txt
    permissions: '0600'
    content: ghp_your_token_here

  - path: /tmp/repo-url.txt
    permissions: '0644'
    content: https://github.com/YOUR_USERNAME/ai-dev.git

  # Omit /tmp/auto-rebuild.txt to skip automatic nixos-rebuild
```

Then SSH in and manually rebuild when ready:
```bash
ssh root@SERVER_IP
cd /root/ai-dev/infrastructure/nixos
nixos-rebuild switch --flake .#ai-dev-server
```

## Complete Deployment Flow Example

Here's a complete example deploying an ai-dev server with SOPS:

```bash
#!/bin/bash
set -e

echo "🚀 Deploying NixOS ai-dev server with FULL AUTOMATION..."

# Configuration
GITHUB_PAT="${GITHUB_PAT:-$(cat ~/.github-pat 2>/dev/null || echo '')}"
REPO_URL="https://github.com/YOUR_USERNAME/ai-dev.git"
FLAKE_NAME="ai-dev-server"

# Validate
if [ -z "$GITHUB_PAT" ]; then
  echo "❌ Set GITHUB_PAT environment variable or create ~/.github-pat"
  exit 1
fi

# 1. Read age key
AGE_KEY=$(cat ~/.config/sops/age/keys.txt)

# 2. Create cloud-init with SOPS + GitHub + auto-deploy
cat > /tmp/cloud-init.yaml <<EOF
#cloud-config
write_files:
  - path: /tmp/sops-age-key.txt
    permissions: '0600'
    content: |
$(echo "$AGE_KEY" | sed 's/^/      /')

  - path: /tmp/github-pat.txt
    permissions: '0600'
    content: ${GITHUB_PAT}

  - path: /tmp/repo-url.txt
    permissions: '0644'
    content: ${REPO_URL}

  - path: /tmp/repo-dir.txt
    permissions: '0644'
    content: /root/ai-dev

  - path: /tmp/auto-rebuild.txt
    permissions: '0644'
    content: ${FLAKE_NAME}
EOF

# 3. Deploy server
echo "📦 Creating Hetzner server..."
hcloud server create \
  --type cx33 \
  --image YOUR_NIXOS_IMAGE_ID \
  --name ai-dev-server \
  --location nbg1 \
  --ssh-key YOUR_SSH_KEY_ID \
  --user-data-from-file /tmp/cloud-init.yaml

rm /tmp/cloud-init.yaml

# 4. Wait for server IP
sleep 5
SERVER_IP=$(hcloud server ip ai-dev-server)
echo "✅ Server created at $SERVER_IP"

# 5. Wait for cloud-init to complete (auto-deployment happens here)
echo "⏳ Waiting for cloud-init automation..."
echo "   - Installing SOPS key"
echo "   - Configuring GitHub PAT"
echo "   - Cloning $REPO_URL"
echo "   - Running nixos-rebuild switch"
echo ""
echo "This will take ~5 minutes..."

# Poll cloud-init status
for i in {1..60}; do
  sleep 10
  if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$SERVER_IP \
    'cloud-init status 2>/dev/null | grep -q "status: done"' 2>/dev/null; then
    echo "✅ Cloud-init completed!"
    break
  fi
  echo "⏳ Still deploying... ($((i * 10))s)"
done

# 6. Verify deployment
echo ""
echo "🔍 Verifying deployment..."
ssh root@$SERVER_IP <<'REMOTE'
  echo "Checking SOPS key..."
  test -f /root/.config/sops/age/keys.txt && echo "  ✅ SOPS key installed" || echo "  ❌ SOPS key missing"

  echo "Checking GitHub credentials..."
  test -f /root/.git-credentials && echo "  ✅ GitHub PAT configured" || echo "  ❌ GitHub PAT missing"

  echo "Checking repository..."
  test -d /root/ai-dev && echo "  ✅ Repository cloned" || echo "  ❌ Repository missing"

  echo "Testing SOPS decryption..."
  cd /root/ai-dev
  if nix-shell -p sops --run 'sops -d secrets/prod.yaml' > /dev/null 2>&1; then
    echo "  ✅ SOPS decryption works"
  else
    echo "  ❌ SOPS decryption failed"
  fi

  echo "Checking NixOS rebuild..."
  if journalctl -u cloud-final.service | grep -q "NixOS rebuilt"; then
    echo "  ✅ NixOS auto-rebuild completed"
  else
    echo "  ⚠️  NixOS rebuild may still be running"
  fi
REMOTE

echo ""
echo "🎉 Deployment complete!"
echo "Connect: ssh root@$SERVER_IP"
echo ""
echo "Server is fully configured with:"
echo "  - SOPS age key (can decrypt secrets)"
echo "  - GitHub PAT (can clone private repos)"
echo "  - ai-dev repository (already cloned)"
echo "  - NixOS configuration (auto-deployed)"
```

## Next Steps

After deployment with SOPS:

1. **Test secret access**: `sops -d secrets/prod.yaml`
2. **Deploy your app**: Run `nixos-rebuild switch` with your flake
3. **Set up monitoring**: Enable the ai-dev production monitor
4. **Backup your age key**: Store it securely offline (password manager, encrypted USB)
