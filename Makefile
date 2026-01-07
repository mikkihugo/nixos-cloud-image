# Makefile for NixOS Hetzner Image Builder

.PHONY: help init validate build test clean

# Default target
help:
	@echo "NixOS Hetzner Image Builder"
	@echo ""
	@echo "Available targets:"
	@echo "  make init       - Initialize Packer plugins"
	@echo "  make validate   - Validate Packer configuration"
	@echo "  make build      - Build the NixOS image (~15-20 minutes)"
	@echo "  make test       - Test the latest snapshot"
	@echo "  make clean      - Clean up old snapshots (keep last 3)"
	@echo "  make all        - Build, test, and clean (full cycle)"
	@echo ""
	@echo "Environment variables:"
	@echo "  HCLOUD_TOKEN    - Hetzner Cloud API token (required)"
	@echo "  SERVER_TYPE     - Server type for building (default: cx22)"
	@echo "  LOCATION        - Datacenter location (default: nbg1)"
	@echo ""

# Initialize Packer
init:
	@echo "Initializing Packer plugins..."
	@packer init .
	@echo "✓ Packer initialized"

# Validate Packer configuration
validate: init
	@echo "Validating Packer configuration..."
	@packer validate .
	@echo "✓ Configuration valid"

# Build the image
build: validate
	@echo "Building NixOS image..."
	@packer build hetzner-nixos.pkr.hcl
	@echo "✓ Build complete"

# Test the latest snapshot
test:
	@echo "Testing latest snapshot..."
	@./scripts/build-and-test.sh test
	@echo "✓ Test complete"

# Clean up old snapshots
clean:
	@echo "Cleaning up old snapshots..."
	@curl -s -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
		"https://api.hetzner.cloud/v1/images?type=snapshot&sort=created:desc" | \
		jq -r '.images[] | select(.labels.created_by == "packer") | .id' | \
		tail -n +4 | while read id; do \
			echo "Deleting snapshot: $$id"; \
			curl -s -X DELETE -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
				"https://api.hetzner.cloud/v1/images/$$id"; \
		done
	@echo "✓ Cleanup complete"

# Full automated cycle
all:
	@./scripts/build-and-test.sh

# Show current snapshots
list:
	@echo "Current snapshots:"
	@curl -s -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
		"https://api.hetzner.cloud/v1/images?type=snapshot&sort=created:desc" | \
		jq -r '.images[] | select(.labels.created_by == "packer") | "\(.id)\t\(.description)\t\(.image_size)GB\t\(.created)"'

# Delete all automated snapshots (WARNING: destructive!)
purge:
	@read -p "Delete ALL automated snapshots? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		curl -s -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
			"https://api.hetzner.cloud/v1/images?type=snapshot" | \
			jq -r '.images[] | select(.labels.created_by == "packer") | .id' | \
			while read id; do \
				echo "Deleting snapshot: $$id"; \
				curl -s -X DELETE -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
					"https://api.hetzner.cloud/v1/images/$$id"; \
			done; \
		echo "✓ All snapshots deleted"; \
	else \
		echo "Cancelled"; \
	fi
