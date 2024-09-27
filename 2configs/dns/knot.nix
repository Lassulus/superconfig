{
  lib,
  ...
}:
let
  ip4 = "95.217.192.59";
  ip6 = "2a01:4f9:4a:4f1a::2";
  # acmeChallenge = domain:
  #   pkgs.writeText "_acme-challenge.${domain}.zone" ''
  #     @ 3600 IN SOA _acme-challenge.${domain}. ns1.lassul.us. 2023101213 7200 3600 86400 3600

  #     $TTL 600

  #     @ IN NS ns1.lassul.us.
  #   '';
  # dyndns = domain:
  #   pkgs.writeText "${domain}.zone" ''
  #     @ 3600 IN SOA ${domain}. ns1.lassul.us. 2023101213 7200 3600 86400 3600

  #     $TTL 300

in
#     @ IN NS ns1.lassul.us.
#   '';
{
  #content of the secret
  #key:
  #- id: acme
  #  algorithm: hmac-sha256
  #  secret: 00000000000000000000000000000000000000000000
  #nix-shell -p knot-dns --run 'keymgr -t my_name hmac-sha256'
  # clanCore.facts.services.knot = {
  #   secret."knot-keys.conf" = {};
  #   generator = ''
  #     ${pkgs.knot-dns}/bin/keymgr -t  hmac-sha256
  #   '';
  # };

  services.knot = {
    enable = true;
    # keyFiles = [
    #   config.sops.secrets."knot-keys.conf".path
    # ];
    settings = {
      server = {
        listen = [
          "${ip4}@53"
          "${ip6}@53"
        ];
      };

      remote = [
        {
          id = "hetzner_ip4_1";
          address = "213.239.242.238@53";
        }
        {
          id = "hetzner_ip4_2";
          address = "213.133.105.6@53";
        }
        {
          id = "hetzner_ip4_3";
          address = "193.47.99.3@53";
        }
        {
          id = "hetzner_ip6_1";
          address = "2a01:4f8:0:a101::a:1@53";
        }
        {
          id = "hetzner_ip6_2";
          address = "2a01:4f8:d0a:2004::2@53";
        }
        {
          id = "hetzner_ip6_3";
          address = "2001:67c:192c::add:a3";
        }
      ];

      # to generate TSIG key
      # for i in host; do keymgr -t $i; done
      acl = [
        {
          id = "hetzner_ip4_1";
          address = "213.239.242.238";
          action = "transfer";
        }
        {
          id = "hetzner_ip4_2";
          address = "213.133.100.103";
          action = "transfer";
        }
        {
          id = "hetzner_ip4_3";
          address = "193.47.99.3";
          action = "transfer";
        }
        {
          id = "hetzner_ip6_1";
          address = "2a01:4f8:0:a101::a:1";
          action = "transfer";
        }
        {
          id = "hetzner_ip6_2";
          address = "2a01:4f8:0:1::5ddc:2";
          action = "transfer";
        }
        {
          id = "hetzner_ip6_3";
          address = "2001:67c:192c::add:a3";
          action = "transfer";
        }
      ];

      mod-rrl = [
        {
          id = "default";
          rate-limit = 200;
          slip = 2;
        }
      ];

      policy = [
        {
          id = "rsa2k";
          algorithm = "RSASHA256";
          ksk-size = 4096;
          zsk-size = 2048;
          nsec3 = true;
        }
      ];

      zone = [
        {
          domain = "lassul.us";
          file = "${./lassul.us.zone}";
          notify = [
            "hetzner_ip4_1"
            "hetzner_ip4_2"
            "hetzner_ip4_3"
            "hetzner_ip6_1"
            "hetzner_ip6_2"
            "hetzner_ip6_3"
          ];
          acl = [
            "hetzner_ip4_1"
            "hetzner_ip4_2"
            "hetzner_ip4_3"
            "hetzner_ip6_1"
            "hetzner_ip6_2"
            "hetzner_ip6_3"
          ];
          dnssec-signing = true;
          dnssec-policy = "rsa2k";
        }
      ];
    };
  };

  # disable to enable auto key generation
  systemd.services.knot.serviceConfig.SystemCallFilter = lib.mkForce [ ];

  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}
