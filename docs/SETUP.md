# Setup Guide - Getting GitHub Actions Working

This guide ensures your automated builds work correctly after pushing to GitHub.

## ⚠️ Important: Manual Setup Required

GitHub Actions **will not work** immediately after pushing. You need to:

1. ✅ Enable GitHub Actions (if disabled)
2. ✅ Add the `HCLOUD_TOKEN` secret
3. ✅ (Optional) Install `hcloud-upload-image` for GitHub runner builds

## Step-by-Step Setup

### 1. Push Repository to GitHub

```bash
cd /Users/mhugo/code/nixos-hetzner-image

# Option A: Using GitHub CLI (recommended)
gh repo create nixos-hetzner-image \
  --public \
  --source=. \
  --remote=origin \
  --push

# Option B: Manual
git remote add origin git@github.com:YOUR_USERNAME/nixos-hetzner-image.git
git push -u origin main
```

### 2. Enable GitHub Actions

**By default, Actions might be disabled for new repos!**

1. Go to your repo on GitHub: `https://github.com/YOUR_USERNAME/nixos-hetzner-image`
2. Click **Settings** tab
3. In left sidebar, click **Actions** → **General**
4. Under "Actions permissions":
   - ✅ Select **"Allow all actions and reusable workflows"**
5. Scroll down and click **Save**

### 3. Add Hetzner Cloud API Token

**The workflows REQUIRE this secret to work!**

