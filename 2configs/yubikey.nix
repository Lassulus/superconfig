{
  pkgs,
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
    # Don't use enableSSHSupport: it would override SSH_AUTH_SOCK system-wide.
    # We still want gpg-agent to expose its ssh socket so it can be used
    # on demand via:
    #   SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)" ssh ...
    # Use "" (not true): gpg-agent treats enable-ssh-support as a flag and
    # rejects any argument; the keyValue formatter renders true as `key true`.
    settings.enable-ssh-support = "";
  };
}
