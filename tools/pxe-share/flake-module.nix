{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.pxe-share =
        (pkgs.writeShellApplication {
          name = "pxe-share";
          runtimeInputs = [
            pkgs.dnsmasq
            pkgs.iptables
            pkgs.nftables
            pkgs.iproute2
            pkgs.gawk
            pkgs.darkhttpd
          ];
          text = builtins.readFile ./pxe-share.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
