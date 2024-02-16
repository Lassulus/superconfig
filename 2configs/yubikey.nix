{ self, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    yubikey-personalization
    yubikey-manager
    pinentry-curses pinentry-qt
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
    ${pkgs.coreutils}/bin/ln -sf ${pkgs.writeText "scdaemon.conf" ''
      disable-ccid
      pcsc-driver ${pkgs.pcsclite.lib}/lib/libpcsclite.so.1
      card-timeout 1

      # Always try to use yubikey as the first reader
      # even when other smart card readers are connected
      # Name of the reader can be found using the pcsc_scan command
      # If you have problems with gpg not recognizing the Yubikey
      # then make sure that the string here matches exacly pcsc_scan
      # command output. Also check journalctl -f for errors.
      reader-port Yubico YubiKey
    ''} $HOME/.gnupg/scdaemon.conf
  '';
  systemd.user.services.gpg-agent.serviceConfig.ExecStartPost = pkgs.writers.writeDash "init_gpg" ''
    ${pkgs.gnupg}/bin/gpg --import ${self.inputs.stockholm.outPath + "/kartei/lass/pgp/yubikey.pgp"} >/dev/null
    echo -e '5\ny\n' | ${pkgs.gnupg}/bin/gpg --command-fd 0 --expert --edit-key DBCD757846069B392EA9401D6657BE8A8D1EE807 trust >/dev/null || :
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
      pinentryFlavor = "qt";
      enableSSHSupport = true;
    };
  };
}
