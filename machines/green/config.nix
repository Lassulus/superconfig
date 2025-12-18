{
  self,
  config,
  pkgs,
  ...
}:
{
  clan.core.vars.password-store.secretLocation = "/var/state/secret-vars";

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

    ../../2configs/atuin-server.nix
    ../../2configs/autoupdate.nix
  ];

  krebs.build.host = config.krebs.hosts.green;

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = config.clan.core.vars.generators.green-container.files."green.sync.pub".path;
  };

  clan.core.vars.generators.green-container = {
    files."green.sync.key" = { };
    files."green.sync.pub".secret = false;
    runtimeInputs = with pkgs; [
      coreutils
      openssh
    ];
    script = ''
      ssh-keygen -t ed25519 -N "" -f "$out"/green.sync.key
      mv "$out"/green.sync.key.pub "$out"/green.sync.pub
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

  environment.systemPackages = [
    self.packages.${pkgs.system}.muchsync
    pkgs.rbw
  ];
}
