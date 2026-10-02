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
    # also exports SSH_AUTH_SOCK in environment.extraInit (only if unset),
    # which we don't want as the system-wide default — undo exactly that
    # export below, leaving other agents (tpm2.nix) alone; users opt in via:
    #   SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)" ssh ...
    enableSSHSupport = true;
  };

  environment.extraInit = lib.mkAfter ''
    case "''${SSH_AUTH_SOCK:-}" in
      */gnupg/S.gpg-agent.ssh) unset SSH_AUTH_SOCK ;;
    esac
  '';
}
