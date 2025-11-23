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
}
