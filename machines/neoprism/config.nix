{ self, config, lib, pkgs, ... }:

{
  imports = [
    ../../2configs/ssh-redirect.nis
    ../../2configs/retiolum.nix
    ../../2configs/mail/internet-gateway.nix
    ../../2configs/binary-cache/server.nix
    # ../../2configs/matrix.nix
    ../../2configs/gsm-wiki.nix
    ../../2configs/monitoring/telegraf.nix
    ../../nginx.nix

    # sync-containers
    ../../2configs/consul.nix
    ../../2configs/services/flix/container-host.nix
    ../../2configs/services/radio/container-host.nix
    ../../2configs/ubik-host.nix
    ../../2configs/orange-host.nix
    (self.inputs.stockholm + "/krebs/2configs/hotdog-host.nix")

    # other containers
    ../../2configs/riot.nix

    # proxying of services
    ../../2configs/services/radio/proxy.nix
    ../../2configs/services/flix/proxy.nix
    ../../2configs/services/coms/jitsi.nix

    # dns
    ../../2configs/dns/knot.nix

    # debug stuff
    ../../2configs/websites/mergebot.lassul.us.nix

    # changedetection
    ../../2configs/changedetection.nix
  ];

  krebs.build.host = config.krebs.hosts.neoprism;
}
