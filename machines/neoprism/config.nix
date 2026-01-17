{ config, ... }:

{
  imports = [
    ../../2configs
    ../../2configs/ssh-redirect.nix
    ../../2configs/retiolum.nix
    ../../2configs/exim-smarthost.nix
    ../../2configs/gsm-wiki.nix
    ../../2configs/monitoring/telegraf.nix
    ../../2configs/pair-programming.nix
    ../../2configs/nginx.nix

    ../../2configs/services/matrix
    ../../2configs/services/matrix/proxy.nix

    ../../2configs/services/pad

    ../../2configs/hass/proxy.nix

    # sync-containers
    ../../2configs/consul.nix
    ../../2configs/services/flix/container-host.nix
    ../../2configs/services/radio/container-host.nix
    ../../2configs/orange-host.nix
    ../../2configs/hotdog-host.nix

    # other containers
    ../../2configs/riot.nix

    # proxying of services
    ../../2configs/services/radio/proxy.nix
    ../../2configs/services/flix/proxy.nix
    ../../2configs/services/coms/jitsi.nix

    # dns
    ../../2configs/dns/knot.nix

    # url shortener
    ../../2configs/go.nix

    # video strreaming
    ../../2configs/cast.nix

    # debug stuff
    ../../2configs/websites/mergebot.lassul.us.nix

    # autoupdates
    ../../2configs/autoupdate.nix

    # vaultwarden
    ../../2configs/vaultwarden.nix
  ];

  krebs.build.host = config.krebs.hosts.neoprism;
  system.stateVersion = "24.05";
}
