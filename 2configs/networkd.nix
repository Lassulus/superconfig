{ lib, ... }:
{

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
