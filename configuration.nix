# Netboot-style minimal NixOS configuration for Hetzner Cloud
{ modulesPath, lib, pkgs, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # Boot configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.tmp.cleanOnBoot = true;
  boot.growPartition = true;

  # Minimal kernel modules for cloud (only virtio)
  boot.initrd.includeDefaultModules = false;
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_net" "virtio_scsi"
    "ext4" "sd_mod" "sr_mod"
  ];

  # Root filesystem with auto-resize
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
    autoResize = true;
  };

  # Cloud-init for metadata (hostname, SSH keys, etc.)
  services.cloud-init.enable = true;
  services.cloud-init.network.enable = true;
  swapDevices = [];  # Swap created by cloud-init on first boot

  # Networking
  networking.hostName = lib.mkDefault "nixos";
  networking.useDHCP = lib.mkDefault true;
  networking.useNetworkd = lib.mkDefault true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # SSH server
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  services.openssh.settings.PasswordAuthentication = false;

  # Bootstrap essentials - minimal but functional
  # git: for cloning configuration repos (ai-dev, etc.)
  # curl: for downloading from web/APIs
  # Everything else downloads on-demand from binary cache
  environment.systemPackages = with pkgs; [ git curl ];
  environment.defaultPackages = [ ];

  # Strip ALL documentation to minimize image size
  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;
  documentation.info.enable = false;
  documentation.doc.enable = false;

  # Only English locale to save space
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  # Nix configuration
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;  # Hard-link duplicates
  };

  # Virtual machine guest configuration
  virtualisation.hypervGuest.enable = lib.mkDefault false;
  virtualisation.vmware.guest.enable = lib.mkDefault false;
  services.qemuGuest.enable = lib.mkDefault true;

  system.stateVersion = "25.11";
}
