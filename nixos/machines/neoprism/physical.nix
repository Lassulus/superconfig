{ config, lib, pkgs, ... }:

{

  imports = [
    ./config.nix
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
  ];

  disko.devices = import ./disk.nix;
  networking.hostId = "9c0a74ac";

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.devices = [
    config.disko.devices.disk."/dev/nvme0n1".device
    config.disko.devices.disk."/dev/nvme1n1".device
  ];
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # networking config
  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    config = {
      networkConfig.SpeedMeter = true;
    };
    # netdevs.ext-br.netdevConfig = {
    #   Kind = "bridge";
    #   Name = "ext-br";
    #   MACAddress = "a8:a1:59:0f:2d:69";
    # };
    # networks.ext-br = {
    #   name = "ext-br";
    #   address = [
    #     "95.217.192.59/26"
    #     "2a01:4f9:4a:4f1a::1/64"
    #   ];
    #   gateway = [
    #     "95.217.192.1"
    #     "fe80::1"
    #   ];
    # };
    networks.eth0 = {
      #bridge = [ "ext-br" ];
      matchConfig.Name = "eth0";
       address = [
         "95.217.192.59/26"
         "2a01:4f9:4a:4f1a::1/64"
       ];
       gateway = [
         "95.217.192.1"
         "fe80::1"
       ];
    };
  };

  networking.useDHCP = false;
  # boot.initrd.network = {
  #   enable = true;
  #   ssh = {
  #     enable = true;
  #     authorizedKeys = [ config.krebs.users.lass.pubkey ];
  #     port = 2222;
  #     hostKeys = [
  #       (<secrets/ssh.id_ed25519>)
  #       (<secrets/ssh.id_rsa>)
  #     ];
  #   };
  # };
  # boot.kernelParams = [
  #   "net.ifnames=0"
  #   "ip=dhcp"
  #   "boot.trace"
  # ];
}
