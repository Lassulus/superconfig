{
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    yubikey-personalization
    yubikey-manager
    pinentry-curses
    pinentry-qt
  ];

  services.udev.packages = with pkgs; [ yubikey-personalization ];

  services.pcscd.enable = true;

  programs.gnupg.agent = {
    enable = true;
    # Sets up the gpg-agent-ssh.socket unit so gpg-agent (running in
    # --supervised mode) actually receives an ssh listen fd. The module
    # also exports SSH_AUTH_SOCK in environment.extraInit, which we
    # don't want system-wide — unset it again below so users opt in via:
    #   SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)" ssh ...
    enableSSHSupport = true;
  };

  environment.extraInit = lib.mkAfter ''
    unset SSH_AUTH_SOCK
  '';
}
