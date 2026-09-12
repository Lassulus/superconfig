{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      packages.nat-share =
        (pkgs.writeShellApplication {
          name = "nat-share";
          runtimeInputs = [
            pkgs.dnsmasq
            pkgs.iptables
            pkgs.nftables
            pkgs.iproute2
            pkgs.gawk
            config.packages.pxe-share
          ];
          text = builtins.readFile ./nat-share.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