1. Get your Hetzner Cloud API token:
   - Go to https://console.hetzner.cloud/
   - Select your project
   - Go to **Security** → **API Tokens**
   - Click **Generate API Token**
   - Name it: `github-actions`
   - Permissions: **Read & Write**
   - Copy the token (you won't see it again!)

2. Add secret to GitHub:
   - Go to your repo settings
   - Click **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `HCLOUD_TOKEN`
   - Value: Paste your token
   - Click **Add secret**

### 4. Verify Setup

**Check Actions tab:**

1. Go to **Actions** tab in your repo
2. You should see two workflows:
   - ✅ **Build NixOS Image (GitHub Runners)** - Recommended
   - ✅ **Build NixOS Hetzner Image** - Alternative (Packer)

3. If you see ⚠️ warnings or no workflows:
   - Check that Actions are enabled (step 2)
   - Check that `.github/workflows/*.yml` files were pushed
   - Check file permissions (should be 644)

### 5. Test with Manual Trigger

**Don't wait for the schedule - test now!**

1. Go to **Actions** tab
2. Click **"Build NixOS Image (GitHub Runners)"**
3. Click **"Run workflow"** button (top right)
4. Select branch: `main`
5. (Optional) Change NixOS version
6. Click **"Run workflow"**

**What happens next:**
- Workflow starts (~2 minutes)
- Installs Nix on GitHub runner (~3 minutes)
- Builds NixOS image (~5 minutes)
- Compresses with xz (~2 minutes)
- **⚠️ Uploads to Hetzner (requires `hcloud-upload-image`)** (~5 minutes)
- Creates GitHub release
- Total: ~15-20 minutes

## Known Issues & Solutions

### Issue 1: "hcloud-upload-image not found"

**Problem:** The GitHub runner workflow tries to install `hcloud-upload-image` but might fail.

**Solution:** Update the workflow to build from source:

```yaml
- name: Install hcloud-upload-image
  run: |
    # Build from source since binary might not be available
    git clone https://github.com/apricote/hcloud-upload-image.git
    cd hcloud-upload-image
    go build -o hcloud-upload-image .
    sudo mv hcloud-upload-image /usr/local/bin/
```

**OR** use the Packer workflow instead (always works):

### Issue 2: "workflow not found" or "disabled"

**Problem:** Workflows don't appear in Actions tab.

**Solutions:**
1. Check Actions are enabled (Settings → Actions → General)
2. Ensure `.github/workflows/` directory exists in your repo
3. Check workflow YAML syntax: `yamllint .github/workflows/*.yml`
4. Push again if files weren't uploaded

### Issue 3: "HCLOUD_TOKEN secret not found"

**Problem:** Workflow fails with "Error: Input required and not supplied: token"

**Solution:** Add the secret (see step 3 above)

### Issue 4: Nix build fails on GitHub runner

**Problem:** The Nix build might fail due to disk space or memory limits.

**Solution:** Use the **Packer workflow** instead - it builds on Hetzner servers with more resources.

## Which Workflow Should I Use?

### Use GitHub Runners (build-with-nix.yml) if:
- ✅ You want FREE builds
- ✅ You have time to debug Nix issues
- ✅ You want to build locally too
- ✅ You're comfortable with Nix

### Use Packer (build-image.yml) if:
- ✅ You want it to "just work" (most reliable)
- ✅ You don't mind €0.01-0.05 per build
- ✅ You want to SSH debug during build
- ✅ You prefer traditional VM-based builds

**Recommendation for first-time users:** Start with **Packer workflow** - it's more reliable!

## Testing the Packer Workflow

The Packer workflow is **more reliable** and requires less setup:

1. Go to **Actions** → **Build NixOS Hetzner Image**
2. Click **Run workflow**
3. It will:
   - Spin up Ubuntu server on Hetzner
   - Install NixOS
   - Create snapshot
   - Delete server
   - Publish to Releases

**This is guaranteed to work** if:
- ✅ `HCLOUD_TOKEN` secret is added
- ✅ Token has Read & Write permissions
- ✅ Your Hetzner account has credits

## Disabling Unwanted Workflows

If you only want ONE workflow to run:

1. Go to **Actions** tab
2. Click the workflow you DON'T want
3. Click **⋯** (three dots) → **Disable workflow**

Example: Disable Packer workflow, keep GitHub runner workflow.

## Troubleshooting

### View workflow logs

1. Go to **Actions** tab
2. Click on a workflow run
3. Click on the job name (e.g., "build-image")
4. Expand each step to see logs

### Common errors

**Error:** `hcloud: authentication failed`
- Solution: Check `HCLOUD_TOKEN` secret is correct

**Error:** `insufficient credits`
- Solution: Add credits to your Hetzner account

**Error:** `image upload failed`
- Solution: Check disk space on runner, or use Packer workflow

**Error:** `workflow disabled`
- Solution: Enable Actions in Settings

## Manual Local Testing

### Test Packer workflow locally:

```bash
export HCLOUD_TOKEN="your-token"
cd /Users/mhugo/code/nixos-hetzner-image

# Initialize and build
packer init .
packer build hetzner-nixos.pkr.hcl

# Or use Make
make build
```

### Test GitHub runner workflow locally:

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon

# Build image
nix build .#nixosConfigurations.hetzner.config.system.build.raw

# Compress
xz -9 result/nixos.img

# Upload (requires hcloud-upload-image)
hcloud-upload-image \
  --server-type cx11 \
  --image-path result/nixos.img.xz \
  --compression xz \
  --description "test-image"
```

## Success Checklist

After setup, you should have:

- ✅ Repository pushed to GitHub
- ✅ Actions enabled in Settings
- ✅ `HCLOUD_TOKEN` secret added
- ✅ At least one workflow visible in Actions tab
- ✅ First manual workflow run succeeded
- ✅ New release appeared with image ID
- ✅ Can deploy server with: `hcloud server create --image IMAGE_ID`

## Next Steps

Once everything works:

1. **Star your repo** ⭐
2. **Add a nice README badge**:
   ```markdown
   ![Build Status](https://github.com/YOUR_USERNAME/nixos-hetzner-image/actions/workflows/build-with-nix.yml/badge.svg)
   ```
3. **Share on**:
   - NixOS Discourse
   - Reddit: r/NixOS
   - Hacker News
4. **Accept contributions**: Others will fork and improve!

## Support

If you have issues:

1. Check this guide carefully
2. Read workflow logs in Actions tab
3. Try the Packer workflow (more reliable)
4. Open an issue with:
   - Workflow name
   - Error message
   - Link to failed workflow run

---

**TL;DR: After pushing to GitHub, you MUST:**
1. Enable Actions in Settings
2. Add `HCLOUD_TOKEN` secret
3. Manually trigger a workflow to test
4. Use Packer workflow if GitHub runner fails
