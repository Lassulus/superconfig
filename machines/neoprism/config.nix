{
  self,
  config,
  lib,
  ...
}:

{
  imports = [
    ../../2configs
    ../../2configs/ssh-redirect.nix
    ../../2configs/retiolum.nix
    ../../2configs/mailserver.nix
    ../../2configs/snappymail.nix
    ../../2configs/gsm-wiki.nix
    ../../2configs/monitoring/telegraf.nix
    ../../2configs/pair-programming.nix
    ../../2configs/nginx.nix
    ../../2configs/rogue-talk.nix

    ../../2configs/services/matrix
    ../../2configs/services/matrix/proxy.nix
    ../../2configs/services/matrix/cinny.nix
    ../../2configs/services/matrix/bridges/mautrix-whatsapp.nix
    ../../2configs/services/matrix/bridges/mautrix-signal.nix
    ../../2configs/services/matrix/bridges/heisenbridge.nix
    ../../2configs/services/matrix/bridges/mautrix-telegram.nix
    ../../2configs/services/matrix/bridges/mautrix-discord.nix
    ../../2configs/services/matrix/bridges/matrix-zulip-bridge.nix

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
    # mastodon (social.krebsco.de) -> hotdog container, migrated from prism
    (self.inputs.stockholm + "/krebs/2configs/mastodon-proxy.nix")

    # dns
    ../../2configs/dns/knot.nix

    # url shortener
    ../../2configs/go.nix

    # video strreaming
    ../../2configs/cast.nix

    # c-base ollama tunnel
    ../../2configs/c-base-ai-tunnel.nix

    # debug stuff
    ../../2configs/websites/mergebot.lassul.us.nix

    # autoupdates
    ../../2configs/autoupdate.nix

    # vaultwarden
    ../../2configs/vaultwarden.nix

    # download user
    ../../2configs/download-user.nix

    # caldav calendar
    ../../2configs/radicale.nix

    # lassul.us website
    ../../2configs/websites/lassulus.nix

    # realwallpaper generator
    ../../2configs/realwallpaper.nix

    # binaergewitter announce bot
    # ../../2configs/bgt-bot

    # paste + cyberlocker
    ../../2configs/paste.nix

    # opencrow matrix bot
    ../../2configs/opencrow.nix

    # document signing
    ../../2configs/docuseal.nix

    # kannix (kanban board)
    ../../2configs/kannix.nix

    # backups
    ./backup.nix

    # IPFS
    ../../2configs/services/flix/ipfs.nix

    # n2n supernode (n2n.lassul.us)
    ../../2configs/n2n-supernode.nix

    # pocket-id SSO IdP (id.lassul.us)
    ../../2configs/pocket-id.nix

    # covibe co-vibing dashboard (covibe.lassul.us)
    ../../2configs/covibe.nix

    # omnigent agent meta-harness (omni.lassul.us)
    ../../2configs/omnigent.nix

    # radicle public seed (radicle.lassul.us)
    ../../2configs/radicle.nix

    # self-hosted iroh relay (relay.lassul.us)
    ../../2configs/iroh-relay

    # signed remote command execution (root executor + fleet dashboard,
    # sigexec.lassul.us)
    ../../2configs/sigexec/executor.nix
    ../../2configs/sigexec/dashboard.nix
  ];

  # lassul.us shouldn't be the default vhost here (nginx.nix already sets one)
  services.nginx.virtualHosts."lassul.us" = {
    default = lib.mkForce false;
    locations = {
      "= /wallpaper-marker.png".extraConfig = ''
        alias /var/realwallpaper/realwallpaper-marker.png;
      '';
      "= /wallpaper.png".extraConfig = ''
        alias /var/realwallpaper/realwallpaper.png;
      '';
      "= /wallpaper-stars-berlin.png".extraConfig = ''
        alias /var/realwallpaper/realwallpaper-krebs-stars-berlin.png;
      '';
    };
  };

  # riot VM (HFOS): fresh libvirt guest on a dedicated bridged public IP.
  # Bridged onto ext-br with its own Hetzner MAC, so libvirt manages no
  # iptables for it -> no nat-chain race, no restart-iptables hack (cf. hfos.nix).
  virtualisation.libvirtd.enable = true;
  security.polkit.enable = true;
  users.users.riot = {
    isNormalUser = true;
    extraGroups = [ "libvirtd" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCwcI8EKqUwYVd4IlnTTaNY3qVMDe2M1sVPMdWaTJ8FnAXixBcZozFHyJ9bvGn6c/vFGBEACZk6QCxC2+sTxbaodCOUIyhAtxqAGO7jINmGrVWjg2NW8qBi+e+ekr2+jlhizxgMPgMcbawuazpMzrozi6sfJfRelJRqe6TxrK/SBO+V5pf8v2ubAfHHF6bJrqAykC247d2NmsHEyM/nGOOb2AlJx2vrK1FbFWr2fBAvnhJww9wqrfDYSM6+oRF/vrYKkT9cU8yjtCkyaJZTqRufF2pzc9a0X3Z4LHEIUykAl2aVmi5Wzh8CZj3qCeVb9Ju0ZGQIa5pvG5CbH5SUJOr9y6zhTx1xbqL+JYGkJqgHPMOCFiNIvWnFaNlnvFf4C9KcTf/VMOEvNdDklpjoWm+ptuQIciAhWKuUHd/6MqaRjmlvUqjl49EkRvYOGn9vasKt66MYrtfvbZ3tcqh5w9EEKhrcygiUXhIJzhu2s1BseAVRLjCsQ24BNbzrYiCO+vuk8/hdeHB1rP6Sas2v7jvYb3zQd647OTq+HrZWN8aCjCs5h8Y0QxrQzsLru0zKDRaNDlbSshNBAw7PzSXQAf9fISH7v6sC4nstf5jk+87ua/7xjWG4NYp5Y9FMFCsuE3XVmUCAbauq18RmN6V4s2TxCEs9bxONO0Vba4zwPnvMlw== cardno:000619250765"
    ];
  };
  # the only forwarding the VM needs: accept traffic to/from its public IP.
  krebs.iptables.tables.filter.FORWARD.rules = lib.mkBefore [
    {
      v6 = false;
      predicate = "--destination 95.217.192.52";
      target = "ACCEPT";
    }
    {
      v6 = false;
      predicate = "--source 95.217.192.52";
      target = "ACCEPT";
    }
  ];

  # tank/radicle (radicle seed storage) is created by disko at install; on an
  # already-provisioned host it must be created before deploying:
  #   zfs create -o mountpoint=/var/lib/radicle -o quota=80G tank/radicle
  # nofail keeps a missing dataset from failing local-fs.target -> emergency
  # mode (which has no network and bricks the box).
  fileSystems."/var/lib/radicle".options = [ "nofail" ];

  # Fleet-wide safety net: this box is headless (Hetzner, console only via
  # KVM), so a failed critical target must never strand us at the emergency
  # shell. With emergency mode disabled systemd keeps booting instead of
  # dropping to a console -> network + sshd still come up, so a bad deploy
  # (e.g. a missing dataset, as happened once) leaves the box reachable to
  # fix and redeploy rather than bricked. Mirrors nixpkgs' headless profile.
  # Note: we intentionally do NOT auto-roll-back to the previous generation;
  # our config is pulled from git by system.autoUpgrade, so a rollback would
  # just re-pull the same broken config on the next run (a rollback loop).
  systemd.enableEmergencyMode = false;

  krebs.build.host = config.krebs.hosts.neoprism;
  system.stateVersion = "24.05";
}
