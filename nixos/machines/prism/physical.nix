{ config, lib, pkgs, ... }:

{

  imports = [
    ./config.nix
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.swraid.enable = true;

  fileSystems."/" = {
    device = "rpool/root/nixos";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/d155d6ff-8e89-4876-a9e7-d1b7ba6a4804";
    fsType = "ext4";
  };

  fileSystems."/backups" = {
    device = "tank/backups";
    fsType = "zfs";
  };

  fileSystems."/srv/http" = {
    device = "tank/srv-http";
    fsType = "zfs";
  };

  fileSystems."/var/download" = {
    device = "tank/download";
    fsType = "zfs";
  };

  fileSystems."/var/lib/containers" = {
    device = "tank/containers";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "tank/home";
    fsType = "zfs";
  };

  fileSystems."/var/lib/nextcloud" = {
    device = "tank/nextcloud";
    fsType = "zfs";
  };

  fileSystems."/var/lib/libvirt" = {
    device = "tank/libvirt";
    fsType = "zfs";
  };

  fileSystems."/var/realwallpaper/archive" = {
    device = "tank/wallpaper";
    fsType = "zfs";
  };

  # silence mdmonitor.service failures
  # https://github.com/NixOS/nixpkgs/issues/72394
  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';

  nix.maxJobs = lib.mkDefault 8;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" "/dev/sdb" ];

  # we don't pay for power there and this might solve a problem we observed at least once
  # https://www.thomas-krenn.com/de/wiki/PCIe_Bus_Error_Status_00001100_beheben
  boot.kernelParams = [ "pcie_aspm=off" "net.ifnames=0" "nomodeset" ];
  networking.dhcpcd.enable = false;


  networking.useNetworkd = lib.mkForce false;
  systemd.network.enable = lib.mkForce false;
  # bridge config
  networking.bridges."ext-br".interfaces = [ "eth0" ];
  networking = {
    hostId = "2283aaae";
    defaultGateway = "95.216.1.129";
    defaultGateway6 = { address = "fe80::1"; interface = "ext-br"; };
    # Use google's public DNS server
    nameservers = [ "8.8.8.8" ];
    interfaces.ext-br.ipv4.addresses = [
      {
        address = "95.216.1.150";
        prefixLength = 26;
      }
    ];
    interfaces.ext-br.ipv6.addresses = [
      {
        address = "2a01:4f9:2a:1e9::1";
        prefixLength = 64;
      }
    ];
  };

}
