#!/usr/bin/env bash
# Automated build, test, and cleanup script using Hetzner Cloud API
set -euo pipefail

# Configuration
HCLOUD_TOKEN="${HCLOUD_TOKEN:-}"
SERVER_TYPE="${SERVER_TYPE:-cx22}"
LOCATION="${LOCATION:-nbg1}"
IMAGE_NAME="${IMAGE_NAME:-nixos-25.11-netboot-$(date +%Y%m%d-%H%M)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

check_requirements() {
    log "Checking requirements..."

    if [ -z "$HCLOUD_TOKEN" ]; then
        error "HCLOUD_TOKEN environment variable not set"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed"
        exit 1
    fi

    if ! command -v packer &> /dev/null; then
        error "packer is required but not installed"
        exit 1
    fi

    log "✓ All requirements met"
}

build_image() {
    log "Building NixOS image with Packer..."

    # Initialize Packer
    packer init .

    # Validate configuration
    packer validate .

    # Build the image
    log "Starting Packer build (this takes ~15-20 minutes)..."
    packer build -var "image_name=${IMAGE_NAME}" hetzner-nixos.pkr.hcl

    log "✓ Packer build complete"
}

get_latest_snapshot() {
    log "Querying Hetzner API for latest snapshot..."

    RESPONSE=$(curl -s -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
        "https://api.hetzner.cloud/v1/images?type=snapshot&sort=created:desc")

    SNAPSHOT_ID=$(echo "$RESPONSE" | jq -r '.images[0].id')
    SNAPSHOT_NAME=$(echo "$RESPONSE" | jq -r '.images[0].description')
    SNAPSHOT_SIZE=$(echo "$RESPONSE" | jq -r '.images[0].image_size')

    if [ "$SNAPSHOT_ID" = "null" ]; then
        error "No snapshot found"
        exit 1
    fi

    log "✓ Found snapshot: $SNAPSHOT_ID ($SNAPSHOT_NAME, ${SNAPSHOT_SIZE}GB)"
    echo "$SNAPSHOT_ID"
}

test_image() {
    local SNAPSHOT_ID=$1
    log "Testing image by creating a temporary server..."

    # Create test server
    local SERVER_NAME="test-nixos-$(date +%s)"
    log "Creating test server: $SERVER_NAME"

    local CREATE_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
        -H "Content-Type: application/json" \
        "https://api.hetzner.cloud/v1/servers" \
        -d "{
            \"name\": \"${SERVER_NAME}\",
            \"server_type\": \"cx11\",
            \"image\": ${SNAPSHOT_ID},
            \"location\": \"${LOCATION}\",
            \"start_after_create\": true,
            \"labels\": {
                \"purpose\": \"testing\",
                \"auto_cleanup\": \"true\"
            }
        }")

    local SERVER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.server.id')
    local SERVER_IP=$(echo "$CREATE_RESPONSE" | jq -r '.server.public_net.ipv4.ip')

    if [ "$SERVER_ID" = "null" ]; then
        error "Failed to create test server"
        echo "$CREATE_RESPONSE" | jq .
        exit 1
    fi

    log "✓ Server created: $SERVER_ID (IP: $SERVER_IP)"

    # Wait for server to be ready
    log "Waiting for server to boot (60 seconds)..."
    sleep 60

    # Test SSH connectivity
    log "Testing SSH connectivity..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"$SERVER_IP" 'echo "SSH OK"' 2>/dev/null; then
        log "✓ SSH connection successful"
    else
        warn "SSH connection failed (this might be OK if SSH keys aren't configured)"
    fi

    # Test basic NixOS commands via SSH (if accessible)
    log "Testing NixOS installation..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"$SERVER_IP" '
        echo "NixOS Version: $(nixos-version)" &&
        echo "Nix Store: $(du -sh /nix/store 2>/dev/null || echo "N/A")" &&
        echo "Swap: $(free -h | grep Swap)" &&
        echo "Channel: $(nix-channel --list)" &&
        echo "Cloud-init status: $(cloud-init status)"
    ' 2>/dev/null; then
        log "✓ NixOS installation verified"
    else
        warn "Could not verify NixOS installation (SSH access required)"
    fi

    # Cleanup test server
    log "Cleaning up test server..."
    curl -s -X DELETE \
        -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
        "https://api.hetzner.cloud/v1/servers/${SERVER_ID}"

    log "✓ Test server deleted"
}

cleanup_old_snapshots() {
    log "Cleaning up old snapshots (keeping last 3)..."

    RESPONSE=$(curl -s -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
        "https://api.hetzner.cloud/v1/images?type=snapshot&sort=created:desc")

    # Get all snapshots with auto_built label
    SNAPSHOT_IDS=$(echo "$RESPONSE" | jq -r '.images[] | select(.labels.created_by == "packer") | .id')

    # Keep first 3, delete the rest
    echo "$SNAPSHOT_IDS" | tail -n +4 | while read -r id; do
        if [ -n "$id" ]; then
            log "Deleting old snapshot: $id"
            curl -s -X DELETE \
                -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
                "https://api.hetzner.cloud/v1/images/${id}"
        fi
    done

    log "✓ Old snapshots cleaned up"
}

show_summary() {
    local SNAPSHOT_ID=$1

    log ""
    log "═══════════════════════════════════════════════"
    log "Build Summary"
    log "═══════════════════════════════════════════════"
    log ""
    log "Snapshot ID: ${SNAPSHOT_ID}"
    log ""
    log "Deploy with hcloud CLI:"
    echo "  hcloud server create --type cx11 --image ${SNAPSHOT_ID} --name my-server --location nbg1"
    log ""
    log "Deploy with Terraform:"
    cat <<EOF
  resource "hcloud_server" "nixos" {
    name        = "my-server"
    image       = "${SNAPSHOT_ID}"
    server_type = "cx11"
    location    = "nbg1"
  }
EOF
    log ""
    log "═══════════════════════════════════════════════"
}

main() {
    log "NixOS Hetzner Image Builder - Automated Build & Test"
    log ""

    check_requirements

    # Build the image
    build_image

    # Get the snapshot ID
    SNAPSHOT_ID=$(get_latest_snapshot)

    # Test the image
    test_image "$SNAPSHOT_ID"

    # Cleanup old snapshots
    cleanup_old_snapshots

    # Show summary
    show_summary "$SNAPSHOT_ID"

    log "✓ All done!"
}

# Handle Ctrl+C gracefully
trap 'error "Script interrupted"; exit 130' INT

# Run main function
main "$@"
