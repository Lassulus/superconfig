{ config, lib, pkgs, ... }:
{
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd.stopIfChanged = false;
  # Services that are only restarted might be not able to resolve when resolved is stopped before
  systemd.services.systemd-resolved.stopIfChanged = false;

  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    networks.wl0 = {
      matchConfig.Name = "wl0";
      DHCP = "yes";
      networkConfig = {
        IgnoreCarrierLoss = "3s";
      };
      dhcpV4Config.UseDNS = true;
    };
  };
}
