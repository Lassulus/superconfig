{
  self,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    yubikey-personalization
    yubikey-manager
    pinentry-curses
    pinentry-qt
    # fix polkit rules
    # https://github.com/NixOS/nixpkgs/issues/280826
    pcscliteWithPolkit.out
  ];

  services.udev.packages = with pkgs; [ yubikey-personalization ];
  systemd.user.sockets.gpg-agent-ssh.wantedBy = [ "sockets.target" ];

  services.pcscd.enable = true;
  systemd.user.services.gpg-agent.serviceConfig.ExecStartPre = pkgs.writers.writeDash "init_gpg" ''
    set -x
    mkdir -p $HOME/.gnupg
    rm -f $HOME/.gnupg/scdaemon.conf
  '';
  systemd.user.services.gpg-agent.serviceConfig.ExecStartPost = pkgs.writers.writeDash "init_gpg" ''
    ${pkgs.gnupg}/bin/gpg --import ${self.keys.pgp.yubi.key} &>/dev/null
    echo '${self.keys.pgp.yubi.id}:6:' | ${pkgs.gnupg}/bin/gpg --import-ownertrust &>/dev/null
  '';

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        (
          action.id == "org.debian.pcsc-lite.access_pcsc" ||
          action.id == "org.debian.pcsc-lite.access_card"
        ) && subject.user == "lass"
      ) {
        return polkit.Result.YES;
      }
    });
    polkit.addRule(function(action, subject) {
      polkit.log("subject: " + subject + " action: " + action);
    });
  '';

  # allow nix to acces remote builders via yubikey
  systemd.services.nix-daemon.environment.SSH_AUTH_SOCK = "/run/user/1337/gnupg/S.gpg-agent.ssh";

  programs = {
    ssh.startAgent = false;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
