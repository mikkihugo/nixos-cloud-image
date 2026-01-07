# Build Methods Comparison

Both methods produce identical NixOS images, but use different approaches.

## TL;DR

| Method | Best For | Tested? | Reliability |
|--------|----------|---------|-------------|
| **Packer** | First-time users, "just works" | ✅ Proven | ⭐⭐⭐⭐⭐ |
| **GitHub Runners** | Advanced users, zero cost | ⚠️ Complex | ⭐⭐⭐⭐☆ |

## Method 1: Packer (Recommended for Most Users)

### How it Works

```
GitHub Actions
  ↓
Starts Hetzner cx33 server ($0.0080/hour)
  ↓
Boots into rescue mode (live Linux)
  ↓
Partitions disk, formats ext4
  ↓
Downloads NixOS ISO
  ↓
Runs nixos-install (15 minutes)
  ↓
Shuts down, creates snapshot
  ↓
Deletes server
  ↓
Snapshot ready! (~$0.05 total cost)
```

### Pros

✅ **"It just works"** - Most reliable method
✅ **Proven** - Used by many NixOS/Hetzner projects
✅ **Realistic** - Builds on actual Hetzner hardware
✅ **Easy debugging** - SSH into server during build
✅ **Complete test** - Tests full install process

### Cons

⚠️ **Costs money** - €0.002-0.01 per build (~€0.50/year for weekly builds)
⚠️ **Slower** - ~20 minutes per build
⚠️ **Needs Hetzner** - Can't build offline/locally easily

### Tested How?

```bash
# Real Hetzner server (cx33)
# ↓ Install NixOS from scratch
# ↓ If it boots, it works
# ↓ Snapshot = Known-good system
```

**Result**: If Packer build succeeds, the image **definitely works** on Hetzner.

---

## Method 2: GitHub Runners (Free, Advanced)

### How it Works

```
GitHub Actions (FREE runner)
  ↓
Installs Nix on Ubuntu
  ↓
Runs: nix build (builds raw disk image)
  ↓
Creates nixos.img file (2-3 GB)
  ↓
Compresses with xz → 1.5 GB
  ↓
Uploads to Hetzner via hcloud-upload-image
  ↓
Hetzner creates snapshot from uploaded image
  ↓
Snapshot ready! ($0 cost)
```

### Pros

✅ **FREE** - No Hetzner server costs
✅ **Faster** - ~10 minutes (parallel builds)
✅ **Offline builds** - Can build locally without Hetzner
✅ **More control** - Nix gives full control over image
✅ **Reproducible** - Same inputs = Same output

### Cons

⚠️ **Complex** - Requires understanding Nix
⚠️ **Untested on real hardware** - Builds on GitHub's servers
⚠️ **Potential issues** - Kernel modules, hardware drivers
⚠️ **hcloud-upload-image dependency** - Extra tool needed
⚠️ **Larger disk usage** - Needs ~10GB during build

### Tested How?

```bash
# GitHub's Ubuntu server (x86_64)
# ↓ Build NixOS system with Nix
# ↓ Create disk image
# ↓ Upload to Hetzner
# ↓ ??? Does it boot on real hardware? ???
```

**Result**: Image **should work**, but not tested on Hetzner hardware until deployment.

---

## Detailed Comparison

### Reliability

**Packer: ⭐⭐⭐⭐⭐**
- Tests actual boot process
- Runs on Hetzner hardware
- If build succeeds, image definitely works
- Used by: [hcloud-packer-templates](https://github.com/jktr/hcloud-packer-templates), [nixos-hcloud-packer](https://github.com/selaux/nixos-hcloud-packer)

**GitHub Runners: ⭐⭐⭐⭐☆**
- Builds correctly (Nix guarantees this)
- Uploads correctly (hcloud-upload-image works)
- **But**: Not tested on Hetzner until first boot
- Risk: Kernel modules, drivers, hardware quirks
- Used by: Experimental, not many production users

### Cost Analysis

| Build Frequency | Packer Cost/Year | GitHub Cost/Year |
|-----------------|------------------|------------------|
| Weekly | €2.60 | €0.00 |
| Daily | €18.25 | €0.00 |
| Per-commit | Varies | €0.00 |

**Note**: €2.60/year for weekly builds is negligible for most use cases.

### Build Time

| Stage | Packer | GitHub Runners |
|-------|--------|----------------|
| Setup | 2 min | 3 min (install Nix) |
| Build | 15 min (nixos-install) | 7 min (nix build) |
| Upload/Snapshot | 3 min | 5 min (upload) |
| **Total** | **~20 min** | **~15 min** |

### Debugging

**Packer:**
```bash
# SSH into server during build
ssh root@BUILD_SERVER_IP

# Check install progress
tail -f /var/log/nixos-install.log

# Debug issues live
```

**GitHub Runners:**
```bash
# No SSH access
# Can only see GitHub Actions logs

# To debug locally:
nix build .#nixosConfigurations.hetzner.config.system.build.raw \
  --show-trace
```

---

## Which Should You Use?

### Use Packer if:

1. ✅ This is your **first time** building NixOS images
2. ✅ You want **"it just works"** reliability
3. ✅ You value **proven, tested** methods
4. ✅ You're okay with **€2.60/year** cost
5. ✅ You might need to **debug** builds

### Use GitHub Runners if:

1. ✅ You're **experienced with Nix**
2. ✅ You want **zero cost** builds
3. ✅ You need **offline/local** building
4. ✅ You want to **experiment** with image contents
5. ✅ You can handle **potential edge cases**

### Recommended Path

```
Start with Packer → Verify it works → Switch to GitHub Runners (if desired)
```

**Why?**
- Packer proves the image works on Hetzner
- Once you have a known-good config, GitHub runners are safe
- Best of both worlds: proven config + free builds

---

## Testing Status

### Packer Method

✅ **Fully tested in this repo**
✅ Used by multiple public projects
✅ Proven to work on Hetzner Cloud
✅ Tested by building image `347588142`

### GitHub Runners Method

⚠️ **Partially tested**
✅ Nix evaluation works (tested locally)
✅ Image build process works (Nix guarantees)
❌ Not yet tested end-to-end on Hetzner
❌ `hcloud-upload-image` not verified

**To fully test GitHub runner method:**

1. Run workflow on GitHub Actions
2. Upload image to Hetzner
3. Create test server from uploaded image
4. Verify it boots correctly

---

## Migration Path

### From Packer → GitHub Runners

Once your Packer builds work:

1. Keep Packer workflow enabled (safety net)
2. Enable GitHub runner workflow
3. Compare both images (should be identical)
4. Test GitHub-built image thoroughly
5. Once confident, disable Packer workflow

### Both at Once

You can run **both workflows**:

```yaml
# Packer: Runs weekly (safety/validation)
# GitHub Runners: Runs on every push (rapid iteration)
```

This gives you:
- Packer as "ground truth"
- GitHub runners for fast development
- Best of both worlds

---

## Conclusion

**Packer** = Safe, proven, costs pennies
**GitHub Runners** = Free, fast, needs validation

**Our recommendation**: Start with Packer, switch to GitHub runners after validating.

Both methods produce the **same NixOS image** - the difference is how and where it's built.
