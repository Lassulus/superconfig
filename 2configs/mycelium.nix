{ self, config, lib, pkgs, ... }:
let
  peers = [
    ### official servers
    "tcp://188.40.132.242:9651" # DE 01
    "tcp://[2a01:4f8:221:1e0b::2]:9651"
    "quic://188.40.132.242:9651"
    "quic://[2a01:4f8:221:1e0b::2]:9651"

    "tcp://136.243.47.186:9651" # DE 02
    "tcp://[2a01:4f8:212:fa6::2]:9651"
    "quic://136.243.47.186:9651"
    "quic://[2a01:4f8:212:fa6::2]:9651"

    "tcp://185.69.166.7:9651" # BE 03
    "tcp://[2a02:1802:5e:0:8478:51ff:fee2:3331]:9651"
    "quic://185.69.166.7:9651"
    "quic://[2a02:1802:5e:0:8478:51ff:fee2:3331]:9651"

    "tcp://185.69.166.8:9651" # BE 04
    "tcp://[2a02:1802:5e:0:8c9e:7dff:fec9:f0d2]:9651"
    "quic://185.69.166.8:9651"
    "quic://[2a02:1802:5e:0:8c9e:7dff:fec9:f0d2]:9651"

    "tcp://65.21.231.58:9651" # FI 05
    "tcp://[2a01:4f9:6a:1dc5::2]:9651"
    "quic://65.21.231.58:9651"
    "quic://[2a01:4f9:6a:1dc5::2]:9651"

    "tcp://65.109.18.113:9651" # FI 06
    "tcp://[2a01:4f9:5a:1042::2]:9651"
    "quic://65.109.18.113:9651"
    "quic://[2a01:4f9:5a:1042::2]:9651"
  ];
in
{
  networking.firewall.allowedTCPPorts = [ 9651 ];
  networking.firewall.allowedUDPPorts = [ 9650 9651 ];

  systemd.services.mycelium = {
    description = "Mycelium network";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = lib.concatStringsSep " " (lib.flatten [
        (lib.getExe self.packages.${pkgs.system}.mycelium)
        "--key-file ${config.clanCore.secrets.mycelium.secrets.mycelium_key.path}"
        "--tun-name myc"
        "--peers" peers
      ]);
      Restart = "always";
      RestartSec = 2;
      StateDirectory = "mycelium";

      # TODO: Hardening
    };
  };

  # TODO get public key from mycelium
  # TODO get ip from key
  clanCore.secrets.mycelium = {
    secrets."mycelium_key" = { };
    generator = { 
      path = [
        self.packages.${pkgs.system}.mycelium
        pkgs.coreutils
      ];
      script = ''
        timeout 5 mycelium --key-file "$secrets"/mycelium_key || :
      '';
    };
  };
}
