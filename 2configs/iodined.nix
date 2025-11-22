{ config, ... }:

let
  # TODO: make this a parameter
  domain = "io.lassul.us";
in
{

  services.iodine.server = {
    enable = true;
    domain = domain;
    ip = "172.16.10.1/24";
    extraConfig = "-c -l ${config.krebs.build.host.nets.internet.ip4.addr}";
  };

  networking.firewall.allowedUDPPorts = [ 53 ];

}
