{ self }:
let
  machineName = "virtulus";
in
{
  privateNetwork = true;
  hostBridge = "ctr0";

  specialArgs = { inherit self; };

  config = {
    imports = [
      self.inputs.clan-core.nixosModules.clanCore
      ./config.nix
    ];
    clan.core.settings.directory = self;
    clan.core.settings.machine.name = machineName;

    # Accept Router Advertisements for SLAAC (IPv6 auto-configuration)
    # Address will be generated from prefix + interface ID (stable privacy)
    systemd.network.networks."10-container" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        IPv6AcceptRA = true;
        # Use stable privacy addresses (RFC 7217) - deterministic per interface
        IPv6PrivacyExtensions = "prefer-public";
      };
    };

    # DNS will be configured via RDNSS from Router Advertisements
    # But keep a fallback in case RDNSS isn't received
    networking.nameservers = [ "fd00:c700::1" ];
  };
}
