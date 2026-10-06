# Public ssh is on 45621; port 22 itself only answers on the VPNs (and lo).
{
  networking.nftables.tables.ssh-redirect = {
    family = "inet";
    content = ''
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        tcp dport 45621 redirect to :22
      }
      chain output {
        type nat hook output priority dstnat; policy accept;
        oifname "lo" tcp dport 45621 redirect to :22
      }
      # Runs before nixos-fw, which accepts 22 everywhere. Connections that
      # came in on 45621 have been redirected to 22 already, so match the
      # port the client asked for.
      chain input {
        type filter hook input priority filter - 1; policy accept;
        ct state new meta l4proto tcp ct original proto-dst 22 iifname != { "lo", "retiolum", "wiregrill" } reject with tcp reset
      }
    '';
  };
}
