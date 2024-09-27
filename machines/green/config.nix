{ config, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/mail.nix

    ../../2configs/syncthing.nix

    ../../2configs/weechat.nix
    ../../2configs/bitlbee.nix

    ../../2configs/pass.nix

    ../../2configs/git-brain.nix
    ../../2configs/et-server.nix
    ../../2configs/consul.nix

    ../../2configs/atuin-server.nix
  ];

  # clanCore.facts.secretUploadDirectory = lib.mkForce "/var/state/secrets";
  clan.password-store.targetDirectory = "/var/state/secrets";

  krebs.build.host = config.krebs.hosts.green;

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = config.clanCore.facts.services.green-container.public."green.sync.pub".value;
  };

  clanCore.facts.services.green-container = {
    secret."green.sync.key" = { };
    public."green.sync.pub" = { };
    generator.path = with pkgs; [
      coreutils
      openssh
    ];
    generator.script = ''
      ssh-keygen -t ed25519 -N "" -f "$secrets"/green.sync.key
      mv "$secrets"/green.sync.key "$facts"/green.sync.pub
    '';
  };

  systemd.tmpfiles.rules = [
    "d /home/lass/.local/share 0700 lass users -"
    "d /home/lass/.local 0700 lass users -"
    "d /home/lass/.config 0700 lass users -"

    "d /var/state/lass_mail 0700 lass users -"
    "L+ /home/lass/Maildir - - - - ../../var/state/lass_mail"

    "d /var/state/lass_ssh 0700 lass users -"
    "L+ /home/lass/.ssh - - - - ../../var/state/lass_ssh"
    "d /var/state/lass_gpg 0700 lass users -"
    "L+ /home/lass/.gnupg - - - - ../../var/state/lass_gpg"
    "d /var/state/lass_sync 0700 lass users -"
    "L+ /home/lass/sync - - - - ../../var/state/lass_sync"

    "d /var/state/git 0700 git nogroup -"
    "L+ /var/lib/git - - - - ../../var/state/git"

    "d /var/state/zerotier-one 0700 root root -"
    "L+ /var/lib/zerotier-one - - - - ../../var/state/zerotier-one"
  ];

  users.users.mainUser.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKgpZwye6yavIs3gUIYvSi70spDa0apL2yHR0ASW74z8" # weechat ssh tunnel
  ];

  krebs.iptables.tables.nat.PREROUTING.rules = [
    {
      predicate = "-i eth0 -p tcp -m tcp --dport 22";
      target = "ACCEPT";
    }
  ];

  # workaround for ssh access from yubikey via android
  services.openssh.extraConfig = ''
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
  '';

  services.dovecot2 = {
    enable = true;
    mailLocation = "maildir:~/Maildir";
  };

  networking.firewall.allowedTCPPorts = [ 143 ];
}
